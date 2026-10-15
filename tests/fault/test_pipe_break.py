"""WI-0015: a pipe breaks while the processes live (PROTOCOL 5, ARCHITECTURE 6.2).

Four cases:
  1. A client closes its pipe abruptly (many times): the hub cleans up, no handle leak, the chain answers.
  2. A client never reads: its send queue overflows, the hub removes it, the chain stays responsive.
  3. A role's pipe is cut by the hub side while the role process lives: the role rebuilds the connection
     (PROTOCOL 5 item 3) and works again; the process keeps its pid.
  4. The pipe is cut and the hub does not come back: the role ends with exit 4 (orphan guard), no leftover.

Cases 1 and 2 run under the real supervisor. Cases 3 and 4 use the Python stand-in hub (WakingHub) because the
test must be able to cut one link without touching the process; the real storage role is the system under test.
"""

import time

import psutil
import pytest

from faultkit import (EXIT_HUB_LOST, FULL_CHAIN, ORPHAN_BUDGET_S, STUB_OPTS, RoleProc, connect, repeat_ids,
                      wait_until)
from support import winpipe
from support.ahfclient import AhfClient, FrameDecoder, dumps, encode_frame, make_envelope
from support.pyhub import WakingHub

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault

CYCLES = 30
HANDLE_SLACK = 8            # handles the supervisor may hold more after the cycles (timers, lists, ...)
FLOOD_REQUESTS = 4000       # more than Connection.maxQueueFrames (1000) answers pile up for a client that never reads


def hello_frame(name, pid=0):
    env = make_envelope(name, name + "#1", "supervisor", "sys.hello", None, None,
                        {"name": name, "pid": pid, "hwnd": 0, "protocol": 1})
    return encode_frame(dumps(env))


def request_frame(name, n):
    env = make_envelope(name, "%s#%d" % (name, n + 2), "supervisor", "cmd.process.list", None, 5000, {})
    return encode_frame(dumps(env))


class RawClient:
    """A pipe client that does what it is told and nothing else: no reader thread, no pong, no cleanup."""

    def __init__(self, pipe, name):
        self.pipe = winpipe.OverlappedPipe.connect_client(pipe, 5.0)
        self.name = name
        self.pipe.write_all(hello_frame(name))
        decoder = FrameDecoder()
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            data = self.pipe.read_some(0.1)
            if data and any(m.get("type") == "sys.welcome" for m in decoder.feed(data)):
                return
        raise AssertionError("no welcome for " + name)

    def flood(self, count):
        for n in range(count):
            self.pipe.write_all(request_frame(self.name, n), timeout_s=10.0)

    def close(self):
        self.pipe.close()


def handles_of(pid):
    return psutil.Process(pid).num_handles()


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_clients_that_close_abruptly_are_cleaned_up_without_handle_leak(chains, round_no):
    chain = chains(FULL_CHAIN, STUB_OPTS)
    before = chain.wait_ready(["storage", "engine", "manager"])
    ahk = chain.sup.ahk_pid()
    # warm up once, so lazily created handles are not counted as a leak
    RawClient(chain.sup.pipe, "warm").close()
    time.sleep(0.5)
    base = handles_of(ahk)
    t0 = time.perf_counter()
    for n in range(CYCLES):
        if n % 2:
            RawClient(chain.sup.pipe, "dropper").close()        # handshake done, then the pipe is gone
        else:
            # a pipe that never says hello and goes away
            raw = winpipe.OverlappedPipe.connect_client(chain.sup.pipe, 5.0)
            raw.close()
    elapsed = time.perf_counter() - t0
    time.sleep(1.0)                                              # let the hub notice the last closes
    after_handles = handles_of(ahk)
    print("\nMEASURE %d abrupt client closes in %.2f s; supervisor handles %d -> %d" % (CYCLES, elapsed, base, after_handles))
    assert after_handles - base <= HANDLE_SLACK, "handle leak: %d -> %d" % (base, after_handles)
    # the hub answers, the closed name is free again and nobody got marked hung
    again = connect(chain.sup.pipe, "dropper", timeout=5.0)
    try:
        assert again.welcome["payload"]["ok"], again.welcome
    finally:
        again.close()
    states = chain.states()
    for name, pid in before.items():
        assert states[name]["pid"] == pid and states[name]["state"] == "ready", (name, states[name])
    assert "flows" in chain.snapshot_ok()


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_client_that_never_reads_is_removed_on_queue_overflow_and_the_chain_stays_responsive(chains, round_no):
    chain = chains(FULL_CHAIN, STUB_OPTS)
    before = chain.wait_ready(["storage", "engine", "manager"])
    ahk = chain.sup.ahk_pid()
    base = handles_of(ahk)
    raw = RawClient(chain.sup.pipe, "flooder")
    try:
        t0 = time.perf_counter()
        try:
            raw.flood(FLOOD_REQUESTS)
        except (winpipe.PipeClosed, TimeoutError, OSError):
            pass            # the hub may already have cut us off; that is the expected outcome
        # the chain answers while the flooder is (still) connected
        t1 = time.perf_counter()
        assert "flows" in chain.snapshot_ok(timeout=3.0)
        print("\nMEASURE snapshot during the flood answered after %.3f s" % (time.perf_counter() - t1))
        time.sleep(1.0)                                  # the hub notices the overflow while pumping the answers
        states = chain.states()
        for name, pid in before.items():
            assert states[name]["pid"] == pid and states[name]["state"] == "ready", (name, states[name])
        assert handles_of(ahk) - base <= HANDLE_SLACK, "handle leak after the overflow"
        print("\nMEASURE flooder phase took %.2f s" % (time.perf_counter() - t0))
        # The supervisor log reaches the test file only when the supervisor ends (ahkrun copies it then), so
        # end the session while the flooder is still connected and read the verdict from that log.
        assert chain.request_exit()["payload"]["started"]
        assert chain.sup.wait_exit(timeout=20) is not None, "supervisor did not end"
        text = chain.sup.text()
        assert "client 'flooder' gone (queue_overflow)" in text, \
            "the hub did not drop the client that never reads:\n" + text[-2000:]
    finally:
        raw.close()


def start_storage_against(procs, datadir, hub_pipe, session_id):
    (datadir / "Flows").mkdir(exist_ok=True)
    args = ["--role=storage", "--session=" + session_id, "--hub=" + hub_pipe, "--data=" + str(datadir)]
    return RoleProc(procs, datadir, "storage", args)


def wait_hello(hub, name, timeout=15.0):
    msg = hub.wait_received(lambda m: m.get("type") == "sys.hello" and m.get("from") == name, timeout=timeout)
    assert msg is not None, "role %r never said hello" % name
    return msg["payload"]["pid"]


def cut_link(hub, name):
    """Closes the hub side of one client's pipe (the process of the client is untouched)."""
    with hub._lock:
        link = next((l for l in hub._links if l.name == name), None)
    assert link is not None, "no link %r" % name
    link.pipe.close()


def hello_count(hub, name):
    return len([m for m in list(hub.received) if m.get("type") == "sys.hello" and m.get("from") == name])


@pytest.mark.parametrize("round_no", repeat_ids())
def test_role_rebuilds_the_connection_after_the_hub_cut_its_pipe(procs, datadir, session_id, round_no):
    pipe = "ahf.%s.fb" % session_id
    run = None
    with WakingHub(pipe) as hub:
        run = start_storage_against(procs, datadir, pipe, session_id)
        try:
            pid = wait_hello(hub, "storage")
            for cut in (1, 2):
                t0 = time.perf_counter()
                cut_link(hub, "storage")
                assert wait_until(lambda: hello_count(hub, "storage") == cut + 1, ORPHAN_BUDGET_S + 2.0, step=0.02), \
                    "storage did not reconnect after cut %d:\n%s" % (cut, run.text())
                print("\nMEASURE storage reconnected %.3f s after cut %d" % (time.perf_counter() - t0, cut))
                assert time.perf_counter() - t0 <= ORPHAN_BUDGET_S, "reconnect took longer than the orphan budget"
                assert psutil.pid_exists(pid), "the role process ended"
                client = AhfClient(pipe, "tester%d" % cut)
                try:
                    answer = client.request("storage", "cmd.storage.flows.list", {}, timeout=5)
                    assert answer["payload"]["ok"], answer
                finally:
                    client.close()
        finally:
            procs.kill(run.proc)
            run.close()


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_role_ends_with_exit_4_when_its_pipe_is_cut_and_the_hub_does_not_come_back(procs, datadir, session_id,
                                                                                     round_no):
    pipe = "ahf.%s.fe" % session_id
    hub = WakingHub(pipe).start()
    run = start_storage_against(procs, datadir, pipe, session_id)
    try:
        pid = wait_hello(hub, "storage")
        ahk = psutil.Process(pid)
        t0 = time.perf_counter()
        hub.stop()                                    # the link is cut and no server instance is left
        code = ahk.wait(timeout=ORPHAN_BUDGET_S + 5.0)
        elapsed = time.perf_counter() - t0
        print("\nMEASURE pipe cut, hub gone: role ended after %.2f s, exit %s" % (elapsed, code))
        assert code == EXIT_HUB_LOST, run.text()
        assert elapsed <= ORPHAN_BUDGET_S, "role ended after %.2f s" % elapsed
        assert run.proc.wait(timeout=10) == EXIT_HUB_LOST
        assert not psutil.pid_exists(run.proc.pid), "ahkrun left behind"
    finally:
        hub.stop()
        procs.kill(run.proc)
        run.close()


def busy_flags(hub, name):
    """The `busy` values of the sys.busy messages of one role in the order the hub received them (hello = marker)."""
    flags = []
    for msg in list(hub.received):
        if msg.get("from") != name:
            continue
        if msg.get("type") == "sys.hello":
            flags.append("hello")
        elif msg.get("type") == "sys.busy":
            flags.append(bool(msg["payload"].get("busy")))
    return flags


def test_worker_announces_its_busy_state_again_after_it_rebuilt_the_connection(procs, datadir, session_id):
    """F-0026: a sys.busy {busy: false} sent while the link is down is dropped. The supervisor then keeps the worker
    as busy for ever (no ping, no pong judgement). After a reconnect the worker must announce its state, also when
    it has no job (before the fix it announced only `true` for a running job)."""
    pipe = "ahf.%s.fw" % session_id
    args = ["--role=worker", "--session=" + session_id, "--hub=" + pipe, "--data=" + str(datadir), "--flow=1"]
    with WakingHub(pipe) as hub:
        run = RoleProc(procs, datadir, "worker1", args)
        try:
            wait_hello(hub, "worker:1")
            cut_link(hub, "worker:1")
            assert wait_until(lambda: hello_count(hub, "worker:1") == 2, ORPHAN_BUDGET_S + 2.0, step=0.02), \
                "worker did not reconnect:\n" + run.text()
            assert wait_until(lambda: busy_flags(hub, "worker:1")[-1:] == [False], 3.0, step=0.02), \
                "no sys.busy false after the reconnect: %r\n%s" % (busy_flags(hub, "worker:1"), run.text())
        finally:
            procs.kill(run.proc)
            run.close()
