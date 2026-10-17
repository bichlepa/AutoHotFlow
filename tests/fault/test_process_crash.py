"""WI-0015: a role process is killed hard (TerminateProcess). Engine, storage, manager stub and worker.

Expected for each role (ARCHITECTURE 6.2, PROTOCOL 4.1a, 4.1 restart policy):
  - the supervisor reports evt.process.crashed (reason "exited") within CRASH_BUDGET_S of the death,
  - the restart follows the policy: engine and storage restart (attempt 1), manager and worker do not,
  - the other roles keep their pid and stay ready,
  - a request to a role that is down is answered at once (not_found), it does not hang.

Every test runs REPEATS times (AHF_FAULT_REPEAT, acceptance 20). Times are printed as MEASURE lines and
recorded in v2-phase2-final:work_items/phase2/WI-0015-fault-injection.md, section Ergebnis.
"""

import json
import time

import psutil
import pytest

from faultkit import (CRASH_BUDGET_S, FULL_CHAIN, REQUEST_BUDGET_S, HEADLESS_OPTS, RoleProc, alive, death_watch,
                      event, repeat_ids, request_ok, wait_until, write_flow)

from support import pipenames
from support.timing import scaled
from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault
WORKER_ELEMENT = "element0000000002"


def kill_role(chain, name):
    """Kills the role hard. Returns (pid, t_death, crashed message). Checks the report time against the death."""
    pid = chain.pid(name)
    death = {}
    death_watch(pid, death)
    psutil.Process(pid).kill()
    crashed = chain.rec.wait(event("evt.process.crashed", name=name), timeout=CRASH_BUDGET_S + 5)
    if crashed is None:
        # F-0071: the supervisor stderr is empty in a healthy run, so it says nothing. Show what the chain knows:
        # was the killed process really gone, what the supervisor thinks of the role, which events arrived.
        try:
            states = chain.states()
        except Exception as exc:        # the chain itself may be stuck; the message must still come out
            states = "states unavailable: %r" % (exc,)
        raise AssertionError("no evt.process.crashed for %s (pid %d, death seen by the watcher: %s):\n"
                             "states: %s\nevents: %s\nstderr:\n%s" % (
                                 name, pid, pid in death, states, [m.get("type") for _, m in chain.rec.items][-30:], chain.sup.text()))
    t_event, msg = crashed
    assert wait_until(lambda: pid in death, 3.0), "death of %s not seen" % name
    lag = t_event - death[pid]
    print("\nMEASURE crash of %s (pid %d): reported %.3f s after the death" % (name, pid, lag))
    assert -0.05 <= lag <= CRASH_BUDGET_S, "crash of %s reported %.3f s after the death" % (name, lag)
    assert msg["payload"]["pid"] == pid, msg
    assert msg["payload"]["reason"] == "exited", msg
    return pid, death[pid], msg


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_killed_engine_is_reported_restarted_and_the_others_are_untouched(chains, round_no):
    chain = chains(FULL_CHAIN, HEADLESS_OPTS)
    before = chain.wait_ready(["storage", "engine", "manager"])
    pid, t_death, msg = kill_role(chain, "engine")
    assert msg["payload"]["restart"] is True, "engine must restart by policy: %s" % msg
    new_pid, t_ready = chain.wait_restarted_ready("engine", pid)
    print("\nMEASURE engine ready again %.3f s after its death" % (t_ready - t_death))
    assert new_pid != pid
    restarted = chain.rec.wait(event("evt.process.restarted", name="engine"), timeout=scaled(5))
    assert restarted and restarted[1]["payload"]["attempt"] == 1, chain.sup.text()
    # the restarted engine announces itself (PROTOCOL 4.3); a new epoch tells the clients to resync
    announced = chain.rec.wait(lambda m: m.get("type") == "evt.engine.restarted", timeout=15)
    assert announced is not None, "no evt.engine.restarted:\n" + chain.sup.text()
    after = chain.states()
    assert after["engine"]["restarts"] == 1, after["engine"]
    for other in ("storage", "manager"):
        assert after[other]["pid"] == before[other] and after[other]["state"] == "ready", (other, after[other])
    assert "flows" in chain.snapshot_ok()           # the engine answers again


@pytest.mark.parametrize("round_no", repeat_ids())
def test_killed_storage_is_restarted_and_the_engine_keeps_running(chains, round_no):
    chain = chains(FULL_CHAIN, HEADLESS_OPTS)
    before = chain.wait_ready(["storage", "engine", "manager"])
    pid, t_death, msg = kill_role(chain, "storage")
    assert msg["payload"]["restart"], msg
    new_pid, t_ready = chain.wait_restarted_ready("storage", pid)
    print("\nMEASURE storage ready again %.3f s after its death" % (t_ready - t_death))
    restarted = chain.rec.wait(event("evt.process.restarted", name="storage"), timeout=scaled(5))
    assert restarted and restarted[1]["payload"]["attempt"] == 1
    # the restarted storage answers its requests again
    answer = request_ok(chain.obs, "storage", "cmd.storage.flows.list", {}, timeout=5)
    assert any(f["name"] == "skeleton" for f in answer["files"]), answer
    after = chain.states()
    assert after["engine"]["pid"] == before["engine"] and after["engine"]["state"] == "ready"
    assert after["manager"]["pid"] == before["manager"] and after["manager"]["state"] == "ready"


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_killed_manager_stub_is_not_restarted_and_requests_to_it_end_at_once(chains, round_no):
    chain = chains(FULL_CHAIN, HEADLESS_OPTS)
    before = chain.wait_ready(["storage", "engine", "manager"])
    _, _, msg = kill_role(chain, "manager")
    assert msg["payload"]["restart"] is False, "the UI is never restarted automatically: %s" % msg
    time.sleep(1.0)
    state = chain.states()["manager"]
    assert state["state"] == "crashed" and state["restarts"] == 0, state
    assert not chain.rec.find(event("evt.process.restarted", name="manager"))
    # a request to the dead UI ends at once with not_found (the hub answers, nothing waits)
    t0 = time.perf_counter()
    answer = chain.obs.request("manager", "cmd.test.command", {"type": "cmd.engine.snapshot", "payload": {}},
                               timeout=REQUEST_BUDGET_S * 3)
    elapsed = time.perf_counter() - t0
    print("\nMEASURE request to the dead manager answered after %.3f s" % elapsed)
    assert answer["payload"]["error"]["code"] == "not_found", answer
    assert elapsed < REQUEST_BUDGET_S, elapsed
    # engine and storage do not notice
    after = chain.states()
    assert after["engine"]["pid"] == before["engine"] and after["storage"]["pid"] == before["storage"]
    assert "flows" in chain.snapshot_ok()


@pytest.mark.slow
@pytest.mark.parametrize("round_no", repeat_ids())
def test_killed_worker_ends_its_element_with_worker_crashed_and_is_not_restarted(chains, datadir, round_no):
    """Regression of WI-0011 under the real supervisor. Since WI-0027 the engine is a child and asks the supervisor for its
    warm worker (worker:1); the supervisor still never restarts a worker, the engine asks for a new one."""
    write_flow(datadir, "w8", element_class="Action_TestHangWorker")
    chain = chains(FULL_CHAIN, HEADLESS_OPTS)
    before = chain.wait_ready(["storage", "engine", "manager", "worker:1"])
    request_ok(chain.obs, "supervisor", "cmd.topic.subscribe", {"topic": "flow:w8"})
    assert chain.rec.wait(event("evt.engine.ready"), timeout=20) is not None, chain.sup.text()
    instance = chain.obs.request("engine", "cmd.flow.start", {"flowId": "w8"}, timeout=5)["payload"]
    assert instance["ok"], instance
    # the worker element (element0000000002) must run before the worker is killed: the trigger runs first
    running = chain.rec.wait(lambda m: m.get("type") == "evt.element.state"
                             and m["payload"].get("elementId") == WORKER_ELEMENT
                             and m["payload"].get("state") == "running", timeout=10)
    assert running is not None, chain.sup.text()
    pid, t_death, msg = kill_role(chain, "worker:1")
    assert not msg["payload"]["restart"], "workers are not restarted by the supervisor: %s" % msg
    ended = chain.rec.wait(event("evt.instance.ended"), timeout=10)
    assert ended is not None, "instance did not end after the worker died:\n" + chain.sup.text()
    print("\nMEASURE worker death -> instance ended with 'worker crashed': %.3f s" % (ended[0] - t_death))
    assert ended[0] - t_death < scaled(3.0), ended[0] - t_death
    reported = chain.rec.find(lambda m: m.get("type") == "evt.element.state"
                              and "worker crashed (worker:1)" in json.dumps(m["payload"]))
    assert reported, "the element did not report 'worker crashed (worker:1)': %s" % [
        (m["type"], m["payload"]) for _, m in chain.rec.items if m.get("type", "").startswith("evt.element")]
    assert ended[1]["payload"]["reason"] == "exception", ended[1]
    # engine, storage and manager keep running; the engine has asked for a replacement (a worker with another name)
    assert "flows" in chain.snapshot_ok()
    assert wait_until(lambda: any(n != "worker:1" and p["state"] == "ready" for n, p in chain.states().items()
                                  if n.startswith("worker:")), 15.0), chain.states()
    after = chain.states()
    assert after["storage"]["pid"] == before["storage"] and after["manager"]["pid"] == before["manager"]
    assert after["engine"]["pid"] == before["engine"]
    assert after["worker:1"]["restarts"] == 0 and after["worker:1"]["state"] == "crashed", after["worker:1"]
