"""WI-0060: the enabled state of the triggers in real sessions (supervisor, storage, engine; E0056, E0057, E0058).

The unit tests (tests/ahk/engine_trigger_state.test.ahk) and the stand-in storage of tests/integration/test_engine.py
cover the transitions and the protocol. Here the real storage writes FlowState.json, and a second session on the same
data folder must find the state again. Nothing is armed yet (WI-0062): the state is checked through the engine.
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


def enabled_in_snapshot(flows, flow_id):
    snap = flows.request_ok("engine", "cmd.engine.snapshot", {})
    return [f["enabled"] for f in snap["flows"] if f["flowId"] == flow_id][0]


def wait_for_file(path, timeout=FILE_WAIT_S):
    deadline = time.monotonic() + timeout
    while not path.exists():
        if time.monotonic() > deadline:
            return False
        time.sleep(0.05)
    return True


def test_the_switched_state_survives_a_session_restart(flows):
    prepare(flows)
    flows.start()
    flows.enable(FLOW)
    flows.request_ok("engine", "cmd.trigger.enable", {"flowId": FLOW, "elementId": INDEPENDENT})
    assert wait_for_file(flows.datadir / "FlowState.json"), "storage did not write FlowState.json"
    stored = json.loads((flows.datadir / "FlowState.json").read_text(encoding="utf-8-sig"))
    assert stored == {"formatVersion": 1, "flows": {FLOW: sorted([TRIGGER, INDEPENDENT])}}
    flows.stop()                                    # the regular end of the session (cmd.app.exit)
    flows.start()
    assert enabled_in_snapshot(flows, FLOW) is True, "the enabled state was not loaded"
    assert flows.request_ok("engine", "cmd.flow.disable", {"flowId": FLOW})["independentActive"] == 1


def test_a_v1_file_loads_disabled_in_a_real_session(flows):
    prepare(flows, v1_file=True)
    flows.start()
    assert enabled_in_snapshot(flows, FLOW) is False
    assert not (flows.datadir / "FlowState.json").exists(), "nothing was switched, nothing is written"


def test_a_broken_flow_state_file_is_kept_and_the_session_starts(flows):
    prepare(flows)
    (flows.datadir / "FlowState.json").write_text("{broken", encoding="utf-8")
    flows.start()
    assert enabled_in_snapshot(flows, FLOW) is False
    assert (flows.datadir / "FlowState.json.broken").read_text(encoding="utf-8") == "{broken"
