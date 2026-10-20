"""WI-0094: a patch changes the triggers of a flow in the trigger host (PROTOCOL 4.2 "Triggers", 4.4 "Patches", E0092).

Real session (supervisor, storage, engine, triggerhost). The triggers are Trigger_Periodic_Timer, so that the ticks show
whether the host runs the new parameters. A changed interval of an enabled trigger fires at the new interval; a removed
one fires no more and leaves the state file; a trigger added to an active flow is enabled and armed, one that does not
follow the flow starts disabled; one added to an inactive flow starts disabled; an undo brings a removed trigger back
with its old ID and the same rules; a move arms nothing again.

Timing: the upper bounds of the counts are never scaled (one tick per interval at most), the lower bounds are generous.
"""

import json
import time

import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner
from support.timing import scaled

HOST_ROLES = "storage,engine,triggerhost"
WAIT_S = 10.0
FAST_MS = "200"
NEW_TRIGGER = "element0000000900"       # no element of the test flows has this number
NEW_INDEPENDENT = "element0000000901"


@pytest.fixture
def host_flows(procs, datadir, session_id):
    """A FlowRunner whose session starts the trigger host as well."""
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


def periodic_flow(name, interval=FAST_MS):
    fb = FlowBuilder(name)
    trigger = fb.trigger("Trigger_Periodic_Timer", Interval=interval, Unit="MilliSeconds")
    done = fb.action("Action_Do_nothing")
    fb.chain(trigger, done)
    return fb, trigger


def periodic_element(element_id, interval, follows=None):
    """A new trigger for cmd.flow.patch (element.add): a periodic timer, its position below the test flows."""
    element = {"ID": element_id, "type": "trigger", "class": "Trigger_Periodic_Timer", "package": "Default",
               "packageVersion": "1.2.0", "name": "Added " + element_id, "x": "0", "y": "900", "StandardName": "1",
               "pars": {"Interval": interval, "Unit": "MilliSeconds"}, "DefaultTrigger": "0"}
    if follows is not None:
        element["followsFlow"] = follows
    return element


def patch(flows_, flow_id, ops):
    """cmd.flow.patch on the current revision of the flow; returns the answer."""
    base = flows_.request_ok("engine", "cmd.flow.get", {"flowId": flow_id})["rev"]
    return flows_.request_ok("engine", "cmd.flow.patch", {"flowId": flow_id, "baseRev": base, "ops": ops})


def definition(flows_, flow_id):
    return flows_.request_ok("engine", "cmd.flow.get", {"flowId": flow_id})["definition"]


def snapshot_flow(flows_, flow_id):
    for f in flows_.request_ok("engine", "cmd.engine.snapshot", {})["flows"]:
        if f["flowId"] == flow_id:
            return f
    return None


def trigger_state(flows_, flow_id, element_id):
    flow = snapshot_flow(flows_, flow_id) or {}
    for t in flow.get("triggers", []):
        if t["elementId"] == element_id:
            return t
    return None


def wait_state(flows_, flow_id, element_id, pred, timeout=WAIT_S):
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


def state_file(datadir, flow_id):
    """The trigger IDs that FlowStates/<flowId>.json lists as enabled ([] when there is no file or it is not read yet)."""
    path = datadir / "FlowStates" / (flow_id + ".json")
    try:
        return json.loads(path.read_text(encoding="utf-8")).get("enabled", [])
    except (OSError, ValueError):
        return []


def wait_file(datadir, flow_id, pred, timeout=WAIT_S):
    deadline = time.monotonic() + scaled(timeout)
    while time.monotonic() < deadline:
        if pred(state_file(datadir, flow_id)):
            return True
        time.sleep(0.05)
    return False


def set_interval(element_id, interval):
    return {"op": "element.update", "id": element_id, "fields": {"pars": {"Interval": interval}}}


def remove(element_id):
    return {"op": "element.remove", "id": element_id}


def add(element):
    return {"op": "element.add", "element": element}


def test_a_changed_interval_of_an_enabled_trigger_fires_at_the_new_interval(host_flows):
    fb, trigger = periodic_flow("Changed interval")
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is True) is not None, host_flows.stderr_text()
    assert len(host_flows.ended(fid, count=2, timeout=scaled(WAIT_S))) >= 2, host_flows.stderr_text()
    patch(host_flows, fid, [set_interval(trigger.id, "1000")])
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is True) is not None
    since = host_flows.mark()
    time.sleep(2.5)          # not scaled: at 1000 ms one interval holds at most 2 ticks, at the old 200 ms about 12
    ticks = host_flows.ended(fid, since=since, count=0, timeout=0)
    assert 1 <= len(ticks) <= 3, "%d ticks in 2.5 s after the change to 1000 ms" % len(ticks)


def test_a_removed_trigger_fires_no_more_and_leaves_the_state_file(host_flows):
    fb, trigger = periodic_flow("Removed")
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is True) is not None, host_flows.stderr_text()
    assert wait_file(host_flows.datadir, fid, lambda ids: trigger.id in ids), "the enabled state is not written"
    assert len(host_flows.ended(fid, count=1, timeout=scaled(WAIT_S))) >= 1
    patch(host_flows, fid, [remove(trigger.id)])
    assert trigger_state(host_flows, fid, trigger.id) is None, "the removed trigger is still in the snapshot"
    assert wait_file(host_flows.datadir, fid, lambda ids: trigger.id not in ids), "the state file keeps the trigger"
    since = host_flows.mark()
    time.sleep(scaled(0.8))
    assert started(host_flows, fid, since) == [], "a tick of the removed trigger"


def test_a_trigger_added_to_an_active_flow_is_enabled_and_armed_when_it_follows_the_flow(host_flows):
    fb, trigger = periodic_flow("Active flow")
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is True) is not None, host_flows.stderr_text()
    patch(host_flows, fid, [add(periodic_element(NEW_TRIGGER, FAST_MS)),
                            add(periodic_element(NEW_INDEPENDENT, FAST_MS, follows=False))])
    following = wait_state(host_flows, fid, NEW_TRIGGER, lambda s: s["armed"] is True)
    assert following is not None and following["enabled"] is True, "a following trigger of an active flow: " + str(following)
    independent = trigger_state(host_flows, fid, NEW_INDEPENDENT)
    assert independent is not None and independent["enabled"] is False and independent["armed"] is False, independent
    assert len(host_flows.ended(fid, count=1, timeout=scaled(WAIT_S))) >= 1
    assert wait_file(host_flows.datadir, fid, lambda ids: NEW_TRIGGER in ids), "the new trigger is not in the state file"
    assert NEW_INDEPENDENT not in state_file(host_flows.datadir, fid)


def test_a_trigger_added_to_an_inactive_flow_starts_disabled(host_flows):
    fb, trigger = periodic_flow("Inactive flow")
    fid = host_flows.add(fb)
    host_flows.start()
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["enabled"] is False) is not None, host_flows.stderr_text()
    patch(host_flows, fid, [add(periodic_element(NEW_TRIGGER, FAST_MS))])
    state = trigger_state(host_flows, fid, NEW_TRIGGER)
    assert state is not None and state["enabled"] is False and state["armed"] is False, state
    assert snapshot_flow(host_flows, fid)["enabled"] is False, "adding a trigger does not make the flow active"
    since = host_flows.mark()
    time.sleep(scaled(0.5))
    assert started(host_flows, fid, since) == [], "a disabled new trigger fired"


def test_an_undo_of_a_removal_brings_the_trigger_back_with_its_old_id_and_the_rules_of_a_new_one(host_flows):
    fb = FlowBuilder("Undo removal")
    first = fb.trigger("Trigger_Periodic_Timer", Interval=FAST_MS, Unit="MilliSeconds")
    second = fb.trigger("Trigger_Periodic_Timer", Interval=FAST_MS, Unit="MilliSeconds")
    fb.chain(first, fb.action("Action_Do_nothing"))
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    assert wait_state(host_flows, fid, second.id, lambda s: s["armed"] is True) is not None, host_flows.stderr_text()
    old = definition(host_flows, fid)["allElements"][second.id]
    patch(host_flows, fid, [remove(second.id)])
    assert trigger_state(host_flows, fid, second.id) is None
    # The first trigger still follows the flow, so the flow is active when the element comes back.
    patch(host_flows, fid, [add(old)])
    state = wait_state(host_flows, fid, second.id, lambda s: s["armed"] is True)
    assert state is not None and state["enabled"] is True, "undo of a following trigger of an active flow: %s" % state


def test_a_move_of_an_enabled_trigger_does_not_arm_it_again(host_flows):
    fb, trigger = periodic_flow("Move")
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    assert wait_state(host_flows, fid, trigger.id, lambda s: s["armed"] is True) is not None, host_flows.stderr_text()
    since = host_flows.mark()
    patch(host_flows, fid, [{"op": "element.update", "id": trigger.id, "fields": {"x": "77"}}])
    time.sleep(scaled(0.5))
    states = [m for m in host_flows.messages(since) if m.get("type") == "evt.trigger.state"
              and m["payload"].get("elementId") == trigger.id]
    assert states == [], "a move sent evt.trigger.state: %s" % states
    assert len(host_flows.ended(fid, since=since, count=1, timeout=scaled(WAIT_S))) >= 1, "the trigger stopped ticking"
