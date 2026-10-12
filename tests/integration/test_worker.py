"""WI-11: worker role (src/worker/).

The worker runs as a real process (src/AutoHotFlow.ahk --role=worker --flow=<n>, started through
tools/ahkrun.py). Its hub is the Python stand-in tests/support/pyhub.py (WakingHub, RoleHub from
test_role). The test plays the engine: an AhfClient named "engine" sends cmd.worker.run and
cmd.worker.cancel and receives evt.worker.done. The engine itself (WorkerBridge) is tested in
test_worker_pool.py (supervisor commands) and tests/fault/test_worker_lifecycle.py (pool rules of the engine).
"""

import time

import pytest

from support.ahfclient import AhfClient
from test_role import (FLOOD_PINGS, STALL_S, RoleHub, RoleRun, StallingHub, ahk_process, first_pong_of,
                       flood_pings, pongs_from, wait_hello)

ROOT_TIMEOUT_S = 5.0
CANCEL_BUDGET_S = 0.5          # acceptance: cmd.worker.cancel -> evt.worker.done "stopped" within 500 ms
PING_BUDGET_S = 0.05           # pings during a blocking element are answered while it blocks
BLOCK_MS = 800                 # Action_TestBlockWorker blocks for this long


@pytest.fixture
def pipe(session_id):
    return "ahf.worker.%s" % session_id


@pytest.fixture
def runs(procs):
    started = []
    yield started
    for run in started:
        run.close_files()


@pytest.fixture
def hub(pipe):
    with RoleHub(pipe) as h:
        yield h


def start_worker(procs, datadir, runs, pipe, session_id, n=1):
    args = ["--role=worker", "--session=" + session_id, "--hub=" + pipe, "--data=" + str(datadir),
            "--flow=%d" % n]
    run = RoleRun(procs, datadir, "worker%d" % n, args)
    runs.append(run)
    return run


def run_payload(exec_id, cls, params=None, imports=None):
    return {
        "execId": exec_id,
        "class": cls,
        "params": params or {},
        "imports": imports or {},
        "env": {"flowId": "Flow 1", "elementId": "element0000000001", "instanceId": "inst-1",
                "threadId": "thr-1"},
        "timeoutMs": 5000,
    }


def send_run(engine, payload, worker="worker:1"):
    """cmd.worker.run; returns the answer payload (ok is expected)."""
    return engine.request(worker, "cmd.worker.run", payload, timeout=ROOT_TIMEOUT_S)["payload"]


def done_for(engine, exec_id, timeout=ROOT_TIMEOUT_S):
    """Waits for evt.worker.done of one execution (others are skipped)."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        for msg in engine.events(timeout=0.5):
            if msg.get("type") == "evt.worker.done" and msg["payload"].get("execId") == exec_id:
                return msg["payload"]
    raise AssertionError("no evt.worker.done for %s within %.1f s" % (exec_id, timeout))


@pytest.fixture
def worker(procs, datadir, runs, pipe, session_id, hub):
    start_worker(procs, datadir, runs, pipe, session_id)
    wait_hello(hub, "worker:1")
    eng = AhfClient(pipe, "engine")
    yield eng
    eng.close()


@pytest.fixture
def supervisor_client(pipe, hub):
    """Stands in for the supervisor, which receives sys.bye (the hub has no supervisor of its own here)."""
    client = AhfClient(pipe, "supervisor")
    yield client
    client.close()


# --- protocol: run, result, errors -----------------------------------------------------------------

def test_run_is_accepted_at_once_and_the_result_comes_as_done(worker):
    ans = send_run(worker, run_payload("e1", "Action_TestEchoWorker"))
    assert ans["ok"]
    done = done_for(worker, "e1")
    assert done["result"] == "normal"
    assert done["exports"] == {"out": ""}


def test_element_that_blocks_finishes_normal_after_its_time(worker):
    t0 = time.perf_counter()
    assert send_run(worker, run_payload("e2", "Action_TestBlockWorker"))["ok"]
    done = done_for(worker, "e2")
    elapsed_ms = (time.perf_counter() - t0) * 1000
    assert done["result"] == "normal"
    assert elapsed_ms >= BLOCK_MS - 50, elapsed_ms


def test_second_run_while_busy_is_answered_with_busy(worker):
    assert send_run(worker, run_payload("e3", "Action_TestBlockWorker"))["ok"]
    ans = send_run(worker, run_payload("e4", "Action_TestBlockWorker"))
    assert not ans["ok"]
    assert ans["error"]["code"] == "busy"
    assert done_for(worker, "e3")["result"] == "normal"


def test_worker_is_reusable_after_done(worker):
    assert send_run(worker, run_payload("e5", "Action_TestEchoWorker"))["ok"]
    assert done_for(worker, "e5")["result"] == "normal"
    assert send_run(worker, run_payload("e6", "Action_TestEchoWorker"))["ok"]
    assert done_for(worker, "e6")["result"] == "normal"


def test_unknown_class_is_an_exception_not_a_crash(worker):
    assert send_run(worker, run_payload("e7", "Action_Nope"))["ok"]
    done = done_for(worker, "e7")
    assert done["result"] == "exception"
    assert "unknown element class" in done["message"]


def test_inline_element_is_refused_as_exception(worker):
    assert send_run(worker, run_payload("e8", "Action_Sleep", {"Duration": "1"}))["ok"]
    done = done_for(worker, "e8")
    assert done["result"] == "exception"
    assert "not a worker element" in done["message"]


def test_throwing_element_is_reported_as_exception_and_the_worker_keeps_running(worker):
    assert send_run(worker, run_payload("e9", "Action_TestThrowWorker"))["ok"]
    done = done_for(worker, "e9")
    assert done["result"] == "exception"
    assert done["message"] == "test worker throw"
    assert send_run(worker, run_payload("e10", "Action_TestEchoWorker"))["ok"]
    assert done_for(worker, "e10")["result"] == "normal"


def test_run_without_execid_is_bad_payload(worker):
    payload = run_payload("", "Action_TestEchoWorker")
    del payload["execId"]
    ans = worker.request("worker:1", "cmd.worker.run", payload, timeout=ROOT_TIMEOUT_S)["payload"]
    assert not ans["ok"]
    assert ans["error"]["code"] == "bad_payload"


def test_cancel_of_unknown_execution_is_not_found(worker):
    ans = worker.request("worker:1", "cmd.worker.cancel", {"execId": "nope"}, timeout=ROOT_TIMEOUT_S)["payload"]
    assert not ans["ok"]
    assert ans["error"]["code"] == "not_found"


# --- cancel, pings, shutdown -----------------------------------------------------------------------

def test_cancel_stops_the_running_element_and_reports_stopped_within_500_ms(worker):
    assert send_run(worker, run_payload("c1", "Action_TestBlockWorker"))["ok"]
    time.sleep(0.1)
    t0 = time.perf_counter()
    ans = worker.request("worker:1", "cmd.worker.cancel", {"execId": "c1"}, timeout=ROOT_TIMEOUT_S)["payload"]
    assert ans["ok"]
    done = done_for(worker, "c1")
    elapsed = time.perf_counter() - t0
    assert done["result"] == "stopped"
    assert elapsed < CANCEL_BUDGET_S, elapsed
    # The element's own Finish comes at 800 ms after its start, while this window is open. It must not
    # produce a second evt.worker.done for c1.
    late = [m for m in worker.events(timeout=1.2) if m.get("type") == "evt.worker.done"]
    assert not late, late
    assert send_run(worker, run_payload("c2", "Action_TestEchoWorker"))["ok"]
    assert done_for(worker, "c2")["result"] == "normal"


def test_cancel_of_the_hang_element_reports_stopped_within_500_ms(worker):
    assert send_run(worker, run_payload("h1", "Action_TestHangWorker"))["ok"]
    time.sleep(0.2)
    t0 = time.perf_counter()
    ans = worker.request("worker:1", "cmd.worker.cancel", {"execId": "h1"}, timeout=ROOT_TIMEOUT_S)["payload"]
    assert ans["ok"]
    done = done_for(worker, "h1")
    elapsed = time.perf_counter() - t0
    assert done["result"] == "stopped"
    print("MEASURE cancel Action_TestHangWorker -> stopped (ms): %.1f" % (elapsed * 1000))
    assert elapsed < CANCEL_BUDGET_S, elapsed


def test_pings_are_answered_while_a_blocking_element_runs(worker):
    assert send_run(worker, run_payload("p1", "Action_TestBlockWorker"))["ok"]
    answered = []
    t0 = time.perf_counter()
    for n in (1, 2, 3):
        # sys.pong answers the ping (corr), so it is taken with request(), not from the event stream
        pong = worker.request("worker:1", "sys.ping", {"n": n}, timeout=1.0)
        answered.append((n, pong["payload"]["n"], time.perf_counter() - t0))
    assert [a[1] for a in answered] == [1, 2, 3]
    assert answered[-1][2] < BLOCK_MS / 1000.0
    assert done_for(worker, "p1")["result"] == "normal"


def test_shutdown_while_running_reports_stopped_before_bye(worker, supervisor_client, hub):
    assert send_run(worker, run_payload("s1", "Action_TestBlockWorker"))["ok"]
    time.sleep(0.1)
    hub.send_to("worker:1", "sys.shutdown", {"reason": "user", "deadlineMs": 2000})
    seen = []
    bye = None
    deadline = time.monotonic() + 5.0
    while bye is None and time.monotonic() < deadline:
        for msg in worker.events(timeout=0.5):
            if msg.get("type") == "evt.worker.done" and msg["payload"].get("execId") == "s1":
                seen.append("done:" + msg["payload"]["result"])
        for msg in supervisor_client.events(timeout=0.1):
            if msg.get("type") == "sys.bye":
                seen.append("bye")
                bye = msg
                break
    assert seen == ["done:stopped", "bye"], seen
    assert bye["payload"]["clean"]


def test_shutdown_with_a_job_and_a_hub_that_reads_late_still_delivers_stopped_and_bye(procs, datadir, runs, pipe,
                                                                                       session_id):
    # WI-30 (F-26 cause A): at sys.shutdown the send queue of the worker is full (the hub reads nothing for
    # STALL_S). evt.worker.done "stopped" still reaches the engine, and sys.bye comes after it.
    with StallingHub(pipe, first_pong_of("worker:1"), STALL_S) as hub:
        run = start_worker(procs, datadir, runs, pipe, session_id)
        ahk = ahk_process(wait_hello(hub, "worker:1"))
        with AhfClient(pipe, "engine") as eng:
            assert send_run(eng, run_payload("f1", "Action_TestHangWorker"))["ok"]
            time.sleep(0.2)
            flood_pings(hub, "worker:1")
            hub.send_to("worker:1", "sys.shutdown", {"reason": "user", "deadlineMs": 3000})
            assert ahk.wait(timeout=10) == 0, run.stderr_text()
            assert done_for(eng, "f1")["result"] == "stopped"
            bye = hub.wait_received(lambda m: m.get("type") == "sys.bye" and m.get("from") == "worker:1", timeout=5)
            assert hub.stalled.is_set()
            assert bye is not None and bye["payload"]["clean"] is True, "sys.bye lost"
            assert pongs_from(hub, "worker:1") == list(range(1, FLOOD_PINGS + 1))
            types = [m.get("type") for m in hub.received if m.get("from") == "worker:1"]
            assert types.index("evt.worker.done") < types.index("sys.bye"), types[-5:]


# --- sys.busy (WI-27) ------------------------------------------------------------------------------

def busy_messages(supervisor_client, window=1.0):
    return [m["payload"]["busy"] for m in supervisor_client.events(timeout=window) if m.get("type") == "sys.busy"]


def test_worker_reports_busy_when_a_job_begins_and_ends(worker, supervisor_client):
    assert send_run(worker, run_payload("b1", "Action_TestBlockWorker"))["ok"]
    assert done_for(worker, "b1")["result"] == "normal"
    assert busy_messages(supervisor_client) == [True, False]


def test_worker_reports_not_busy_after_a_cancel_too(worker, supervisor_client):
    assert send_run(worker, run_payload("b2", "Action_TestHangWorker"))["ok"]
    time.sleep(0.2)
    assert worker.request("worker:1", "cmd.worker.cancel", {"execId": "b2"}, timeout=ROOT_TIMEOUT_S)["payload"]["ok"]
    assert done_for(worker, "b2")["result"] == "stopped"
    assert busy_messages(supervisor_client) == [True, False]
