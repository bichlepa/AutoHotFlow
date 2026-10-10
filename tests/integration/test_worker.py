"""WI-11: worker role (src/worker/).

The worker runs as a real process (src/AutoHotFlow.ahk --role=worker --flow=<n>, started through
tools/ahkrun.py). Its hub is the Python stand-in tests/support/pyhub.py (WakingHub, RoleHub from
test_role). The test plays the engine: an AhfClient named "engine" sends cmd.worker.run and
cmd.worker.cancel and receives evt.worker.done. The engine itself (WorkerBridge) is tested in
test_worker_engine.py.
"""

import shutil
import sys
import time

import psutil
import pytest

from support.ahfclient import AhfClient
from test_engine import (SKELETON_SRC, SLEEP, StorageStub, ask, collect_until, element_states, is_type, make_flow,
                         observer, stop_flow, wait_ready)
from test_role import AHKRUN, ENTRY, ROOT, RoleHub, RoleRun, wait_hello

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


# --- engine side: WorkerBridge (src/engine/WorkerBridge.ahk) ------------------------------------
# The engine runs as a real process with --workers=N. Its storage is the StorageStub of test_engine.
# The workers are real worker processes. Tests without a supervisor use the Python hub (RoleHub); the
# crash test runs a real supervisor, because only the supervisor sees process deaths (topic "process").

ENGINE_READY_S = 15.0
RUNNING_S = 5.0


@pytest.fixture
def flowdir(datadir):
    """A data directory with the skeleton flow in Flows/, as storage would hold it."""
    (datadir / "Flows").mkdir()
    shutil.copy(SKELETON_SRC, datadir / "Flows" / "skeleton.json")
    return datadir


@pytest.fixture
def storage(hub, pipe, flowdir):
    stub = StorageStub(pipe, flowdir).start()
    yield stub
    stub.close()


def start_engine_with_pool(procs, datadir, runs, pipe, session_id, workers):
    args = ["--role=engine", "--session=" + session_id, "--hub=" + pipe, "--data=" + str(datadir),
            "--workers=%d" % workers]
    run = RoleRun(procs, datadir, "engine", args)
    runs.append(run)
    return run


def start_flow(obs, flow_id):
    """cmd.flow.start; returns the instance id."""
    return ask(obs, "cmd.flow.start", {"flowId": flow_id})["instanceId"]


def is_running(element_id=SLEEP):
    return lambda m: (m.get("type") == "evt.element.state" and m["payload"]["state"] == "running"
                      and m["payload"]["elementId"] == element_id)


@pytest.fixture
def worker1(procs, datadir, runs, session_id, pipe, hub, flowdir, storage):
    """One worker process (worker:1). The engine is started by each test, after its observer subscribed."""
    start_worker(procs, datadir, runs, pipe, session_id)
    wait_hello(hub, "worker:1")


def test_worker_element_runs_through_the_pool_and_the_flow_continues(worker1, procs, datadir, runs, session_id, pipe, hub, flowdir, storage):
    make_flow(flowdir, "w1", element_class="Action_TestEchoWorker")
    with observer(pipe, "engine", "flow:w1") as obs:
        start_engine_with_pool(procs, flowdir, runs, pipe, session_id, workers=1)
        wait_ready(obs, timeout=ENGINE_READY_S)
        start_flow(obs, "w1")
        got = collect_until(obs, is_type("evt.instance.ended"), timeout=RUNNING_S)
        sleep_states = [s[:2] for s in element_states(got) if s[0] == SLEEP]
        assert sleep_states == [(SLEEP, "running"), (SLEEP, "finished")], sleep_states
        assert got[-1][1]["payload"]["reason"] == "finished"
    hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})


def test_snapshot_is_answered_within_50_ms_while_a_worker_element_blocks(worker1, procs, datadir, runs, session_id, pipe, hub, flowdir, storage):
    make_flow(flowdir, "w2", element_class="Action_TestBlockWorker")
    with observer(pipe, "engine", "flow:w2") as obs:
        start_engine_with_pool(procs, flowdir, runs, pipe, session_id, workers=1)
        wait_ready(obs, timeout=ENGINE_READY_S)
        t_start = time.perf_counter()
        start_flow(obs, "w2")
        times = []
        for _ in range(4):
            t0 = time.perf_counter()
            snap = ask(obs, "cmd.engine.snapshot")
            times.append(time.perf_counter() - t0)
            assert snap["ok"]
        got = collect_until(obs, is_type("evt.instance.ended"), timeout=RUNNING_S)
        finished_at = got[-1][0] - t_start
        # the snapshots were answered while the element was still running (Action_TestBlockWorker: 800 ms)
        assert finished_at > 0.6, finished_at
        print("MEASURE snapshot during worker block (ms):", ["%.1f" % (t * 1000) for t in times])
        assert max(times) < 0.05, ["%.1f ms" % (t * 1000) for t in times]
    hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})


def test_stop_during_a_worker_element_ends_the_instance_within_500_ms_and_the_slot_is_free_again(
        worker1, procs, datadir, runs, session_id, pipe, hub, flowdir, storage):
    make_flow(flowdir, "w3", element_class="Action_TestBlockWorker")
    make_flow(flowdir, "w4", element_class="Action_TestEchoWorker")
    with observer(pipe, "engine", "flow:w3", "flow:w4") as obs:
        start_engine_with_pool(procs, flowdir, runs, pipe, session_id, workers=1)
        wait_ready(obs, timeout=ENGINE_READY_S)
        start_flow(obs, "w3")
        collect_until(obs, is_running(), timeout=RUNNING_S)
        t0 = time.perf_counter()
        assert stop_flow(obs, "w3")["stopped"] == 1
        got = collect_until(obs, is_type("evt.instance.ended"), timeout=RUNNING_S)
        elapsed = got[-1][0] - t0
        assert got[-1][1]["payload"]["reason"] == "flow.stop"
        assert elapsed < 0.5, elapsed
        # the worker reports "stopped" and its slot becomes idle again: the next element runs
        start_flow(obs, "w4")
        got = collect_until(obs, is_type("evt.instance.ended"), timeout=RUNNING_S)
        assert [st[:2] for st in element_states(got) if st[0] == SLEEP][-1] == (SLEEP, "finished")
    hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})


def test_without_a_connected_worker_the_element_is_an_exception_not_a_hang(procs, datadir, runs, session_id,
                                                                          pipe, hub, flowdir, storage):
    make_flow(flowdir, "w5", element_class="Action_TestEchoWorker")
    with observer(pipe, "engine", "flow:w5") as obs:
        start_engine_with_pool(procs, flowdir, runs, pipe, session_id, workers=1)   # no worker process
        wait_ready(obs, timeout=ENGINE_READY_S)
        t0 = time.perf_counter()
        start_flow(obs, "w5")
        got = collect_until(obs, is_type("evt.instance.ended"), timeout=RUNNING_S)
        assert time.perf_counter() - t0 < 2.0
        last = element_states(got)[-1]
        assert last[1] == "exception" and "worker not available" in last[3], last
    hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})


def test_frozen_worker_does_not_confirm_the_cancel_and_its_slot_is_down_after_the_orphan_deadline(
        worker1, procs, datadir, runs, session_id, pipe, hub, flowdir, storage):
    # A frozen worker (psutil suspend) answers nothing, so the cancel is never confirmed. The engine still ends
    # the instance at once; the slot stays busy for ORPHAN_MS (2 s), then it is down and jobs fail.
    make_flow(flowdir, "w6", element_class="Action_TestHangWorker")
    make_flow(flowdir, "w7", element_class="Action_TestEchoWorker")
    worker_pid = worker1_pid(hub)
    with observer(pipe, "engine", "flow:w6", "flow:w7") as obs:
        start_engine_with_pool(procs, flowdir, runs, pipe, session_id, workers=1)
        wait_ready(obs, timeout=ENGINE_READY_S)
        start_flow(obs, "w6")
        collect_until(obs, is_running(), timeout=RUNNING_S)
        time.sleep(0.3)                       # the worker has started the element
        psutil.Process(worker_pid).suspend()
        t0 = time.perf_counter()
        stop_flow(obs, "w6")
        got = collect_until(obs, is_type("evt.instance.ended"), timeout=RUNNING_S)
        assert got[-1][0] - t0 < 0.5
        time.sleep(2.5)
        start_flow(obs, "w7")
        got = collect_until(obs, is_type("evt.instance.ended"), timeout=RUNNING_S)
        last = element_states(got)[-1]
        assert last[1] == "exception" and "worker not available" in last[3], last
    hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})


def worker1_pid(hub):
    """The pid of worker:1 from its sys.hello (wait_hello returns it)."""
    return wait_hello(hub, "worker:1")


# --- crash of a worker (real supervisor) ---------------------------------------------------------

def wait_worker_pid(obs, name, timeout=15.0):
    """Polls cmd.process.list until the worker is ready; returns its pid."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        answer = obs.request("supervisor", "cmd.process.list", {}, timeout=5)
        for p in answer["payload"].get("processes", []):
            if p["name"] == name and p["state"] == "ready":
                return p["pid"]
        time.sleep(0.1)
    raise AssertionError("worker %s not ready within %.1f s" % (name, timeout))


def test_killed_worker_ends_its_element_with_worker_crashed(procs, datadir, runs, session_id, flowdir):
    pipe = "ahf.%s.hub" % session_id
    sup_err = open(datadir / "sup.stderr", "wb")
    procs.start([sys.executable, str(AHKRUN), "--timeout", "120", str(ENTRY), "--session=" + session_id,
                 "--data=" + str(flowdir), "--start=worker:1"],
                stdout=sup_err, stderr=sup_err, cwd=str(ROOT))
    make_flow(flowdir, "w8", element_class="Action_TestHangWorker")
    storage = StorageStub(pipe, flowdir).start()
    try:
        with observer(pipe, "engine", "flow:w8", "process") as obs:
            worker_pid = wait_worker_pid(obs, "worker:1")
            start_engine_with_pool(procs, flowdir, runs, pipe, session_id, workers=1)
            wait_ready(obs, timeout=ENGINE_READY_S)
            start_flow(obs, "w8")
            collect_until(obs, is_running(), timeout=RUNNING_S)
            t0 = time.perf_counter()
            psutil.Process(worker_pid).kill()
            got = collect_until(obs, is_type("evt.instance.ended"), timeout=10.0)
            elapsed = got[-1][0] - t0
            last = element_states(got)[-1]
            assert last[1] == "exception" and last[3] == "worker crashed (worker:1)", last
            assert got[-1][1]["payload"]["reason"] == "exception"
            print("MEASURE kill -> instance ended with worker crashed (ms): %.1f" % (elapsed * 1000))
            assert elapsed < 3.0, elapsed
    finally:
        storage.close()
        sup_err.close()
