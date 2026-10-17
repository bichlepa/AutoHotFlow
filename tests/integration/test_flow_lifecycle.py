"""WI-0070: create, rename, duplicate and delete a flow in real sessions (supervisor, storage, engine).

The storage part (cmd.storage.flow.delete, cmd.storage.flow.write with createOnly) and the engine commands are checked
against the real files of the data folder. The rules of the commands are in doc/PROTOCOL.md 4.2 (flow lifecycle) and
4.6.
"""

import json
from pathlib import Path

from support.flowrun import flows, write_var  # noqa: F401  (fixture flows)

ROOT = Path(__file__).resolve().parents[2]
SKELETON_SRC = ROOT / "tests" / "data" / "skeleton_flow.json"
FLOW = "life"


def add_skeleton(flows, flow_id=FLOW):
    """Registers a copy of the skeleton flow (one manual trigger) under flow_id."""
    return flows.add_file(SKELETON_SRC, flow_id=flow_id)


def flow_file(datadir, flow_id=FLOW):
    return datadir / "Flows" / (flow_id + ".json")


def state_file(datadir, flow_id=FLOW):
    return datadir / "FlowStates" / (flow_id + ".json")


def static_dir(datadir, flow_id=FLOW):
    return datadir / "Variables" / flow_id


# --- storage: delete and createOnly (WI-0070, E0066) -------------------------------------------------------------------

def test_storage_flow_delete_removes_the_flow_file_its_state_and_its_static_variables(flows):
    add_skeleton(flows)
    state_file_path = state_file(flows.datadir)
    state_file_path.parent.mkdir(exist_ok=True)
    state_file_path.write_text('{"formatVersion": 1, "enabled": []}', encoding="utf-8")
    write_var(flows.datadir, "kept", "1", flow_id=None)              # a global variable: not the flow's
    write_var(flows.datadir, "gone", "2", flow_id=FLOW)              # a static variable of the flow
    flows.start()
    answer = flows.request_ok("storage", "cmd.storage.flow.delete", {"flowId": FLOW})
    assert answer["existed"]
    assert not flow_file(flows.datadir).exists()
    assert not state_file(flows.datadir).exists()
    assert not static_dir(flows.datadir).exists()
    assert (flows.datadir / "Variables" / "kept.ahfvd").exists()     # the global variables stay


def test_storage_flow_delete_of_a_missing_flow_is_no_error(flows):
    add_skeleton(flows)
    flows.start()
    answer = flows.request_ok("storage", "cmd.storage.flow.delete", {"flowId": "never there"})
    assert not answer["existed"]


def test_storage_flow_delete_refuses_a_name_with_path_characters(flows):
    add_skeleton(flows)
    flows.start()
    answer = flows.request("storage", "cmd.storage.flow.delete", {"flowId": "..\\life"})
    assert answer["ok"] is False and answer["error"]["code"] == "bad_payload"
    assert flow_file(flows.datadir).exists()


def test_storage_flow_write_create_only_refuses_an_existing_file_and_keeps_it(flows):
    add_skeleton(flows)
    flows.start()
    before = flow_file(flows.datadir).read_text(encoding="utf-8")
    text = json.dumps({"name": "other", "allElements": {}, "allConnections": {}})
    answer = flows.request("storage", "cmd.storage.flow.write", {
        "path": "Flows/" + FLOW + ".json", "text": text, "backup": True, "createOnly": True})
    assert answer["ok"] is False and answer["error"]["code"] == "conflict"
    assert flow_file(flows.datadir).read_text(encoding="utf-8") == before


def test_storage_flow_write_create_only_writes_a_new_file(flows):
    add_skeleton(flows)
    flows.start()
    text = json.dumps({"name": "new", "allElements": {}, "allConnections": {}})
    flows.request_ok("storage", "cmd.storage.flow.write", {
        "path": "Flows/brandnew.json", "text": text, "backup": True, "createOnly": True})
    assert (flows.datadir / "Flows" / "brandnew.json").exists()
