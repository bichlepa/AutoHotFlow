"""WI-05: message layer (Message, Dispatcher, Peer) against a Python stand-in hub.

Real AutoHotkey processes run src/core/ipc/Peer.ahk through tests/integration/helpers/peer_probe.ahk.
The hub is tests/support/pyhub.py, with one addition: WakingHub posts the wake-up message to the
receiving window after every routed message. PROTOCOL 1 asks the sender to do that. pyhub does not
do it, so without it each message would wait for the 250 ms fallback timer of the AHK side.

Peer-to-peer checks use "srv" and "cli" (two AHK peers, mode serve and ask). Python-driven checks use
"py" (AhfClient). "silent" is a Python peer that never answers, for timeouts and lost connections.
"""

import ctypes
import sys
import time
from ctypes import wintypes
from pathlib import Path

import pytest

HELPERS = Path(__file__).resolve().parent / "helpers"
sys.path.insert(0, str(HELPERS))

import rawpipe  # noqa: E402
from rawpipe import Helper  # noqa: E402
from support.ahfclient import AhfClient  # noqa: E402
from support.pyhub import PyHub  # noqa: E402

PROBE = HELPERS / "peer_probe.ahk"
WM_AHF_WAKE = 0x8001
LOOP_REQUESTS = 10000

_user32 = ctypes.WinDLL("user32", use_last_error=True)
_user32.CreateWindowExW.argtypes = [wintypes.DWORD, wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD,
                                    ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                                    ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]
_user32.CreateWindowExW.restype = ctypes.c_void_p
_user32.DestroyWindow.argtypes = [ctypes.c_void_p]
_user32.DestroyWindow.restype = wintypes.BOOL
_user32.PeekMessageW.argtypes = [ctypes.c_void_p, ctypes.c_void_p, wintypes.UINT, wintypes.UINT, wintypes.UINT]
_user32.PeekMessageW.restype = wintypes.BOOL
PM_REMOVE = 1
HWND_MESSAGE = ctypes.c_void_p(-3)


class WakingHub(PyHub):
    """PyHub that wakes every peer window that has announced one, after each routed message."""

    def _handle(self, link, msg):
        super()._handle(link, msg)
        with self._lock:
            hwnds = [l.hwnd for l in self._links if l.hwnd]
        for hwnd in hwnds:
            rawpipe.wake(hwnd)


@pytest.fixture
def pipe_name(session_id):
    return "ahf.peertest.%s" % session_id


def probe(procs, ahk_exe, datadir, pipe_name, name, mode, *options):
    """Starts peer_probe.ahk as peer `name`."""
    return Helper(procs, ahk_exe, datadir, PROBE, pipe_name, "name=" + name, "mode=" + mode, *options, label=name)


def wait_count(helper, type_, n, timeout):
    """Waits until the helper has written at least n records of the type."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        found = helper.of_type(type_)
        if len(found) >= n:
            return found
        time.sleep(0.01)
    raise AssertionError("only %d of %d '%s' records within %.1f s: %s"
                         % (len(helper.of_type(type_)), n, type_, timeout, helper.records()))


def answers(helper, step):
    return [r for r in helper.records() if r.get("type") == "answer" and r.get("step") == step]


def sent_id(helper, step):
    return next(r["id"] for r in helper.records() if r.get("type") == "sent" and r.get("step") == step)


def is_subscribe_from(name):
    return lambda m: m.get("type") == "cmd.topic.subscribe" and m.get("from") == name


def create_message_window():
    hwnd = _user32.CreateWindowExW(0, "STATIC", "ahf-peer-probe", 0, 0, 0, 0, 0, HWND_MESSAGE, None, None, None)
    assert hwnd, "CreateWindowExW failed: error %d" % ctypes.get_last_error()
    return hwnd


def wait_for_wake(hwnd, timeout):
    """Polls the window's queue for WM_AHF_WAKE. Returns the elapsed seconds, or None on timeout."""
    msg = ctypes.create_string_buffer(64)
    start = time.perf_counter()
    while time.perf_counter() - start < timeout:
        if _user32.PeekMessageW(ctypes.addressof(msg), hwnd, WM_AHF_WAKE, WM_AHF_WAKE, PM_REMOVE):
            return time.perf_counter() - start
        time.sleep(0.001)
    return None


# --- connection and handshake ----------------------------------------------------------------

def test_peer_is_ready_and_hello_carries_window_and_pid(procs, ahk_exe, datadir, pipe_name):
    with WakingHub(pipe_name) as hub:
        srv = probe(procs, ahk_exe, datadir, pipe_name, "srv", "serve")
        ready = srv.wait_record("ready", timeout=15)
        started = srv.wait_record("started", timeout=15)
        assert ready["status"] == "ready"
        hello = hub.wait_received(lambda m: m.get("type") == "sys.hello", timeout=5)
        assert hello is not None, "hub never received sys.hello"
        assert hello["to"] == "supervisor" and hello["from"] == "srv" and hello["corr"] is None
        payload = hello["payload"]
        assert payload["name"] == "srv"
        assert payload["protocol"] == 1
        assert payload["hwnd"] == started["hwnd"] and payload["pid"] == started["pid"]
        print("\nready %.1f ms after start (hub without wake-up of the peer)" % ready["elapsedMs"])


def test_hello_wakes_the_hub_window_when_hub_hwnd_is_given(procs, ahk_exe, datadir, pipe_name):
    hwnd = create_message_window()
    try:
        with WakingHub(pipe_name) as hub:
            srv = probe(procs, ahk_exe, datadir, pipe_name, "srv", "serve", "hubHwnd=%d" % hwnd)
            srv.wait_record("ready", timeout=15)
            assert hub.wait_received(lambda m: m.get("type") == "sys.hello", timeout=5) is not None
            woke = wait_for_wake(hwnd, timeout=2.0)
            assert woke is not None, "no WM_AHF_WAKE reached the hub window after sys.hello"
            print("\nwake message seen %.2f ms after the hub polled" % (woke * 1000))
    finally:
        _user32.DestroyWindow(hwnd)


# --- requests and events between two AHK peers --------------------------------------------------

def test_request_answers_and_event_between_two_ahk_peers(procs, ahk_exe, datadir, pipe_name):
    with WakingHub(pipe_name):
        srv = probe(procs, ahk_exe, datadir, pipe_name, "srv", "serve")
        srv.wait_record("ready", timeout=15)
        cli = probe(procs, ahk_exe, datadir, pipe_name, "cli", "ask", "steps=echo,boom,unknown,event")
        cli.wait_record("done", timeout=30)

        [echo] = answers(cli, "echo")
        assert echo["corr"] == sent_id(cli, "echo")
        assert echo["msgType"] == "res.echo" and echo["from"] == "srv"
        assert echo["payload"]["ok"] == 1
        assert echo["payload"]["echo"] == {"x": 1}

        [boom] = answers(cli, "boom")
        assert boom["corr"] == sent_id(cli, "boom")
        assert boom["payload"]["ok"] == 0
        assert boom["payload"]["error"]["code"] == "busy"

        [unknown] = answers(cli, "unknown")
        assert unknown["corr"] == sent_id(cli, "unknown")
        assert unknown["payload"]["ok"] == 0
        assert unknown["payload"]["error"]["code"] == "unknown_type"

        event = srv.wait_record(lambda r: r.get("type") == "event" and r.get("msgType") == "evt.test.hello",
                                timeout=5)
        assert event["from"] == "cli"
        assert event["payload"] == {"n": 7}


def test_timeout_calls_back_once_and_late_answer_is_dropped(procs, ahk_exe, datadir, pipe_name):
    with WakingHub(pipe_name):
        cli = probe(procs, ahk_exe, datadir, pipe_name, "cli", "ask", "steps=timeout")
        silent = AhfClient(pipe_name, "silent", connect_timeout=15)
        try:
            request = silent.wait_event("cmd.wait", timeout=15)
            time.sleep(0.6)                     # answer after the 300 ms deadline
            silent.reply(request, {"ok": True})
            cli.wait_record("done", timeout=15)
        finally:
            silent.close()

        [timed_out] = answers(cli, "timeout")
        assert timed_out["count"] == 1
        assert timed_out["payload"]["ok"] == 0
        assert timed_out["payload"]["error"]["code"] == "timeout"
        assert abs(timed_out["elapsedMs"] - 300) <= 50, "timeout after %.1f ms, expected 300 +- 50" % timed_out["elapsedMs"]
        after = cli.wait_record("after_timeout", timeout=5)
        assert after["count"] == 1, "callback ran %d times" % after["count"]
        assert after["lateReplies"] == 1, "the late answer was not counted as dropped"
        assert after["pending"] == 0
        print("\ntimeout fired after %.1f ms (asked 300 ms)" % timed_out["elapsedMs"])


# --- requests and events driven from Python ----------------------------------------------------

def test_python_gets_answers_for_ping_unknown_type_handler_error_and_bad_payload(procs, ahk_exe, datadir, pipe_name):
    with WakingHub(pipe_name):
        srv = probe(procs, ahk_exe, datadir, pipe_name, "srv", "serve")
        srv.wait_record("ready", timeout=15)
        py = AhfClient(pipe_name, "py", connect_timeout=15)
        try:
            pong = py.request("srv", "sys.ping", {"n": 5}, timeout=5)
            assert pong["type"] == "sys.pong" and pong["payload"]["n"] == 5

            unknown = py.request("srv", "cmd.nothing", {}, timeout=5)
            assert unknown["type"] == "res.nothing"
            assert unknown["payload"]["error"]["code"] == "unknown_type"

            boom = py.request("srv", "cmd.boom", {}, timeout=5)
            assert boom["payload"]["ok"] == 0 and boom["payload"]["error"]["code"] == "busy"

            echo = py.request("srv", "cmd.echo", {"a": "b"}, timeout=5)
            assert echo["payload"]["echo"] == {"a": "b"}

            # Not valid: payload is a number. The command still gets its error answer (PROTOCOL 2).
            raw = ('{"to":"srv","from":"py","id":"py#900","type":"cmd.echo","corr":null,"payload":5}')
            py._write(raw)
            bad = py._wait_answer("py#900", 5)
            assert bad["type"] == "res.echo"
            assert bad["payload"]["ok"] == 0 and bad["payload"]["error"]["code"] == "bad_payload"
        finally:
            py.close()


def test_events_from_python_and_topic_fan_out_reach_the_peer(procs, ahk_exe, datadir, pipe_name):
    with WakingHub(pipe_name) as hub:
        srv = probe(procs, ahk_exe, datadir, pipe_name, "srv", "serve")
        srv.wait_record("ready", timeout=15)
        hub.wait_received(is_subscribe_from("srv"), timeout=5)
        py = AhfClient(pipe_name, "py", connect_timeout=15)
        try:
            py.send("srv", "evt.test.from_py", {"k": 1})
            # The subscription is processed on the hub's own thread: send until the peer has it.
            deadline = time.monotonic() + 5
            topic_seen = None
            while topic_seen is None and time.monotonic() < deadline:
                py.send("topic:news", "evt.news.item", {"v": 2})
                topic_seen = next((r for r in srv.records()
                                   if r.get("type") == "event" and r.get("msgType") == "evt.news.item"), None)
                time.sleep(0.05)
            assert topic_seen is not None, "topic event did not reach the subscribed peer"
            assert topic_seen["payload"] == {"v": 2}
            direct = srv.wait_record(lambda r: r.get("type") == "event" and r.get("msgType") == "evt.test.from_py",
                                     timeout=5)
            assert direct["from"] == "py" and direct["payload"] == {"k": 1}
        finally:
            py.close()


# --- lost connections --------------------------------------------------------------------------

def test_reconnect_after_hub_restart_resubscribes_and_reports_ready_again(procs, ahk_exe, datadir, pipe_name):
    hub = WakingHub(pipe_name).start()
    hub2 = None
    try:
        srv = probe(procs, ahk_exe, datadir, pipe_name, "srv", "serve")
        wait_count(srv, "ready", 1, timeout=15)
        assert hub.wait_received(is_subscribe_from("srv"), timeout=5) is not None
        hub.stop()
        time.sleep(1.0)
        hub2 = WakingHub(pipe_name).start()
        wait_count(srv, "ready", 2, timeout=8)
        assert hub2.wait_received(is_subscribe_from("srv"), timeout=5) is not None, \
            "subscription was not sent again after the reconnect"
        assert srv.of_type("closed") == [], "OnClosed must not fire while the budget lasts"
    finally:
        hub.stop()
        if hub2 is not None:
            hub2.stop()


def test_hub_gone_for_longer_than_the_budget_calls_onclosed(procs, ahk_exe, datadir, pipe_name):
    hub = WakingHub(pipe_name).start()
    try:
        srv = probe(procs, ahk_exe, datadir, pipe_name, "srv", "serve")
        srv.wait_record("ready", timeout=15)
        stopped = time.monotonic()
        hub.stop()
        closed = srv.wait_record("closed", timeout=16)
        elapsed = time.monotonic() - stopped
        assert closed["reason"] == "hub_unreachable"
        assert 9.5 <= elapsed <= 12.5, "OnClosed after %.2f s, expected about 10 s" % elapsed
        print("\nOnClosed %.2f s after the hub stopped" % elapsed)
    finally:
        hub.stop()


def test_pending_request_fails_with_peer_gone_when_hub_drops(procs, ahk_exe, datadir, pipe_name):
    hub = WakingHub(pipe_name).start()
    silent = None
    try:
        cli = probe(procs, ahk_exe, datadir, pipe_name, "cli", "ask", "steps=hang")
        silent = AhfClient(pipe_name, "silent", connect_timeout=15)
        silent.wait_event("cmd.wait", timeout=15)      # the request is out and waiting
        hub.stop()
        hang = cli.wait_record(lambda r: r.get("type") == "answer" and r.get("step") == "hang", timeout=5)
        assert hang["payload"]["ok"] == 0
        assert hang["payload"]["error"]["code"] == "peer_gone"
        assert hang["elapsedMs"] < 2000, "failure after %.1f ms, expected at once" % hang["elapsedMs"]
        time.sleep(0.5)
        assert len(answers(cli, "hang")) == 1
    finally:
        if silent is not None:
            silent.close()
        hub.stop()


# --- many requests ----------------------------------------------------------------------------

def test_10000_sequential_requests_keep_pending_and_handles_flat(procs, ahk_exe, datadir, pipe_name):
    with WakingHub(pipe_name):
        srv = probe(procs, ahk_exe, datadir, pipe_name, "srv", "serve")
        srv.wait_record("ready", timeout=15)
        cli = probe(procs, ahk_exe, datadir, pipe_name, "cli", "ask", "steps=loop", "n=%d" % LOOP_REQUESTS)
        cli.wait_record("done", timeout=100)
        loop = cli.wait_record("loop", timeout=5)
        assert loop["n"] == LOOP_REQUESTS
        assert loop["bad"] == 0, "%d requests had a wrong answer" % loop["bad"]
        assert loop["pending"] == 0, "requests still registered after the run: %d" % loop["pending"]
        assert loop["handlesMid"] - loop["handlesStart"] <= 2, loop
        assert loop["handlesEnd"] - loop["handlesMid"] <= 2, loop
        per = loop["elapsedMs"] / LOOP_REQUESTS
        print("\n%d sequential requests in %.0f ms (%.3f ms each); handles %d -> %d -> %d"
              % (LOOP_REQUESTS, loop["elapsedMs"], per, loop["handlesStart"], loop["handlesMid"], loop["handlesEnd"]))
