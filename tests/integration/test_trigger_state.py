"""WI-0060, E0063: the enabled state of the triggers in real sessions (supervisor, storage, engine; E0056, E0057, E0058).

The unit tests (tests/ahk/engine_trigger_state.test.ahk) and the stand-in storage of tests/integration/test_engine.py
cover the transitions and the protocol. Here the real storage writes FlowStates/<flowId>.json, and a second session on
the same data folder must find the state again. Nothing is armed yet (WI-0062): the state is checked through the engine.
"""

import json
import shutil
import time
from pathlib import Path

from support.flowrun import flows  # noqa: F401  (fixture)
from support.timing import scaled

ROOT = Path(__file__).resolve().parents[2]
SKELETON_SRC = ROOT / "tests" / "data" / "skeleton_flow.json"
TRIGGER = "element0000000001"        # the manual trigger of the skeleton, follows its flow (no followsFlow key)
INDEPENDENT = "independent"          # a second trigger that does not follow the flow
FLOW = "sw"
FILE_WAIT_S = scaled(5.0)


def prepare(flows, v1_file=False):
    """Registers the flow with the runner (a copy of the skeleton) and then writes the flow of this test over it."""
    flows.add_file(SKELETON_SRC, flow_id=FLOW)
    write_flow(flows.datadir, v1_file)


def write_flow(datadir, v1_file=False):
    """The skeleton as Flows/sw.json with the second, independent trigger. v1_file: no formatVersion and an
    "enabled" key at the first trigger (a v1 file)."""
    flow = json.loads(SKELETON_SRC.read_text(encoding="utf-8"))
    flow["name"] = FLOW
    if not v1_file:
        flow["formatVersion"] = 2
    first = flow["allElements"][TRIGGER]
    if v1_file:
        first["enabled"] = "1"
    other = dict(first)
    other["ID"] = INDEPENDENT
    other["followsFlow"] = False
    flow["allElements"][INDEPENDENT] = other
    (datadir / "Flows").mkdir(exist_ok=True)
    (datadir / "Flows" / (FLOW + ".json")).write_text(json.dumps(flow, ensure_ascii=False, indent=2), encoding="utf-8")


def state_file(datadir, flow_id=FLOW):
    return datadir / "FlowStates" / (flow_id + ".json")


def enabled_in_snapshot(flows, flow_id):
    snap = flows.request_ok("engine", "cmd.engine.snapshot", {})
    return [f["enabled"] for f in snap["flows"] if f["flowId"] == flow_id][0]


def read_state(datadir, flow_id=FLOW):
    path = state_file(datadir, flow_id)
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8-sig"))


def wait_for(predicate, timeout=FILE_WAIT_S):
    deadline = time.monotonic() + timeout
    while not predicate():
        if time.monotonic() > deadline:
            return False
        time.sleep(0.05)
    return True


def wait_for_file(path, timeout=FILE_WAIT_S):
    return wait_for(path.exists, timeout)


def test_the_switched_state_survives_a_session_restart(flows):
    prepare(flows)
    flows.start()
    flows.enable(FLOW)
    flows.request_ok("engine", "cmd.trigger.enable", {"flowId": FLOW, "elementId": INDEPENDENT})
    # The first write follows the first switch at once; the second switch comes within the interval and is written after it.
    expected = {"formatVersion": 1, "enabled": sorted([TRIGGER, INDEPENDENT])}
    assert wait_for(lambda: read_state(flows.datadir) == expected), \
        "storage did not write the state: %s" % read_state(flows.datadir)
    flows.stop()                                    # the regular end of the session (cmd.app.exit)
    flows.start()
    assert enabled_in_snapshot(flows, FLOW) is True, "the enabled state was not loaded"
    assert flows.request_ok("engine", "cmd.flow.disable", {"flowId": FLOW})["independentActive"] == 1


def test_a_v1_file_loads_disabled_in_a_real_session(flows):
    prepare(flows, v1_file=True)
    flows.start()
    assert enabled_in_snapshot(flows, FLOW) is False
    assert not state_file(flows.datadir).exists(), "nothing was switched, nothing is written"


def test_a_broken_flow_state_file_is_kept_and_the_session_starts(flows):
    prepare(flows)
    state_file(flows.datadir).parent.mkdir(exist_ok=True)
    state_file(flows.datadir).write_text("{broken", encoding="utf-8")
    flows.start()
    assert enabled_in_snapshot(flows, FLOW) is False
    # Storage renames the file on the request of the engine; the engine does not wait for that answer.
    kept = state_file(flows.datadir).with_name(FLOW + ".json.broken")
    assert wait_for_file(kept), "the broken file was not kept"
    assert kept.read_text(encoding="utf-8") == "{broken"


def test_an_unreadable_state_file_refuses_a_switch_until_it_can_be_read(flows):
    prepare(flows)
    state_file(flows.datadir).parent.mkdir(exist_ok=True)
    state_file(flows.datadir).mkdir()              # a folder where the file is: it exists and cannot be read
    flows.start()
    assert enabled_in_snapshot(flows, FLOW) is False
    answer = flows.request("engine", "cmd.flow.enable", {"flowId": FLOW})
    assert answer["ok"] is False and "cannot be read" in answer["message"], answer
    assert enabled_in_snapshot(flows, FLOW) is False, "a refused switch changes nothing"
    # The file can be read again: the next switch reads it and applies to its state.
    state_file(flows.datadir).rmdir()
    state_file(flows.datadir).write_text(json.dumps({"formatVersion": 1, "enabled": [INDEPENDENT]}), encoding="utf-8")
    mark = flows._rec.mark()
    flows.request_ok("engine", "cmd.flow.enable", {"flowId": FLOW})
    # The late read merged INDEPENDENT into the state: it is announced (and armed) as well, not only the switched trigger.
    announced = {m["payload"]["elementId"] for m in flows.messages(mark) if m.get("type") == "evt.trigger.state"
                 and m["payload"].get("enabled") is True}
    assert announced == {TRIGGER, INDEPENDENT}, announced
    expected = {"formatVersion": 1, "enabled": sorted([TRIGGER, INDEPENDENT])}
    assert wait_for(lambda: read_state(flows.datadir) == expected), read_state(flows.datadir)
