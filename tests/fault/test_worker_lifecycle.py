"""WI-27: life cycle of the worker pool under the real supervisor, storage and engine (ARCHITECTURE 6.4).

A Chain (faultkit) is a supervisor with storage and engine as children, plus a Python observer. The pool
options of the engine (--workers, --warm-workers, --worker-idle-ms) are passed on by the supervisor. The
product start (no options at all) is the first test. Flows with a worker element are written into the data
directory before the chain starts (the engine loads them at its start).

Times are printed as MEASURE lines. Budgets are generous because the tests also run in parallel under load.
"""

import time

import psutil
import pytest

from support.timing import scaled
from faultkit import CRASH_BUDGET_S, alive, event, repeat_ids, request_ok, wait_until, write_flow

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault
WORKER_ELEMENT = "element0000000002"
TRIGGER_ELEMENT = "element0000000001"
READY_S = 20.0


# --- helpers ---------------------------------------------------------------------------------------

def start_chain(chains, datadir, flows, extra=()):
    """flows: {name: (element class, pars)}. Returns the chain with storage and engine ready, subscribed to the flows."""
    for name, (cls, pars) in flows.items():
        write_flow(datadir, name, cls, pars)
    chain = chains("storage,engine", list(extra))
    chain.wait_ready(["storage", "engine"], timeout=READY_S)
    assert chain.rec.wait(event("evt.engine.ready"), timeout=READY_S) is not None, chain.sup.text()
    for name in flows:
        request_ok(chain.obs, "supervisor", "cmd.topic.subscribe", {"topic": "flow:" + name})
    return chain


def workers(chain):
    return {n: p for n, p in chain.states().items() if n.startswith("worker:")}


def live_workers(chain):
    return {n: p for n, p in workers(chain).items() if p["state"] in ("starting", "ready", "stopping", "hung")}


def ready_workers(chain):
    return {n: p for n, p in workers(chain).items() if p["state"] == "ready"}


def start_flow(chain, flow):
    answer = chain.obs.request("engine", "cmd.flow.start", {"flowId": flow}, timeout=5)["payload"]
    assert answer["ok"], answer
    return answer["instanceId"]


def ended(chain, instance, timeout=10.0):
    got = chain.rec.wait(lambda m: m.get("type") == "evt.instance.ended" and m["payload"].get("instanceId") == instance,
                         timeout=scaled(timeout))
    assert got is not None, "instance %s did not end:\n%s" % (instance, chain.sup.text())
    return got


def worker_element(chain, flow, since=0.0):
    """The evt.element.state messages of the worker element of the flow after the time since: [(t, payload)]."""
    return [(t, m["payload"]) for t, m in chain.rec.find(
        lambda m: m.get("type") == "evt.element.state" and m["payload"].get("flowId") == flow
        and m["payload"].get("elementId") == WORKER_ELEMENT) if t >= since]


def final_state(chain, flow, since=0.0):
    states = worker_element(chain, flow, since)
    assert states, "no state events of the worker element of %s" % flow
    return states[-1][1]


def run_echo_ok(chain, flow="wecho"):
    """Starts the echo flow and expects a normal end. Returns the instance end message."""
    t0 = time.perf_counter()
    instance = start_flow(chain, flow)
    t, msg = ended(chain, instance, timeout=15.0)
    assert msg["payload"]["reason"] == "finished", (msg, final_state(chain, flow, t0))
    return t - t0


def exited_killed(chain, name, timeout):
    return chain.rec.wait(event("evt.process.exited", name=name, reason="killed"), timeout=scaled(timeout))


ECHO = {"wecho": ("Action_TestEchoWorker", None)}


# --- start, first job ------------------------------------------------------------------------------

def test_product_start_without_test_options_runs_a_worker_element(chains, datadir):
    """No pool option at all: the engine asks for its warm worker and the worker element runs."""
    chain = start_chain(chains, datadir, ECHO)
    chain.wait_ready(["worker:1"], timeout=READY_S)
    assert list(live_workers(chain)) == ["worker:1"]
    t_first = run_echo_ok(chain)
    print("\nMEASURE warm worker: flow start -> instance ended (incl. a 250 ms hub wake of the python request): %.3f s"
          % t_first)
    assert list(live_workers(chain)) == ["worker:1"], "the job must not start a second worker"


def test_time_to_the_first_job_when_the_worker_has_to_be_started_cold(chains, datadir):
    """--warm-workers=0: the pool is empty, the first job waits for a new process. Measured as the time from the
    end of the trigger element to the start of the worker element (both are engine events)."""
    chain = start_chain(chains, datadir, ECHO, ["--warm-workers=0"])
    assert not live_workers(chain)
    t0 = time.perf_counter()
    instance = start_flow(chain, "wecho")
    ended(chain, instance, timeout=15.0)
    trigger_done = [t for t, p in worker_element_of(chain, "wecho", TRIGGER_ELEMENT, t0) if p["state"] == "finished"]
    started = [t for t, p in worker_element(chain, "wecho", t0) if p["state"] == "running"]
    assert trigger_done and started
    cold = started[0] - trigger_done[0]
    print("\nMEASURE cold start: trigger finished -> worker element running (spawn, process start, ready): %.0f ms"
          % (cold * 1000))
    assert cold < 3.0, cold          # 300 ms is the aim (WI-27); this limit only catches a pool that does not start
    assert len(workers(chain)) == 1


def worker_element_of(chain, flow, element, since=0.0):
    return [(t, m["payload"]) for t, m in chain.rec.find(
        lambda m: m.get("type") == "evt.element.state" and m["payload"].get("flowId") == flow
        and m["payload"].get("elementId") == element) if t >= since]


def test_no_pool_means_worker_not_available(chains, datadir):
    chain = start_chain(chains, datadir, ECHO, ["--workers=0"])
    assert not workers(chain)
    instance = start_flow(chain, "wecho")
    ended(chain, instance, timeout=10.0)
    state = final_state(chain, "wecho")
    assert state["state"] == "exception" and "worker not available" in state["message"], state
    assert not workers(chain)


# --- a long blocking call ----------------------------------------------------------------------------

@pytest.mark.slow
def test_a_worker_that_blocks_longer_than_6_s_is_not_hung_and_the_element_ends_normal(chains, datadir):
    chain = start_chain(chains, datadir, {"wlong": ("Action_TestLongBlockWorker", None)})
    name = next(iter(chain.wait_ready(["worker:1"], timeout=READY_S)))
    t0 = time.perf_counter()
    instance = start_flow(chain, "wlong")
    t, msg = ended(chain, instance, timeout=20.0)
    print("\nMEASURE long blocking worker element ended normal after %.1f s" % (t - t0))
    assert msg["payload"]["reason"] == "finished", final_state(chain, "wlong")
    assert t - t0 > 7.0
    assert not chain.rec.find(event("evt.process.hung", name=name)), chain.sup.text()
    assert not chain.rec.find(event("evt.process.crashed", name=name))
    assert name in ready_workers(chain)


# --- cancel, deadline ---------------------------------------------------------------------------------

@pytest.mark.slow
def test_cancel_of_a_frozen_worker_ends_the_instance_at_once_and_the_process_is_killed_and_replaced(chains, datadir):
    flows = dict(ECHO, wfreeze=("Action_TestFreezeWorker", None))
    chain = start_chain(chains, datadir, flows)
    old = next(iter(chain.wait_ready(["worker:1"], timeout=READY_S)))
    old_pid = chain.pid(old)
    instance = start_flow(chain, "wfreeze")
    assert chain.rec.wait(lambda m: m.get("type") == "evt.element.state" and m["payload"].get("flowId") == "wfreeze"
                          and m["payload"].get("elementId") == WORKER_ELEMENT
                          and m["payload"].get("state") == "running", timeout=10) is not None
    time.sleep(0.3)             # the worker has started the element and is blocked in it
    t0 = time.perf_counter()
    request_ok(chain.obs, "engine", "cmd.flow.stop", {"flowId": "wfreeze"})
    t_end, msg = ended(chain, instance, timeout=5.0)
    print("\nMEASURE stop of a frozen worker element: instance ended after %.3f s (python request incl.)" % (t_end - t0))
    assert msg["payload"]["reason"] == "flow.stop"
    got = exited_killed(chain, old, timeout=10.0)
    assert got is not None, "the frozen worker was not killed:\n" + chain.sup.text()
    print("MEASURE stop -> frozen worker killed (exited, reason killed): %.2f s" % (got[0] - t0))
    assert got[0] - t0 < scaled(6.0)
    assert not alive(old_pid)
    assert not chain.rec.find(event("evt.process.crashed", name=old))
    run_echo_ok(chain)          # a replacement serves the next job
    assert old not in live_workers(chain)


@pytest.mark.slow
def test_job_deadline_ends_the_element_with_worker_timeout_and_kills_the_worker(chains, datadir):
    flows = dict(ECHO, wtimeout=("Action_TestFreezeTimeoutWorker", None))
    chain = start_chain(chains, datadir, flows)
    old = next(iter(chain.wait_ready(["worker:1"], timeout=READY_S)))
    t0 = time.perf_counter()
    instance = start_flow(chain, "wtimeout")
    t_end, msg = ended(chain, instance, timeout=10.0)
    state = final_state(chain, "wtimeout")
    print("\nMEASURE job deadline 1500 ms: instance ended after %.2f s" % (t_end - t0))
    assert state["state"] == "exception" and state["message"] == "worker timeout", state
    assert msg["payload"]["reason"] == "exception"
    assert t_end - t0 > 1.3
    got = exited_killed(chain, old, timeout=10.0)
    assert got is not None, "the frozen worker was not killed:\n" + chain.sup.text()
    print("MEASURE job deadline -> frozen worker killed: %.2f s" % (got[0] - t0))
    run_echo_ok(chain)


# --- crash ----------------------------------------------------------------------------------------------

def test_killed_worker_ends_its_element_with_worker_crashed_and_the_pool_has_a_replacement(chains, datadir):
    flows = dict(ECHO, whang=("Action_TestHangWorker", None))
    chain = start_chain(chains, datadir, flows)
    old = next(iter(chain.wait_ready(["worker:1"], timeout=READY_S)))
    old_pid = chain.pid(old)
    instance = start_flow(chain, "whang")
    assert chain.rec.wait(lambda m: m.get("type") == "evt.element.state" and m["payload"].get("flowId") == "whang"
                          and m["payload"].get("elementId") == WORKER_ELEMENT
                          and m["payload"].get("state") == "running", timeout=10) is not None
    time.sleep(0.3)
    t0 = time.perf_counter()
    psutil.Process(old_pid).kill()
    t_end, msg = ended(chain, instance, timeout=10.0)
    print("\nMEASURE kill of a busy worker -> instance ended: %.3f s" % (t_end - t0))
    state = final_state(chain, "whang")
    assert state["state"] == "exception" and state["message"] == "worker crashed (%s)" % old, state
    assert msg["payload"]["reason"] == "exception"
    # the supervisor does not restart the worker, the engine asks for a new one (warm worker)
    assert chain.rec.find(event("evt.process.crashed", name=old, restart=False))
    assert wait_until(lambda: ready_workers(chain) and old not in ready_workers(chain), READY_S), chain.sup.text()
    run_echo_ok(chain)


@pytest.mark.parametrize("round_no", repeat_ids())
def test_worker_killed_before_it_answers_the_run_ends_the_element_with_worker_crashed_and_is_reported_as_crashed(
        chains, datadir, round_no):
    """F-46 (WI-35), deterministic: the run is open at the frozen worker (the hub holds it, hub.routedOpen >= 1), then
    the worker dies. The hub answers peer_gone at once, before the supervisor has judged the end of the process. The
    engine must not read that as a refusal, and the supervisor must not report the end as a planned "killed"."""
    flows = dict(ECHO, whang=("Action_TestHangWorker", None))
    chain = start_chain(chains, datadir, flows)
    old = next(iter(chain.wait_ready(["worker:1"], timeout=READY_S)))
    old_pid = chain.pid(old)
    chain.freeze(old_pid)
    instance = start_flow(chain, "whang")

    def run_is_open():
        snap = request_ok(chain.obs, "supervisor", "cmd.diag.snapshot", {})["snapshot"]
        return snap["hub"]["routedOpen"] >= 1
    assert wait_until(run_is_open, scaled(10.0)), "the run never reached the hub:\n" + chain.sup.text()
    t0 = time.perf_counter()
    psutil.Process(old_pid).kill()
    crashed = chain.rec.wait(event("evt.process.crashed", name=old, restart=False), timeout=CRASH_BUDGET_S + 5)
    assert crashed is not None, "no evt.process.crashed for %s:\n%s" % (old, chain.sup.text())
    print("\nMEASURE worker killed with an open run -> crashed reported: %.3f s" % (crashed[0] - t0))
    assert crashed[0] - t0 <= CRASH_BUDGET_S + 0.25, crashed[0] - t0     # 0.25: the observer's wake-up delay
    assert chain.rec.find(event("evt.process.exited", name=old, reason="killed")) == [], \
        "the death was reported as a planned end:\n" + chain.sup.text()
    t_end, msg = ended(chain, instance, timeout=3.0)
    assert t_end - t0 <= scaled(3.0), t_end - t0
    state = final_state(chain, "whang")
    assert state["state"] == "exception" and state["message"] == "worker crashed (%s)" % old, state


@pytest.mark.slow
def test_frozen_worker_does_not_answer_the_run_and_is_replaced(chains, datadir):
    chain = start_chain(chains, datadir, ECHO)
    old = next(iter(chain.wait_ready(["worker:1"], timeout=READY_S)))
    chain.freeze(chain.pid(old))
    t0 = time.perf_counter()
    instance = start_flow(chain, "wecho")
    t_end, msg = ended(chain, instance, timeout=15.0)
    state = final_state(chain, "wecho")
    assert state["state"] == "exception" and ("worker not available: %s (timeout)" % old) in state["message"], state
    print("\nMEASURE frozen worker: no answer to cmd.worker.run -> element ended after %.1f s" % (t_end - t0))
    assert 4.5 < t_end - t0 < 5.0 + scaled(4.0), t_end - t0
    run_echo_ok(chain)          # the frozen one was killed, a new one serves the next job


@pytest.mark.slow
def test_five_failures_within_a_minute_block_the_pool(chains, datadir):
    chain = start_chain(chains, datadir, ECHO, ["--workers=2"])
    killed = []
    for _ in range(5):
        def fresh():
            live = {n: p for n, p in live_workers(chain).items() if n not in killed and p["pid"]}
            return next(iter(live.items()), None)
        found = wait_until(fresh, READY_S)
        assert found, "no (new) worker to kill after %s:\n%s" % (killed, chain.sup.text())
        name, info = found
        killed.append(name)
        psutil.Process(info["pid"]).kill()
        assert chain.rec.wait(event("evt.process.crashed", name=name), timeout=scaled(5)) is not None
    # the fifth failure blocks the pool: no sixth worker, a worker element ends with "worker not available"
    time.sleep(1.5)
    assert not live_workers(chain), live_workers(chain)
    instance = start_flow(chain, "wecho")
    ended(chain, instance, timeout=10.0)
    state = final_state(chain, "wecho")
    assert state["state"] == "exception" and "worker not available" in state["message"], state
    assert not live_workers(chain)


# --- restart of the engine -------------------------------------------------------------------------------

@pytest.mark.slow
def test_engine_restart_during_a_worker_job_leaves_no_orphan_and_the_next_job_runs(chains, datadir):
    flows = dict(ECHO, wfreeze=("Action_TestFreezeWorker", None))
    chain = start_chain(chains, datadir, flows)
    old = next(iter(chain.wait_ready(["worker:1"], timeout=READY_S)))
    old_pid = chain.pid(old)
    start_flow(chain, "wfreeze")
    assert chain.rec.wait(lambda m: m.get("type") == "evt.element.state" and m["payload"].get("flowId") == "wfreeze"
                          and m["payload"].get("elementId") == WORKER_ELEMENT
                          and m["payload"].get("state") == "running", timeout=10) is not None
    time.sleep(0.3)
    engine_pid = chain.pid("engine")
    t0 = time.perf_counter()
    psutil.Process(engine_pid).kill()
    new_engine, _ = chain.wait_restarted_ready("engine", engine_pid, timeout=15.0)
    # "ready" in the supervisor is the hello of the engine; the flows are loaded later (F-49)
    chain.wait_flows(["wecho"], timeout=READY_S)
    assert wait_until(lambda: not alive(old_pid), 10.0), "the orphan %s (pid %d) still lives:\n%s" % (
        old, old_pid, chain.sup.text())
    print("\nMEASURE engine killed -> orphan worker gone: %.2f s" % (time.perf_counter() - t0))
    # exactly the new engine's warm worker is left
    assert wait_until(lambda: len(ready_workers(chain)) == 1 and old not in live_workers(chain), READY_S), \
        "workers after the restart: %s" % workers(chain)
    assert exited_engine_gone(chain, old, timeout=2.0) is not None      # WI-33 (E10): reason "engine gone", was "killed"
    run_echo_ok(chain)
    assert len(live_workers(chain)) == 1, live_workers(chain)


@pytest.mark.slow
def test_f49_restarted_engine_is_ready_for_the_supervisor_before_it_has_loaded_its_flows(chains, datadir):
    """F-49, deterministic: storage is frozen, so the restarted engine can say hello (state "ready" in the
    supervisor) but cannot load its flows. A start in this window is answered with not_found. This is the
    documented order (PROTOCOL 4.3: evt.engine.ready only after loading), so a test that starts a flow after an
    engine restart has to wait for the flows first (chain.wait_flows)."""
    chain = start_chain(chains, datadir, ECHO)
    storage_pid = chain.pid("storage")
    engine_pid = chain.pid("engine")
    chain.freeze(storage_pid)
    psutil.Process(engine_pid).kill()
    chain.wait_restarted_ready("engine", engine_pid, timeout=15.0)
    answer = chain.obs.request("engine", "cmd.flow.start", {"flowId": "wecho"}, timeout=5)["payload"]
    assert answer["ok"] is False and answer["error"]["code"] == "not_found", answer
    assert "not loaded" in answer["error"]["message"], answer


# --- the workers end with the engine (WI-33, E10) -------------------------------------------------------------

ENGINE_GONE_BUDGET_S = scaled(1.5)          # the aim is 1 s (WI-33); the margin is 0.5 s, three times that in the parallel run


def exited_engine_gone(chain, name, timeout):
    return chain.rec.wait(event("evt.process.exited", name=name, reason="engine gone"), timeout=scaled(timeout))


@pytest.mark.slow
def test_engine_killed_during_a_hanging_job_ends_the_worker_at_once_and_the_new_engine_builds_the_pool(chains, datadir):
    flows = dict(ECHO, whang=("Action_TestHangWorker", None))
    chain = start_chain(chains, datadir, flows)
    old = next(iter(chain.wait_ready(["worker:1"], timeout=READY_S)))
    old_pid = chain.pid(old)
    start_flow(chain, "whang")
    assert chain.rec.wait(lambda m: m.get("type") == "evt.element.state" and m["payload"].get("flowId") == "whang"
                          and m["payload"].get("elementId") == WORKER_ELEMENT
                          and m["payload"].get("state") == "running", timeout=10) is not None
    time.sleep(0.3)             # the worker has the job and hangs in it
    engine_pid = chain.pid("engine")
    t0 = time.perf_counter()
    psutil.Process(engine_pid).kill()
    gone = wait_until(lambda: not alive(old_pid), 10.0)
    took = time.perf_counter() - t0
    print("\nMEASURE engine killed -> worker with a hanging job gone: %.2f s" % took)
    assert gone, "the worker %s (pid %d) still lives:\n%s" % (old, old_pid, chain.sup.text())
    assert took < ENGINE_GONE_BUDGET_S, took
    got = exited_engine_gone(chain, old, timeout=3.0)
    assert got is not None, "no evt.process.exited with reason 'engine gone':\n" + chain.sup.text()
    assert not chain.rec.find(event("evt.process.crashed", name=old))
    chain.wait_restarted_ready("engine", engine_pid, timeout=15.0)
    chain.wait_flows(["wecho"], timeout=READY_S)        # F-49
    assert wait_until(lambda: len(ready_workers(chain)) == 1 and old not in live_workers(chain), READY_S), \
        "workers after the restart: %s" % workers(chain)
    run_echo_ok(chain)          # the new engine's pool serves a new job


@pytest.mark.slow
def test_engine_beyond_the_restart_limit_leaves_no_worker(chains, datadir):
    flows = dict(ECHO, whang=("Action_TestHangWorker", None))
    chain = start_chain(chains, datadir, flows, ["--test-roles", "--restart-max=0"])
    old = next(iter(chain.wait_ready(["worker:1"], timeout=READY_S)))
    old_pid = chain.pid(old)
    start_flow(chain, "whang")
    assert chain.rec.wait(lambda m: m.get("type") == "evt.element.state" and m["payload"].get("flowId") == "whang"
                          and m["payload"].get("elementId") == WORKER_ELEMENT
                          and m["payload"].get("state") == "running", timeout=10) is not None
    time.sleep(0.3)
    psutil.Process(chain.pid("engine")).kill()
    assert chain.rec.wait(event("evt.process.crashed", name="engine", restart=False), timeout=10) is not None
    assert wait_until(lambda: not alive(old_pid), 5.0), "the worker lives although the engine is gone for good:\n" \
        + chain.sup.text()
    assert exited_engine_gone(chain, old, timeout=3.0) is not None
    time.sleep(1.5)
    assert not live_workers(chain), live_workers(chain)


# --- limit, demand, idle end ---------------------------------------------------------------------------------

@pytest.mark.slow
def test_more_jobs_than_the_limit_wait_and_the_limit_is_never_exceeded(chains, datadir):
    names = ["wb%d" % i for i in range(4)]
    flows = {n: ("Action_TestBlockWorker", {"Duration": "1500"}) for n in names}
    chain = start_chain(chains, datadir, flows, ["--workers=2"])
    chain.wait_ready(["worker:1"], timeout=READY_S)
    instances = [start_flow(chain, n) for n in names]
    peak_processes = 0
    deadline = time.monotonic() + 30.0
    ends = set()
    while time.monotonic() < deadline and len(ends) < len(names):
        peak_processes = max(peak_processes, len(live_workers(chain)))
        for i in instances:
            if chain.rec.find(lambda m, i=i: m.get("type") == "evt.instance.ended" and m["payload"].get("instanceId") == i):
                ends.add(i)
        time.sleep(0.1)
    assert len(ends) == len(names), "ended: %s\n%s" % (ends, chain.sup.text())
    for n in names:
        assert final_state(chain, n)["state"] == "finished", (n, final_state(chain, n))
    # element concurrency from the engine events: +1 at running, -1 at finished
    events = sorted((t, p["state"]) for n in names for t, p in worker_element(chain, n)
                    if p["state"] in ("running", "finished", "exception"))
    level = peak = 0
    for _, state in events:
        level += 1 if state == "running" else -1
        peak = max(peak, level)
    print("\nMEASURE 4 jobs, limit 2: peak jobs at once %d, peak worker processes %d" % (peak, peak_processes))
    assert peak == 2, peak
    assert peak_processes <= 2, peak_processes
    assert len(workers(chain)) <= 2, workers(chain)


@pytest.mark.slow
def test_idle_workers_beyond_the_warm_one_end_after_the_idle_time(chains, datadir):
    names = ["wi%d" % i for i in range(3)]
    flows = {n: ("Action_TestBlockWorker", {"Duration": "2500"}) for n in names}
    chain = start_chain(chains, datadir, flows, ["--workers=3", "--warm-workers=1", "--worker-idle-ms=1500"])
    chain.wait_ready(["worker:1"], timeout=READY_S)
    instances = [start_flow(chain, n) for n in names]
    for i in instances:
        ended(chain, i, timeout=30.0)
    # three workers were needed at some time
    assert len(workers(chain)) >= 3 or wait_until(lambda: len(workers(chain)) >= 3, 1.0)
    t0 = time.perf_counter()
    assert wait_until(lambda: len(live_workers(chain)) == 1, 20.0), "workers: %s" % workers(chain)
    print("\nMEASURE workers beyond the warm one ended %.2f s after the last job" % (time.perf_counter() - t0))
    killed = chain.rec.find(event("evt.process.exited", reason="killed"))
    assert len(killed) == 2, [m["payload"] for _, m in killed]
    time.sleep(3.0)                          # the warm worker stays
    assert len(live_workers(chain)) == 1 and len(ready_workers(chain)) == 1, workers(chain)
