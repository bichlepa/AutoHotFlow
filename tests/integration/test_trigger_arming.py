"""WI-0062: the engine arms the enabled triggers in the trigger host and turns their events into instances (real chain:
supervisor, storage, engine, triggerhost; PROTOCOL 4.4, ARCHITECTURE 6.1 step 4, 6.2).

The test triggers of tests/elements/Test/Triggers run in the host: Trigger_TestTimer (fires every Interval ms, its
TriggerVariables set A_TestCount to the counter of the event), Trigger_TestFireOnEnable (fires in Enable at the start
context ahfStartup), Trigger_TestFail (Enable throws). The unit tests of the arming (tests/ahk/engine_trigger_arms.test.ahk)
cover the logic with a fake peer; here the protocol and the processes are real.

The fault tests (marker foundation) kill the processes: the trigger host and the engine are restarted by the supervisor,
and the engine re-arms; a host that is not there (restart limit reached) leaves the triggers not armed and the engine
running.
"""

import json
import time

import psutil
import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner
from support.timing import scaled

HOST_ROLES = "storage,engine,triggerhost"
TIMER_INTERVAL = "200"
WAIT_S = 10.0


@pytest.fixture
def host_flows(procs, datadir, session_id):
    """A FlowRunner whose session starts the trigger host as well."""
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


def timer_flow(name, interval=TIMER_INTERVAL):
    fb = FlowBuilder(name)
    trigger = fb.trigger("Test.Trigger_TestTimer", Interval=interval)
    probe = fb.probe("A_TestCount")
    fb.chain(trigger, probe)
    return fb, trigger


def fire_on_enable_flow(name):
    fb = FlowBuilder(name)
    trigger = fb.trigger("Test.Trigger_TestFireOnEnable")
    probe = fb.probe("A_TestCount")
    fb.chain(trigger, probe)
    return fb, trigger


def snapshot_flow(flows_, flow_id):
    """The flow in the snapshot of the engine, or None: none while the engine is restarting or loading."""
    try:
        answer = flows_.request_ok("engine", "cmd.engine.snapshot", {})
    except Exception:
        return None
    for f in answer["flows"]:
        if f["flowId"] == flow_id:
            return f
    return None


def trigger_state(flows_, flow_id, element_id):
    flow = snapshot_flow(flows_, flow_id)
    for t in (flow or {}).get("triggers", []):
        if t["elementId"] == element_id:
            return t
    return None


def watch(flows_):
    """The observer gets the events of the supervisor (process) and of the engine (engine, evt.engine.ready)."""
    for topic in ("process", "engine"):
        flows_.request_ok("supervisor", "cmd.topic.subscribe", {"topic": topic})


def wait_engine_ready(flows_, since, timeout=WAIT_S):
    found = flows_.wait_message(lambda m: m.get("type") == "evt.engine.ready", timeout=timeout, since=since)
    assert found is not None, "no evt.engine.ready within %s s: %s" % (timeout, flows_.stderr_text())


def wait_state(flows_, flow_id, element_id, pred, timeout=WAIT_S):
    """The trigger state (snapshot) once pred(state) holds, or None after the timeout."""
    deadline = time.monotonic() + scaled(timeout)
    while time.monotonic() < deadline:
        state = trigger_state(flows_, flow_id, element_id)
        if state is not None and pred(state):
            return state
        time.sleep(0.05)
    return None


def started(flows_, flow_id, since=0):
    return [m for m in flows_.messages(since) if m.get("type") == "evt.instance.started"
            and m["payload"].get("flowId") == flow_id]


def pid_of(flows_, name):
    for p in flows_.request_ok("supervisor", "cmd.process.list", {})["processes"]:
        if p["name"] == name:
            return p["pid"]
    raise AssertionError("no process %s in the process list" % name)


def kill(flows_, name):
    psutil.Process(pid_of(flows_, name)).kill()


def wait_process_event(flows_, type_, name, since, timeout=WAIT_S):
    found = flows_.wait_message(lambda m: m.get("type") == type_ and m["payload"].get("name") == name,
                                timeout=timeout, since=since)
    assert found is not None, "no %s of %s within %s s:\n%s" % (type_, name, timeout, flows_.stderr_text())
    return found


def test_an_enabled_trigger_is_armed_and_its_events_start_instances_with_their_variables(host_flows):
    fb, trigger = timer_flow("Arm timer")
    fid = host_flows.add(fb)
    host_flows.start()
    since = host_flows.mark()
    host_flows.enable(fid)
    armed = wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is True)
    assert armed is not None and armed["enabled"] is True and armed["message"] == "", armed
    ended = host_flows.ended(fid, since=since, count=3, timeout=scaled(WAIT_S))
    assert len(ended) >= 3, host_flows.stderr_text()
    value = host_flows.read_probe("A_TestCount")
    assert value is not None and value.text.isdigit() and int(value.text) >= 1, value


def test_disabling_the_flow_disarms_the_trigger_and_no_instance_starts_after_it(host_flows):
    fb, trigger = timer_flow("Disarm timer")
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is True) is not None
    host_flows.ended(fid, count=1, timeout=scaled(WAIT_S))
    host_flows.request_ok("engine", "cmd.flow.disable", {"flowId": fid})
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is False) is not None
    since = host_flows.mark()
    time.sleep(scaled(0.8))
    assert started(host_flows, fid, since) == [], "an instance started after the disable"


def test_the_arming_is_announced_with_evt_trigger_state(host_flows):
    fb, trigger = timer_flow("Announce timer")
    fid = host_flows.add(fb)
    host_flows.start()
    since = host_flows.mark()
    host_flows.enable(fid)
    found = host_flows.wait_message(lambda m: m.get("type") == "evt.trigger.state"
                                    and m["payload"].get("elementId") == trigger.id
                                    and m["payload"].get("armed") is True, timeout=WAIT_S, since=since)
    assert found is not None, host_flows.stderr_text()
    payload = found[1]["payload"]
    assert payload["enabled"] is True and payload["message"] == ""


def test_a_parameter_that_cannot_be_evaluated_is_not_armed_and_the_engine_runs_on(host_flows):
    fb, trigger = timer_flow("Broken parameter", interval="1 +")
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    state = wait_state(host_flows, fid, trigger.id, lambda s: s["message"] != "")
    assert state is not None and state["armed"] is False and state["enabled"] is True, state
    assert host_flows.request_ok("engine", "cmd.engine.snapshot", {})["ready"] is True


def test_an_unknown_class_and_a_missing_package_are_not_armed_with_their_message(host_flows):
    fb = FlowBuilder("Unknown triggers")
    unknown = fb.trigger("Test.Trigger_Missing")
    package = fb.trigger("NoSuchPackage.Trigger_Manual")
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    for element in (unknown, package):
        state = wait_state(host_flows, fid, element.id, lambda s: s["message"] != "")
        assert state is not None and state["armed"] is False, (element.id, state)
    assert host_flows.request_ok("engine", "cmd.engine.snapshot", {})["ready"] is True


def test_a_trigger_whose_enable_fails_is_not_armed_and_the_others_are(host_flows):
    fb = FlowBuilder("Refused trigger")
    refused = fb.trigger("Test.Trigger_TestFail")
    good = fb.trigger("Test.Trigger_TestTimer", Interval=TIMER_INTERVAL)
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    bad = wait_state(host_flows, fid, refused.id, lambda s: s["message"] != "")
    assert bad is not None and bad["armed"] is False, bad
    assert wait_state(host_flows, fid, good.id, lambda s: s["armed"] is True) is not None


def test_the_startup_trigger_fires_once_at_the_start_of_autohotflow(host_flows):
    fb, trigger = fire_on_enable_flow("Startup")
    fid = host_flows.add(fb)
    state_file = {"formatVersion": 1, "flows": {fid: [trigger.id]}}
    (host_flows.datadir / "FlowState.json").write_text(json.dumps(state_file), encoding="utf-8")
    host_flows.start()
    ended = host_flows.ended(fid, count=1, timeout=scaled(WAIT_S))
    assert len(ended) == 1, host_flows.stderr_text()
    time.sleep(scaled(0.5))
    assert len(started(host_flows, fid)) == 1, "the startup trigger fires once per start of AutoHotFlow"


@pytest.mark.foundation
def test_the_trigger_host_is_restarted_and_its_triggers_fire_again(host_flows):
    fb, trigger = timer_flow("Host restart")
    fid = host_flows.add(fb)
    host_flows.start()
    watch(host_flows)
    host_flows.enable(fid)
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is True) is not None
    host_flows.ended(fid, count=1, timeout=scaled(WAIT_S))
    since = host_flows.mark()
    kill(host_flows, "triggerhost")
    wait_process_event(host_flows, "evt.process.crashed", "triggerhost", since)
    wait_process_event(host_flows, "evt.process.ready", "triggerhost", since)
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is True) is not None, host_flows.stderr_text()
    before = len(started(host_flows, fid, since))
    assert len(host_flows.ended(fid, since=since, count=before + 2, timeout=scaled(WAIT_S))) >= before + 2


@pytest.mark.foundation
def test_the_engine_is_restarted_and_rearms_without_the_startup_context(host_flows):
    startup_fb, startup = fire_on_enable_flow("Startup after restart")
    timer_fb, timer = timer_flow("Timer after restart")
    sid = host_flows.add(startup_fb)
    tid = host_flows.add(timer_fb)
    state_file = {"formatVersion": 1, "flows": {sid: [startup.id]}}
    (host_flows.datadir / "FlowState.json").write_text(json.dumps(state_file), encoding="utf-8")
    host_flows.start()
    watch(host_flows)
    host_flows.enable(tid)
    assert len(host_flows.ended(sid, count=1, timeout=scaled(WAIT_S))) == 1
    assert wait_state(host_flows, tid, timer.id, lambda s: s["armed"] is True) is not None
    since = host_flows.mark()
    kill(host_flows, "engine")
    wait_process_event(host_flows, "evt.process.crashed", "engine", since)
    wait_process_event(host_flows, "evt.process.ready", "engine", since)
    wait_engine_ready(host_flows, since)
    assert wait_state(host_flows, tid, timer.id, lambda s: s["armed"] is True) is not None, host_flows.stderr_text()
    assert wait_state(host_flows, sid, startup.id, lambda s: s["armed"] is True) is not None
    time.sleep(scaled(0.5))
    assert started(host_flows, sid, since) == [], "the startup trigger does not fire after a restart of the engine"
    assert len(host_flows.ended(tid, since=since, count=2, timeout=scaled(WAIT_S))) >= 2


@pytest.mark.foundation
def test_a_host_that_is_not_there_leaves_the_triggers_not_armed_and_the_engine_running(host_flows):
    fb, trigger = timer_flow("No host")
    fid = host_flows.add(fb)
    host_flows.start()
    watch(host_flows)
    host_flows.enable(fid)
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is True) is not None
    # The supervisor restarts the host up to its limit (3 in 60 s); the next end is final.
    for attempt in range(4):
        since = host_flows.mark()
        kill(host_flows, "triggerhost")
        wait_process_event(host_flows, "evt.process.crashed", "triggerhost", since)
        if attempt < 3:                 # the supervisor restarts it, the next kill needs its new pid
            wait_process_event(host_flows, "evt.process.ready", "triggerhost", since)
    state = wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is False and s["message"] != "")
    assert state is not None, host_flows.stderr_text()
    assert host_flows.request_ok("engine", "cmd.engine.snapshot", {})["ready"] is True
