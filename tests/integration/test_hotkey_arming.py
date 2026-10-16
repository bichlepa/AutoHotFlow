"""WI-0067 (acceptance S0003): the hotkey trigger in a real session WITHOUT keys (the trigger host registers the hotkey,
the engine knows the state; no key is pressed, so no input is sent and no lock is needed).

- an enabled hotkey trigger is armed by the trigger host (evt.trigger.state armed, no message);
- disabling the flow disarms it; enabling it again arms it;
- after a restart of the trigger host the trigger is armed again.

The hotkey with real input (a key that really fires the flow) is the open decision on how keys are delivered in tests
(doc/MANUAL-CHECKS.md section 6); it is not in this file.
"""

import json
import time

import psutil
import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner
from support.timing import scaled

HOST_ROLES = "storage,engine,triggerhost"
HOTKEY = "vk9D"          # an unassigned virtual key (E0059): registering it sends no input
WAIT_S = 10.0


@pytest.fixture
def host_flows(procs, datadir, session_id):
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


def hotkey_state(runner, flow_id, trigger_id):
    for f in runner.request_ok("engine", "cmd.engine.snapshot", {})["flows"]:
        if f["flowId"] == flow_id:
            for t in f.get("triggers", []):
                if t["elementId"] == trigger_id:
                    return t
    return None


def wait_for(runner, flow_id, trigger_id, pred, timeout=WAIT_S):
    deadline = time.monotonic() + scaled(timeout)
    while time.monotonic() < deadline:
        state = hotkey_state(runner, flow_id, trigger_id)
        if state is not None and pred(state):
            return state
        time.sleep(0.05)
    return None


def test_an_enabled_hotkey_trigger_is_armed_and_disabling_the_flow_disarms_it(host_flows):
    fb = FlowBuilder("hotkey-arming")
    trigger = fb.trigger("Trigger_Hotkey", hotkey=HOTKEY, BlockKey="0", UseWindow="Everywhere")
    fb.chain(trigger, fb.action("Action_Do_nothing"))
    fid = host_flows.add(fb)
    state_dir = host_flows.datadir / "FlowStates"
    state_dir.mkdir(exist_ok=True)
    (state_dir / (fid + ".json")).write_text(json.dumps({"formatVersion": 1, "enabled": [trigger.id]}),
                                             encoding="utf-8")
    host_flows.start()
    armed = wait_for(host_flows, fid, trigger.id, lambda s: s["armed"] is True)
    assert armed is not None, (hotkey_state(host_flows, fid, trigger.id), host_flows.stderr_text())
    assert armed["enabled"] is True and "set" in armed["message"], armed    # the host reports the registration

    host_flows.request_ok("engine", "cmd.flow.disable", {"flowId": fid})
    assert wait_for(host_flows, fid, trigger.id, lambda s: s["armed"] is False and s["enabled"] is False) is not None, \
        host_flows.stderr_text()

    host_flows.request_ok("engine", "cmd.flow.enable", {"flowId": fid})
    again = wait_for(host_flows, fid, trigger.id, lambda s: s["armed"] is True)
    assert again is not None, host_flows.stderr_text()


def test_the_hotkey_trigger_is_armed_again_after_a_restart_of_the_trigger_host(host_flows):
    fb = FlowBuilder("hotkey-restart")
    trigger = fb.trigger("Trigger_Hotkey", hotkey="vk9C", BlockKey="0", UseWindow="Everywhere")
    fb.chain(trigger, fb.action("Action_Do_nothing"))
    fid = host_flows.add(fb)
    state_dir = host_flows.datadir / "FlowStates"
    state_dir.mkdir(exist_ok=True)
    (state_dir / (fid + ".json")).write_text(json.dumps({"formatVersion": 1, "enabled": [trigger.id]}),
                                             encoding="utf-8")
    host_flows.start()
    assert wait_for(host_flows, fid, trigger.id, lambda s: s["armed"] is True) is not None, host_flows.stderr_text()
    pid = None
    for p in host_flows.request_ok("supervisor", "cmd.process.list", {})["processes"]:
        if p["name"] == "triggerhost":
            pid = p["pid"]
    assert pid is not None, "no triggerhost in the process list"
    psutil.Process(pid).kill()
    # the supervisor restarts the host; the engine arms the trigger again after the restart (the "not armed" state in
    # between may be too short to poll, so only the end state is asserted)
    back = wait_for(host_flows, fid, trigger.id, lambda s: s["armed"] is True, timeout=20)
    assert back is not None, (hotkey_state(host_flows, fid, trigger.id), host_flows.stderr_text())
