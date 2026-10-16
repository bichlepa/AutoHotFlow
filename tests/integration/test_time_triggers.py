"""WI-0063: the time triggers Trigger_Periodic_Timer and Trigger_Start_up in a real session (supervisor, storage, engine,
triggerhost; PROTOCOL 4.4, ELEMENT-API-V2 3.5). The classes are in src/elements/Default/Triggers/.

Timing: the count of events is bounded from above by the time the timer could run at most (one interval per tick), so
the upper bound is never scaled (as in test_triggerhost.py); the lower bounds are generous.

Start up (REQ-TRG-220): a trigger fires once per start of AutoHotFlow when it is enabled in its
FlowStates/<flowId>.json; with the type Windows only when the supervisor was started with --windows-startup; not when
it is enabled later, and (foundation marker) not after a restart of the trigger host.
"""

import json
import time

import psutil
import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner
from support.timing import scaled

HOST_ROLES = "storage,engine,triggerhost"
WAIT_S = 10.0
INTERVAL_MS = 200


@pytest.fixture
def host_flows(procs, datadir, session_id):
    """A FlowRunner whose session starts the trigger host as well."""
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


def periodic_flow(name, interval=str(INTERVAL_MS), unit="MilliSeconds"):
    fb = FlowBuilder(name)
    trigger = fb.trigger("Trigger_Periodic_Timer", Interval=interval, Unit=unit)
    done = fb.action("Action_Do_nothing")
    fb.chain(trigger, done)
    return fb, trigger


def startup_flow(name, startup_type="AutoHotFlow"):
    fb = FlowBuilder(name)
    trigger = fb.trigger("Trigger_Start_up", startupType=startup_type)
    done = fb.action("Action_Do_nothing")
    fb.chain(trigger, done)
    return fb, trigger


def write_flow_state(datadir, enabled):
    """FlowStates/<flowId>.json (E0063) with the given triggers enabled.
    enabled maps a flow ID to a list of trigger IDs."""
    (datadir / "FlowStates").mkdir(exist_ok=True)
    for flow_id, trigger_ids in enabled.items():
        state = {"formatVersion": 1, "enabled": trigger_ids}
        (datadir / "FlowStates" / (flow_id + ".json")).write_text(json.dumps(state), encoding="utf-8")


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


def watch(flows_):
    """The observer gets the events of the supervisor (process)."""
    flows_.request_ok("supervisor", "cmd.topic.subscribe", {"topic": "process"})


def pid_of(flows_, name):
    for p in flows_.request_ok("supervisor", "cmd.process.list", {})["processes"]:
        if p["name"] == name:
            return p["pid"]
    raise AssertionError("no process %s in the process list" % name)


def wait_process_event(flows_, type_, name, since, timeout=WAIT_S):
    found = flows_.wait_message(lambda m: m.get("type") == type_ and m["payload"].get("name") == name,
                                timeout=timeout, since=since)
    assert found is not None, "no %s of %s within %s s:\n%s" % (type_, name, timeout, flows_.stderr_text())
    return found


def test_the_periodic_timer_fires_about_every_interval(host_flows):
    fb, trigger = periodic_flow("Periodic")
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is True) is not None, host_flows.stderr_text()
    began = time.monotonic()
    ended = host_flows.ended(fid, count=4, timeout=scaled(WAIT_S))
    elapsed = time.monotonic() - began
    assert len(ended) >= 4, host_flows.stderr_text()
    # The fourth tick comes four intervals after the timer was set, and the timer was set before the state was seen.
    assert elapsed >= 3 * INTERVAL_MS / 1000.0, "four ticks in %.3f s: the timer is faster than its interval" % elapsed
    # Never scaled: one second holds at most 1000 / INTERVAL_MS + 1 ticks.
    since = host_flows.mark()
    time.sleep(1.0)
    in_one_second = host_flows.ended(fid, since=since, count=0, timeout=0)
    assert len(in_one_second) <= 1000 // INTERVAL_MS + 1, "%d ticks in one second" % len(in_one_second)


def test_disabling_the_flow_stops_the_periodic_timer(host_flows):
    fb, trigger = periodic_flow("Periodic disable")
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is True) is not None
    assert len(host_flows.ended(fid, count=1, timeout=scaled(WAIT_S))) >= 1
    host_flows.request_ok("engine", "cmd.flow.disable", {"flowId": fid})
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is False) is not None
    since = host_flows.mark()
    time.sleep(scaled(0.8))
    assert started(host_flows, fid, since) == [], "a tick after the disable"


def test_a_bad_parameter_of_a_time_trigger_is_not_armed_and_gives_the_v1_text(host_flows):
    fb = FlowBuilder("Bad time triggers")
    zero = fb.trigger("Trigger_Periodic_Timer", Interval="0", Unit="Seconds")
    unit = fb.trigger("Trigger_Periodic_Timer", Interval="5", Unit="Hours")
    kind = fb.trigger("Trigger_Start_up", startupType="Shutdown")
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    # The message before the arming is "trigger host is not running", so the wait is for the v1 text itself.
    state = wait_state(host_flows, fid, zero.id, lambda s: s["message"] == "Parameter 'interval' has invalid value: 0")
    assert state is not None and state["armed"] is False and state["enabled"] is True, state
    state = wait_state(host_flows, fid, unit.id, lambda s: s["message"] == "Parameter 'Unit' has invalid value: Hours")
    assert state is not None and state["armed"] is False, state
    state = wait_state(host_flows, fid, kind.id,
                       lambda s: s["message"] == "Parameter 'startupType' has invalid value: Shutdown")
    assert state is not None and state["armed"] is False, state
    assert host_flows.request_ok("engine", "cmd.engine.snapshot", {})["ready"] is True


def test_the_autohotflow_startup_trigger_fires_once_at_the_start(host_flows):
    fb, trigger = startup_flow("Startup")
    fid = host_flows.add(fb)
    write_flow_state(host_flows.datadir, {fid: [trigger.id]})
    host_flows.start()
    assert len(host_flows.ended(fid, count=1, timeout=scaled(WAIT_S))) == 1, host_flows.stderr_text()
    time.sleep(scaled(0.5))
    assert len(started(host_flows, fid)) == 1, "the start-up trigger fires once per start of AutoHotFlow"


def test_the_windows_startup_trigger_fires_only_with_the_windows_option(host_flows):
    ahf_fb, ahf = startup_flow("Startup AHF")
    win_fb, win = startup_flow("Startup Windows", startup_type="Windows")
    ahf_id = host_flows.add(ahf_fb)
    win_id = host_flows.add(win_fb)
    write_flow_state(host_flows.datadir, {ahf_id: [ahf.id], win_id: [win.id]})
    host_flows.start()
    assert len(host_flows.ended(ahf_id, count=1, timeout=scaled(WAIT_S))) == 1, host_flows.stderr_text()
    time.sleep(scaled(0.5))
    assert started(host_flows, win_id) == [], "the Windows type fires without --windows-startup"
    # A new start with --windows-startup: both types fire once (a start with Windows is also a start of AutoHotFlow).
    host_flows.stop()
    host_flows.start(extra=["--windows-startup"])
    assert len(host_flows.ended(win_id, count=1, timeout=scaled(WAIT_S))) == 1, host_flows.stderr_text()
    assert len(host_flows.ended(ahf_id, count=1, timeout=scaled(WAIT_S))) == 1, host_flows.stderr_text()
    time.sleep(scaled(0.5))
    assert len(started(host_flows, win_id)) == 1 and len(started(host_flows, ahf_id)) == 1


def test_a_startup_trigger_enabled_later_does_not_fire(host_flows):
    # The first arming pass carries the start context and consumes it, whether or not it arms anything. A probe flow
    # enabled before the start is armed by that pass: once it is armed, the pass is over, and the flow enabled later
    # gets no token. (Without the probe the test would enable the flow before the trigger host is ready.)
    probe_fb, probe = periodic_flow("Probe", interval="60", unit="Seconds")
    probe_fid = host_flows.add(probe_fb)
    fb, trigger = startup_flow("Enabled later")
    fid = host_flows.add(fb)
    write_flow_state(host_flows.datadir, {probe_fid: [probe.id]})
    host_flows.start()
    assert wait_state(host_flows, probe_fid, probe.id, lambda s: s["armed"] is True) is not None, host_flows.stderr_text()
    host_flows.enable(fid)
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is True) is not None, host_flows.stderr_text()
    time.sleep(scaled(0.5))
    assert started(host_flows, fid) == [], "the start-up trigger fires when it is enabled after the start"


@pytest.mark.foundation
def test_the_startup_trigger_does_not_fire_after_a_restart_of_the_trigger_host(host_flows):
    fb, trigger = startup_flow("Startup after host restart")
    fid = host_flows.add(fb)
    write_flow_state(host_flows.datadir, {fid: [trigger.id]})
    host_flows.start()
    watch(host_flows)
    assert len(host_flows.ended(fid, count=1, timeout=scaled(WAIT_S))) == 1, host_flows.stderr_text()
    since = host_flows.mark()
    psutil.Process(pid_of(host_flows, "triggerhost")).kill()
    wait_process_event(host_flows, "evt.process.crashed", "triggerhost", since)
    wait_process_event(host_flows, "evt.process.ready", "triggerhost", since)
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is True) is not None, host_flows.stderr_text()
    time.sleep(scaled(0.5))
    assert len(started(host_flows, fid)) == 1, "the start-up trigger fired again after a restart of the host"
