"""WI-07: supervisor (src/supervisor/): start, routing, crash, hang, shutdown, single instance.

The supervisor runs as a real process through tools/ahkrun.py (never the interpreter directly). Its
children are real role processes: the test roles echo, crasher, hanger and slow_shutdown from
tests/integration/helpers, registered only with --test-roles. Python clients (AhfClient) play the UI
and the clients; they connect to the supervisor's hub like any other peer.

Timing notes: a Python client has no window for the hub's wake-up, so its messages reach the hub on the
hub's 250 ms fallback timer. Times that include a Python round trip carry that delay. Times measured
between supervisor and child (exits, hangs, crashes) do not.

Exit codes of the supervisor: 0 clean, 1 start failed, 2 bad arguments, 5 a child was terminated.
"""

import subprocess
import sys
import threading
import time
from pathlib import Path

import psutil
import pytest

from support import pipenames, winpipe
from support.ahfclient import AhfClient, dumps, make_envelope
from support.timing import scaled

ROOT = Path(__file__).resolve().parents[2]
ENTRY = ROOT / "tests" / "integration" / "helpers" / "AutoHotFlowTest.ahk"   # product entry plus test roles (WI-29)
AHKRUN = ROOT / "tools" / "ahkrun.py"

EXIT_OK = 0
EXIT_START_FAILED = 1
EXIT_BAD_ARGS = 2
EXIT_FORCED = 5
START_BUDGET_S = scaled(3.0)          # acceptance: all required roles ready within 3 s
CRASH_BUDGET_S = scaled(1.0)          # acceptance: evt.process.crashed within 1 s of the death
HANG_BUDGET_S = scaled(8.0)           # acceptance: a frozen process is hung within 8 s
CLEAN_EXIT_BUDGET_S = scaled(2.0)     # acceptance: healthy children, exit within 2 s
FROZEN_EXIT_SLACK_S = scaled(1.0)     # acceptance: frozen child, exit within deadline + 1 s
RESTART_LIMIT = 3             # Children.RESTART_MAX within Children.RESTART_WINDOW_MS


class Sup:
    """One supervisor process (ahkrun -> AutoHotFlow.ahk). Output goes to a file, not to a pipe."""

    def __init__(self, procs, datadir, session, *args, label="sup"):
        self.session = session
        self.pipe = pipenames.hub_pipe(session)
        self.stderr_path = Path(datadir) / ("%s.stderr" % label)
        self._err = open(self.stderr_path, "wb")
        cmd = [sys.executable, str(AHKRUN), "--timeout", "120", str(ENTRY),
               "--session=" + session, "--data=" + str(datadir), *args]
        self.t0 = time.perf_counter()
        self.proc = procs.start(cmd, stdout=self._err, stderr=self._err, cwd=str(ROOT))

    def wait_exit(self, timeout):
        try:
            return self.proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            return None

    def text(self):
        self._err.flush()
        return self.stderr_path.read_bytes().decode("utf-8", "replace")

    def close(self):
        self._err.close()


def connect(pipe, name, timeout=15.0):
    """Connects to the hub. Retries quickly, so the client subscribes before the first child is ready."""
    deadline = time.monotonic() + timeout
    while True:
        try:
            return AhfClient(pipe, name, connect_timeout=2.0)
        except Exception:
            if time.monotonic() > deadline:
                raise
            time.sleep(0.005)


class Watch:
    """Collects the evt.process.* events of one client, each with the time it arrived."""

    def __init__(self, client):
        self.client = client
        self.items = []
        self._cond = threading.Condition()
        self._stop = False
        self._thread = threading.Thread(target=self._run, name="watch", daemon=True)
        self._thread.start()

    def _run(self):
        while not self._stop:
            try:
                for msg in self.client.events(topic="process", timeout=0.2):
                    with self._cond:
                        self.items.append((time.perf_counter(), msg))
                        self._cond.notify_all()
            except Exception:
                return

    def stop(self):
        self._stop = True

    def find(self, pred):
        return [(t, m) for t, m in list(self.items) if pred(m)]

    def wait(self, pred, timeout):
        """First (time, message) matching pred, or None after timeout seconds."""
        deadline = time.monotonic() + timeout
        with self._cond:
            while True:
                for t, m in self.items:
                    if pred(m):
                        return t, m
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    return None
                self._cond.wait(remaining)


def event(type_, **fields):
    return lambda m: m.get("type") == type_ and all(m["payload"].get(k) == v for k, v in fields.items())


def request_ok(client, to, type_, payload=None, timeout=5.0):
    answer = client.request(to, type_, payload or {}, timeout=timeout)
    assert answer["payload"].get("ok"), answer
    return answer["payload"]


def process_list(client):
    return request_ok(client, "supervisor", "cmd.process.list")["processes"]


def wait_ready(client, names, timeout=10.0):
    """Waits until every child in names is ready and returns {name: (time seen, pid)}, or None.

    Readiness is read from cmd.process.list, not from evt.process.ready: an event that happened before
    this client subscribed is not replayed (PROTOCOL 5, resync by snapshot). The time is taken when the
    snapshot shows the state, so it is an upper bound of the real readiness.
    """
    deadline = time.monotonic() + timeout
    while True:
        by_name = {p["name"]: p for p in process_list(client)}
        if all(by_name.get(n, {}).get("state") == "ready" for n in names):
            return {n: (time.perf_counter(), by_name[n]["pid"]) for n in names}
        if time.monotonic() > deadline:
            return None
        time.sleep(0.05)


def alive(pid):
    try:
        p = psutil.Process(pid)
        return p.is_running() and p.status() != psutil.STATUS_ZOMBIE
    except psutil.NoSuchProcess:
        return False


def start_watch_death(pid, store):
    """Records the time when the process pid has ended (waits in a thread, the test keeps reading)."""
    def run():
        try:
            psutil.Process(pid).wait(timeout=60)
        except (psutil.NoSuchProcess, psutil.TimeoutExpired):
            pass
        store[pid] = time.perf_counter()
    t = threading.Thread(target=run, name="death-%d" % pid, daemon=True)
    t.start()
    return t


@pytest.fixture
def started(procs, datadir, session_id):
    """Opens the list of supervisors and output files of a test, closes the files at teardown."""
    sups = []
    yield lambda *args, **kw: _add(sups, Sup(procs, datadir, session_id, *args, **kw))
    for s in sups:
        s.close()


def _add(sups, sup):
    sups.append(sup)
    return sup


def watch_for(client):
    client.request("supervisor", "cmd.topic.subscribe", {"topic": "process"}, timeout=5)
    return Watch(client)


def children_of(sup_pid):
    try:
        return [c.pid for c in psutil.Process(sup_pid).children(recursive=True)]
    except psutil.NoSuchProcess:
        return []


# --- start and routing ------------------------------------------------------------------------------

def test_required_roles_are_ready_within_3_seconds(started, session_id):
    sup = started("--start=echo:a,echo:b", "--test-roles")
    py = connect(sup.pipe, "py")
    try:
        ready = wait_ready(py, ("echo:a", "echo:b"))
        assert ready is not None, "echo:a and echo:b not ready; supervisor said:\n%s" % sup.text()
        elapsed = max(t for t, _ in ready.values()) - sup.t0
        print("\nall required roles ready after %.2f s (from supervisor start)" % elapsed)
        assert elapsed < START_BUDGET_S, "start took %.2f s" % elapsed
        pids = [pid for _, pid in ready.values()]
        assert all(pid > 0 for pid in pids)
        # the children are processes below ahkrun (the supervisor interpreter is their parent)
        assert set(pids) <= set(children_of(sup.proc.pid))
        states = {p["name"]: p["state"] for p in process_list(py)}
        assert states == {"echo:a": "ready", "echo:b": "ready"}, states
    finally:
        request_ok(py, "supervisor", "cmd.app.exit", {})
        py.close()
        assert sup.wait_exit(timeout=20) == EXIT_OK, sup.text()


def test_message_is_routed_unchanged_and_from_cannot_be_forged(started, session_id):
    sup = started()
    a = connect(sup.pipe, "a")
    b = connect(sup.pipe, "b")
    try:
        payload = {"text": "hallo", "n": 7, "f": 1.5, "s": "0.700000", "list": [1, "x"], "nested": {"k": "v"}}
        # a forged sender: the client writes "from": "forged"; the hub must replace it with "a"
        a._write(dumps(make_envelope("forged", "a#99", "b", "evt.test.routed", None, None, payload)))
        got = b.wait_event("evt.test.routed", timeout=5)
        assert got["from"] == "a", got
        assert got["to"] == "b" and got["id"] == "a#99"
        assert got["payload"] == payload, got["payload"]
        # an unknown target answers a command with not_found
        missing = a.request("nobody", "cmd.test.x", {}, timeout=5)
        assert missing["type"] == "res.test.x" and missing["payload"]["error"]["code"] == "not_found", missing
    finally:
        a.close()
        b.close()
    py = connect(sup.pipe, "py")
    request_ok(py, "supervisor", "cmd.app.exit", {})
    py.close()
    assert sup.wait_exit(timeout=20) == EXIT_OK, sup.text()


def test_frames_outside_the_canonical_form_are_routed_with_the_real_sender(started, session_id):
    # WI-24: canonical frames are routed by their head only; everything else takes the full way. In both
    # ways the sender is the connection. A "from" written behind the payload must not win either.
    sup = started()
    a = connect(sup.pipe, "a")
    b = connect(sup.pipe, "b")
    try:
        # white space after "to": not canonical, parsed fully
        a._write('{"to": "b", "from": "forged", "id": "a#1", "type": "evt.test.spaced", "corr": null, "payload": {"n": 1}}')
        got = b.wait_event("evt.test.spaced", timeout=5)
        assert got["from"] == "a" and got["payload"] == {"n": 1}, got
        # a second "from" behind the payload
        a._write('{"to":"b","from":"a","id":"a#2","type":"evt.test.tail","corr":null,"payload":{"n":2},"from":"forged"}')
        # (the full parser refuses duplicate keys, so the frame is dropped; what matters is that it does not arrive as "forged")
        arrived = [m for m in b.events(timeout=1.0) if m.get("type") == "evt.test.tail"]
        assert all(m["from"] == "a" for m in arrived), arrived
        # canonical frame with a forged sender, payload with braces and quotes inside strings
        text = {"t": '{"x": "}" \\" ]'}
        a._write(dumps(make_envelope("forged", "a#3", "b", "evt.test.fast", None, None, text)))
        got = b.wait_event("evt.test.fast", timeout=5)
        assert got["from"] == "a" and got["payload"] == text, got
        # refusals on the fast way: unknown target and the reserved "*"
        missing = a.request("nobody", "cmd.test.x", {}, timeout=5)
        assert missing["payload"]["error"]["code"] == "not_found", missing
        star = a.request("*", "cmd.test.y", {}, timeout=5)
        assert star["payload"]["error"]["code"] == "denied", star
        # a topic event reaches subscribers, not the sender
        request_ok(b, "supervisor", "cmd.topic.subscribe", {"topic": "t1"})
        a._write(dumps(make_envelope("forged", "a#4", "topic:t1", "evt.test.topic", None, None, {"k": "v"})))
        got = b.wait_event("evt.test.topic", timeout=5)
        assert got["from"] == "a" and got["payload"] == {"k": "v"}, got
    finally:
        a.close()
        b.close()
    py = connect(sup.pipe, "py")
    request_ok(py, "supervisor", "cmd.app.exit", {})
    py.close()
    assert sup.wait_exit(timeout=20) == EXIT_OK, sup.text()


PEER_GONE_BUDGET_S = scaled(1.0)      # F-40 (WI-34): an open request to a client that is gone ends within 1 s
OPEN_REQUEST_S = 10.0                 # the own deadline of these requests: far above the budget


def test_open_request_to_a_client_that_goes_away_is_answered_with_peer_gone_at_once(started, session_id):
    # F-40 (WI-34): the hub forwards a cmd.* and the target goes away before it answers. Before, nobody answered and
    # the sender waited for its own deadline (the engine: 30 s for storage). Now the hub answers with peer_gone when
    # the connection of the target ends. An answer that was given before is not followed by a second one.
    sup = started()
    a = connect(sup.pipe, "a")
    b = connect(sup.pipe, "b")
    try:
        one = a.send("b", "cmd.test.one", {}, timeout_ms=int(OPEN_REQUEST_S * 1000))
        asked = b.wait_event("cmd.test.one", timeout=5)
        b.reply(asked, {"ok": True})
        assert a._wait_answer(one, 5)["payload"]["ok"] is True
        two = a.send("b", "cmd.test.two", {"n": 2}, timeout_ms=int(OPEN_REQUEST_S * 1000))
        b.wait_event("cmd.test.two", timeout=5)          # b has the request and goes away without an answer
        b.close()
        t0 = time.perf_counter()
        try:
            answer = a._wait_answer(two, OPEN_REQUEST_S)
        except Exception as e:          # AhfTimeout: the old behaviour
            pytest.fail("no answer within the own deadline of %.0f s: %s\n%s" % (OPEN_REQUEST_S, e, sup.text()))
        elapsed = time.perf_counter() - t0
        print("\nMEASURE open request answered after the target went away: %.3f s" % elapsed)
        assert answer["type"] == "res.test.two" and answer["from"] == "supervisor", answer
        assert answer["payload"]["ok"] is False and answer["payload"]["error"]["code"] == "peer_gone", answer
        assert elapsed <= PEER_GONE_BUDGET_S, "peer_gone took %.2f s" % elapsed
        time.sleep(0.5)
        assert one not in a._answers and two not in a._answers, "a second answer arrived: %s" % a._answers
    finally:
        a.close()
        b.close()
    py = connect(sup.pipe, "py")
    request_ok(py, "supervisor", "cmd.app.exit", {})
    py.close()
    assert sup.wait_exit(timeout=20) == EXIT_OK, sup.text()


def test_open_request_to_a_child_whose_process_dies_is_answered_with_peer_gone_at_once(started, session_id):
    # F-40 (WI-34): the target is a role process that cannot answer (frozen) and is then killed, as a crashing
    # storage or engine would be. The sender learns it from the hub within 1 s of the death, not at its deadline.
    sup = started("--start=echo:a", "--test-roles")
    py = connect(sup.pipe, "py")
    try:
        ready = wait_ready(py, ("echo:a",))
        assert ready is not None, sup.text()
        pid = ready["echo:a"][1]
        psutil.Process(pid).suspend()
        asked = py.send("echo:a", "cmd.test.echo", {"x": 1}, timeout_ms=int(OPEN_REQUEST_S * 1000))
        time.sleep(0.3)                                   # the request lies in the pipe of the frozen role
        t_kill = time.perf_counter()
        psutil.Process(pid).kill()
        try:
            answer = py._wait_answer(asked, OPEN_REQUEST_S)
        except Exception as e:
            pytest.fail("no answer within the own deadline of %.0f s: %s\n%s" % (OPEN_REQUEST_S, e, sup.text()))
        elapsed = time.perf_counter() - t_kill
        assert answer["payload"]["error"]["code"] == "peer_gone", answer
        assert not alive(pid)
        print("\nMEASURE open request answered after the death of the target: %.3f s" % elapsed)
        assert elapsed <= PEER_GONE_BUDGET_S, "peer_gone %.2f s after the death" % elapsed
    finally:
        request_ok(py, "supervisor", "cmd.app.exit", {})
        py.close()
        assert sup.wait_exit(timeout=20) == EXIT_OK, sup.text()


# --- single instance -------------------------------------------------------------------------------

def test_second_instance_forwards_the_command_and_creates_no_hub(started, session_id):
    first = started(label="first")
    py = connect(first.pipe, "py")
    try:
        request_ok(py, "supervisor", "cmd.process.list")          # the first instance serves
        second = started("--command=hallo welt", label="second")
        code = second.wait_exit(timeout=30)
        assert code == EXIT_OK, "second instance exit %s:\n%s" % (code, second.text())
        assert "forwarding the command" in second.text()
        # the hub is announced by "session ... running, hub ..." (Supervisor.Start); the second instance must not log it
        assert "running, hub" not in second.text(), "second instance started a hub"
        # the first hub still answers, and it is the only one on this pipe
        assert process_list(py) == []
        request_ok(py, "supervisor", "cmd.app.exit", {})
    finally:
        py.close()
    assert first.wait_exit(timeout=20) == EXIT_OK, first.text()
    # ahkrun copies the supervisor's stderr only when it ends, so the delivered command is checked now
    assert "command from command: hallo welt" in first.text(), first.text()


# --- pipe and mutex names (WI-22 point 5) ----------------------------------------------------------

def test_hub_pipe_name_carries_the_windows_session_and_the_user(started, session_id):
    sup = started()
    expected = pipenames.hub_pipe(session_id)
    assert expected.startswith("ahf.s%d.u" % pipenames.windows_session_id()), expected
    py = connect(expected, "py")
    try:
        request_ok(py, "supervisor", "cmd.process.list")
        request_ok(py, "supervisor", "cmd.app.exit", {})
    finally:
        py.close()
    assert sup.wait_exit(timeout=20) == EXIT_OK, sup.text()
    assert "hub " + expected in sup.text(), sup.text()          # the supervisor announces the name it serves


def test_a_foreign_pipe_with_the_old_name_does_not_block_the_start(started, session_id):
    squatter = winpipe.OverlappedPipe.create_server(pipenames.legacy_hub_pipe(session_id))
    try:
        sup = started()
        py = connect(sup.pipe, "py")
        try:
            request_ok(py, "supervisor", "cmd.process.list")
            request_ok(py, "supervisor", "cmd.app.exit", {})
        finally:
            py.close()
        assert sup.wait_exit(timeout=20) == EXIT_OK, sup.text()
    finally:
        squatter.close()


def test_the_instance_mutex_lives_in_the_namespace_of_the_windows_session(started, session_id):
    import ctypes
    sup = started()
    py = connect(sup.pipe, "py")
    try:
        k32 = ctypes.WinDLL("kernel32", use_last_error=True)
        k32.OpenMutexW.restype = ctypes.c_void_p
        k32.OpenMutexW.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_wchar_p]
        k32.CloseHandle.argtypes = [ctypes.c_void_p]
        SYNCHRONIZE = 0x00100000
        h = k32.OpenMutexW(SYNCHRONIZE, 0, "Local\\AHF.supervisor." + session_id)
        assert h, "mutex Local\\AHF.supervisor.<session> not found (error %d)" % ctypes.get_last_error()
        k32.CloseHandle(h)
        request_ok(py, "supervisor", "cmd.app.exit", {})
    finally:
        py.close()
    assert sup.wait_exit(timeout=20) == EXIT_OK, sup.text()


# --- test role availability ------------------------------------------------------------------------

def test_test_roles_are_unknown_without_the_flag(started, session_id):
    sup = started("--start=crasher")
    assert sup.wait_exit(timeout=30) == EXIT_START_FAILED, sup.text()
    assert "unknown role 'crasher'" in sup.text()
    direct = started("--role=crasher", "--hub=ahf.x.hub")
    assert direct.wait_exit(timeout=30) == EXIT_BAD_ARGS, direct.text()
    assert "unknown role 'crasher'" in direct.text()


# --- crash and restart policy ------------------------------------------------------------------------

@pytest.mark.slow
def test_crashed_child_is_reported_within_1s_restarted_by_policy_and_others_are_untouched(started, session_id):
    sup = started("--start=echo:keep,crasher", "--test-roles")
    py = connect(sup.pipe, "py")
    watch = watch_for(py)
    deaths = {}
    threads = []
    try:
        keep = wait_ready(py, ("echo:keep",))
        assert keep is not None, sup.text()
        keep_pid = keep["echo:keep"][1]
        # Each incarnation of the crasher is watched from the moment it is seen ready, then armed: it
        # crashes CRASH_AFTER_MS after the arm message, so the watch always starts before the death.
        # The policy restarts it RESTART_LIMIT times, then gives up.
        final = None
        armed = set()
        end = time.monotonic() + 40
        while time.monotonic() < end:
            crasher = {p["name"]: p for p in process_list(py)}.get("crasher")
            if crasher and crasher["state"] == "ready" and crasher["pid"] not in armed:
                armed.add(crasher["pid"])
                threads.append(start_watch_death(crasher["pid"], deaths))
                request_ok(py, "crasher", "cmd.test.arm", {})
            crashes = watch.find(event("evt.process.crashed", name="crasher"))
            if crashes and not crashes[-1][1]["payload"]["restart"]:
                final = crashes[-1]
                break
            # the healthy sibling keeps answering during the crash loop
            request_ok(py, "echo:keep", "cmd.test.echo", {"n": len(armed)})
            time.sleep(0.05)
        assert final is not None, "no give-up after the restart limit:\n%s" % sup.text()
        crashes = watch.find(event("evt.process.crashed", name="crasher"))
        restarts = watch.find(event("evt.process.restarted", name="crasher"))
        assert len(armed) == RESTART_LIMIT + 1, sorted(armed)
        assert len(crashes) == RESTART_LIMIT + 1, [m["payload"] for _, m in crashes]
        assert len(restarts) == RESTART_LIMIT, [m["payload"] for _, m in restarts]
        assert [m["payload"]["attempt"] for _, m in restarts] == [1, 2, 3]
        assert all(m["payload"]["reason"] == "exited" for _, m in crashes)
        assert all(not m["payload"]["restart"] for _, m in crashes[-1:])
        # no restart after the limit: one more second without a new start
        time.sleep(1.5)
        final_list = {p["name"]: p for p in process_list(py)}["crasher"]
        assert final_list["state"] == "crashed" and final_list["restarts"] == RESTART_LIMIT, final_list
        # the first start happened before the subscription and is not replayed (see wait_ready)
        assert len(watch.find(event("evt.process.started", name="crasher"))) == RESTART_LIMIT
        # each crash is reported within 1 s of the death of that process
        for t_event, m in crashes:
            pid = m["payload"]["pid"]
            for th in threads:
                th.join(timeout=5)
            assert pid in deaths, "no death recorded for pid %s" % pid
            lag = t_event - deaths[pid]
            print("\ncrash of pid %s reported %.3f s after its death" % (pid, lag))
            assert -0.05 <= lag <= CRASH_BUDGET_S, "crash reported %.3f s after the death" % lag
        # the sibling was never touched
        assert alive(keep_pid)
        assert {p["name"]: p["pid"] for p in process_list(py)}["echo:keep"] == keep_pid
    finally:
        watch.stop()
        request_ok(py, "supervisor", "cmd.app.exit", {})
        py.close()
    assert sup.wait_exit(timeout=20) == EXIT_OK, sup.text()


# --- hang ----------------------------------------------------------------------------------------------

@pytest.mark.slow
def test_frozen_child_is_hung_within_8s_and_ended_like_a_crash(started, session_id):
    sup = started("--start=hanger", "--test-roles")
    py = connect(sup.pipe, "py")
    watch = watch_for(py)
    try:
        ready = wait_ready(py, ("hanger",))
        assert ready is not None, sup.text()
        pid = ready["hanger"][1]
        proc = psutil.Process(pid)
        t_frozen = time.perf_counter()
        proc.suspend()
        hung = watch.wait(event("evt.process.hung", name="hanger"), timeout=HANG_BUDGET_S + 4)
        assert hung is not None, "frozen child not reported as hung:\n%s" % sup.text()
        print("\nfrozen child reported hung %.2f s after the freeze" % (hung[0] - t_frozen))
        assert hung[0] - t_frozen <= HANG_BUDGET_S, "hung after %.2f s" % (hung[0] - t_frozen)
        crashed = watch.wait(event("evt.process.crashed", name="hanger"), timeout=10)
        assert crashed is not None and crashed[1]["payload"]["reason"] == "hung", sup.text()
        assert crashed[1]["payload"]["restart"] is False           # hanger is not auto-restarted
        assert crashed[0] - hung[0] <= 4.0, "terminated %.2f s after the hang" % (crashed[0] - hung[0])
        proc.wait(timeout=5)                                      # the process really ended
        assert not alive(pid)
    finally:
        watch.stop()
        request_ok(py, "supervisor", "cmd.app.exit", {})
        py.close()
    # a child was terminated: the exit is reported as forced
    assert sup.wait_exit(timeout=20) == EXIT_FORCED, sup.text()


# --- shutdown -----------------------------------------------------------------------------------------

def test_clean_exit_with_healthy_children_within_2s_and_no_leftover_process(started, session_id):
    sup = started("--start=echo:a,echo:b", "--test-roles")
    py = connect(sup.pipe, "py")
    watch = watch_for(py)
    try:
        ready = wait_ready(py, ("echo:a", "echo:b"))
        assert ready is not None, sup.text()
        pids = [pid for _, pid in ready.values()]
        started_exit = time.perf_counter()
        request_ok(py, "supervisor", "cmd.app.exit", {})
        code = sup.proc.wait(timeout=30)
        elapsed = time.perf_counter() - started_exit
        print("\nexit of healthy supervisor after %.3f s" % elapsed)
        assert code == EXIT_OK, sup.text()
        assert elapsed <= CLEAN_EXIT_BUDGET_S, "exit took %.2f s" % elapsed
        for pid in pids:
            assert not alive(pid), "child %s left behind" % pid
        for name in ("echo:a", "echo:b"):
            exited = watch.find(event("evt.process.exited", name=name))
            assert exited and exited[0][1]["payload"]["clean"] is True, (name, exited)
    finally:
        watch.stop()
        py.close()


def test_slow_child_is_waited_for_and_not_terminated(started, session_id):
    sup = started("--start=slow_shutdown:s", "--test-roles")
    py = connect(sup.pipe, "py")
    watch = watch_for(py)
    try:
        ready = wait_ready(py, ("slow_shutdown:s",))
        assert ready is not None, sup.text()
        pid = ready["slow_shutdown:s"][1]
        request_ok(py, "supervisor", "cmd.app.exit", {})
        assert sup.wait_exit(timeout=30) == EXIT_OK, sup.text()
        exited = watch.find(event("evt.process.exited", name="slow_shutdown:s"))
        assert exited and exited[0][1]["payload"]["clean"], exited
        assert not alive(pid)
    finally:
        watch.stop()
        py.close()


@pytest.mark.slow
def test_frozen_child_at_exit_is_terminated_at_the_deadline(started, session_id):
    sup = started("--start=echo:a,hanger", "--test-roles", "--deadline=2000")
    py = connect(sup.pipe, "py")
    watch = watch_for(py)
    try:
        ready = wait_ready(py, ("echo:a", "hanger"))
        assert ready is not None, sup.text()
        hanger_pid = ready["hanger"][1]
        echo_pid = ready["echo:a"][1]
        psutil.Process(hanger_pid).suspend()
        started_exit = time.perf_counter()
        request_ok(py, "supervisor", "cmd.app.exit", {"deadlineMs": 2000})
        code = sup.proc.wait(timeout=30)
        elapsed = time.perf_counter() - started_exit
        print("\nfrozen child at exit: supervisor ended after %.2f s, exit %s" % (elapsed, code))
        assert code == EXIT_FORCED, sup.text()
        assert elapsed <= 2.0 + FROZEN_EXIT_SLACK_S, "exit took %.2f s" % elapsed
        assert not alive(hanger_pid), "frozen child left behind"
        assert not alive(echo_pid), "healthy child left behind"
        exited = watch.find(event("evt.process.exited", name="echo:a"))
        assert exited and exited[0][1]["payload"]["clean"], exited
    finally:
        watch.stop()
        py.close()


# --- prepare phase (UI may cancel) ---------------------------------------------------------------------

def test_a_manager_can_cancel_the_exit_in_the_prepare_phase(started, session_id):
    sup = started()
    py = connect(sup.pipe, "py")
    watch = watch_for(py)
    manager = connect(sup.pipe, "manager")
    try:
        request_ok(py, "supervisor", "cmd.app.exit", {})
        request = manager.wait_event("cmd.app.prepareExit", timeout=5)
        manager.reply(request, {"cancel": True})
        cancelled = watch.wait(lambda m: m.get("type") == "evt.app.exitCancelled", timeout=5)
        assert cancelled is not None, sup.text()
        time.sleep(1.0)
        assert sup.proc.poll() is None, "exit was not cancelled:\n%s" % sup.text()
        assert process_list(py) == []
        # the next exit goes through when the manager does not object
        request_ok(py, "supervisor", "cmd.app.exit", {})
        request = manager.wait_event("cmd.app.prepareExit", timeout=5)
        manager.reply(request, {"cancel": False})
        assert sup.wait_exit(timeout=20) == EXIT_OK, sup.text()
    finally:
        watch.stop()
        manager.close()
        py.close()


# --- Hub.Request deadline (WI-07 open point) -----------------------------------------------------------

@pytest.mark.slow
def test_request_without_answer_times_out_and_late_answer_is_dropped(started, session_id):
    """A UI that never answers cmd.app.prepareExit: the request ends at its limit with a timeout, the exit
    goes on (a timeout is no cancel), and an answer that comes later is dropped, not counted as a cancel."""
    limit_ms = 500
    # the slow child keeps the exit running after the timeout, so a late answer still reaches a live hub
    sup = started("--start=slow_shutdown:s", "--test-roles", "--prepare-limit=%d" % limit_ms)
    py = connect(sup.pipe, "py")
    watch = watch_for(py)
    manager = connect(sup.pipe, "manager")
    try:
        ready = wait_ready(py, ("slow_shutdown:s",))
        assert ready is not None, sup.text()
        request_ok(py, "supervisor", "cmd.app.exit", {})
        request = manager.wait_event("cmd.app.prepareExit", timeout=5)
        # The timeout must have fired within limit + 0.5 s. The late answer is sent after that point, so it
        # asks for a cancel while its request has ended. (The hub's stderr lines are not a clock: they
        # appear in batches, so the test does not time the timeout from the log.) If the timeout had not
        # fired by then, this answer would count as a real cancel and the assertions below would fail.
        time.sleep(limit_ms / 1000 + 0.5)
        manager.reply(request, {"cancel": True})
        assert sup.wait_exit(timeout=30) == EXIT_OK, sup.text()
        assert watch.find(event("evt.app.exitCancelled")) == [], sup.text()
        text = sup.text()
        assert text.count("timed out") == 1, text
        assert "late or unknown answer" in text, text
        exited = watch.find(event("evt.process.exited", name="slow_shutdown:s"))
        assert exited and exited[0][1]["payload"]["clean"], exited
    finally:
        watch.stop()
        manager.close()
        py.close()


def test_answer_to_a_hub_request_reaches_its_callback_once(started, session_id):
    """The id of a Hub.Request is registered before the frame leaves, so the real answer finds its
    callback: the exit goes on at once, long before the limit, and no timeout is logged."""
    limit_ms = 3000
    sup = started("--test-roles", "--prepare-limit=%d" % limit_ms)
    py = connect(sup.pipe, "py")
    manager = connect(sup.pipe, "manager")
    try:
        request_ok(py, "supervisor", "cmd.app.exit", {})
        request = manager.wait_event("cmd.app.prepareExit", timeout=5)
        started_at = time.perf_counter()
        manager.reply(request, {"cancel": False})
        assert sup.wait_exit(timeout=10) == EXIT_OK, sup.text()
        elapsed = time.perf_counter() - started_at
        print("\nprepareExit answered, exit after %.2f s" % elapsed)
        assert elapsed < limit_ms / 1000, "exit waited for the timeout: %.2f s" % elapsed
        text = sup.text()
        assert "timed out" not in text, text
        assert "late or unknown answer" not in text, text
    finally:
        manager.close()
        py.close()
