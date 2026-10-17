"""WI-0070: the engine commands cmd.flow.create, cmd.flow.duplicate, cmd.flow.meta.update and cmd.flow.delete, end to end
(supervisor, real storage, engine). The storage part is in test_flow_lifecycle.py. Rules: doc/PROTOCOL.md 4.2 (flow
lifecycle).
"""

import copy
import json
import os
import stat
from pathlib import Path

from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture flows)
from support.timing import scaled

ROOT = Path(__file__).resolve().parents[2]
SKELETON_SRC = ROOT / "tests" / "data" / "skeleton_flow.json"
FLOW = "life"
TRIGGER = "element0000000001"
WAIT_S = scaled(5.0)


def skeleton():
    return json.loads(SKELETON_SRC.read_text(encoding="utf-8"))


def add_skeleton(flows, flow_id=FLOW):
    return flows.add_file(SKELETON_SRC, flow_id=flow_id)


def on_disk(datadir, flow_id):
    return json.loads((datadir / "Flows" / (flow_id + ".json")).read_text(encoding="utf-8"))


def listen_to_engine(flows):
    """The observer gets the events of the topic engine (evt.flow.list.changed); the runner subscribes to flow topics only."""
    flows.request_ok("supervisor", "cmd.topic.subscribe", {"topic": "engine"})


def snapshot_flow(flows, flow_id):
    for f in flows.request_ok("engine", "cmd.engine.snapshot", {})["flows"]:
        if f["flowId"] == flow_id:
            return f
    return None


def name_of(flows, flow_id):
    return flows.request_ok("engine", "cmd.flow.get", {"flowId": flow_id})["definition"]["name"]


def error_code(answer):
    assert answer["ok"] is False, answer
    return answer["error"]["code"]


# --- create --------------------------------------------------------------------------------------------------------

def test_create_without_a_definition_makes_the_empty_v1_flow_with_one_manual_trigger(flows):
    add_skeleton(flows)
    flows.start()
    flow_id = flows.request_ok("engine", "cmd.flow.create", {})["flowId"]
    assert flow_id.startswith("Flow ")
    text = on_disk(flows.datadir, flow_id)
    assert text["name"] == "New flow 1" and text["formatVersion"] == 2
    assert text["flowSettings"]["strictTypes"] is True
    elements = text["allElements"]
    assert len(elements) == 1
    (trigger,) = elements.values()
    assert trigger["type"] == "trigger" and trigger["class"] == "Trigger_Manual" and trigger["DefaultTrigger"] is True
    f = snapshot_flow(flows, flow_id)
    assert f["name"] == "New flow 1" and f["enabled"] is False and len(f["triggers"]) == 1


def test_create_picks_the_lowest_free_new_flow_number_and_reports_the_list_change(flows):
    add_skeleton(flows)
    flows.start()
    listen_to_engine(flows)
    first = flows.request_ok("engine", "cmd.flow.create", {"name": "Mine"})["flowId"]
    second = flows.request_ok("engine", "cmd.flow.create", {})["flowId"]
    assert name_of(flows, first) == "Mine"
    assert name_of(flows, second) == "New flow 1"
    third = flows.request_ok("engine", "cmd.flow.create", {})["flowId"]
    assert name_of(flows, third) == "New flow 2"
    changed = flows.wait_message(lambda m: m.get("type") == "evt.flow.list.changed"
                                 and third in m["payload"].get("added", []), timeout=WAIT_S)
    assert changed is not None


def test_create_refuses_a_name_that_another_flow_has_ignoring_case_and_a_bar(flows):
    add_skeleton(flows)
    flows.start()
    name = name_of(flows, FLOW)
    answer = flows.request("engine", "cmd.flow.create", {"name": name.upper()})
    assert error_code(answer) == "bad_payload" and "already exists" in answer["error"]["message"]
    answer = flows.request("engine", "cmd.flow.create", {"name": "a|b"})
    assert error_code(answer) == "bad_payload" and "prohibited" in answer["error"]["message"]


def test_create_with_a_v1_definition_loads_disabled_with_its_marker_and_without_the_enabled_key(flows):
    add_skeleton(flows)
    flows.start()
    definition = skeleton()
    definition.pop("formatVersion", None)
    definition["allElements"][TRIGGER]["enabled"] = "1"
    definition["allElements"]["element0000000099"] = {
        "ID": "element0000000099", "type": "action", "class": "Action_NotYetPorted", "x": "0", "y": "0",
        "pars": {"Expr": "1.50"}, "name": "Later", "StandardName": "1"}
    flow_id = flows.request_ok("engine", "cmd.flow.create", {"name": "Imported", "definition": definition})["flowId"]
    f = snapshot_flow(flows, flow_id)
    assert f["enabled"] is False and f["name"] == "Imported"
    text = on_disk(flows.datadir, flow_id)
    assert text["formatVersion"] == 2
    assert "enabled" not in text["allElements"][TRIGGER]
    assert text["allElements"]["element0000000099"]["v1Text"] is True


def test_create_with_a_definition_that_is_not_an_object_is_bad_payload(flows):
    add_skeleton(flows)
    flows.start()
    answer = flows.request("engine", "cmd.flow.create", {"definition": "text"})
    assert error_code(answer) == "bad_payload"


# --- duplicate -----------------------------------------------------------------------------------------------------

def test_duplicate_gets_a_new_id_the_next_free_copy_name_and_disabled_triggers(flows):
    add_skeleton(flows)
    flows.start()
    flows.enable(FLOW)
    assert snapshot_flow(flows, FLOW)["enabled"] is True
    name = name_of(flows, FLOW)
    copy1 = flows.request_ok("engine", "cmd.flow.duplicate", {"flowId": FLOW})["flowId"]
    assert copy1 != FLOW and name_of(flows, copy1) == name + " 2"
    assert snapshot_flow(flows, copy1)["enabled"] is False
    assert not (flows.datadir / "FlowStates" / (copy1 + ".json")).exists()
    copy2 = flows.request_ok("engine", "cmd.flow.duplicate", {"flowId": FLOW})["flowId"]
    assert name_of(flows, copy2) == name + " 3"
    assert on_disk(flows.datadir, copy1)["name"] == name + " 2"


def test_duplicate_of_an_unknown_flow_is_not_found(flows):
    add_skeleton(flows)
    flows.start()
    assert error_code(flows.request("engine", "cmd.flow.duplicate", {"flowId": "nothing"})) == "not_found"


# --- meta update: name and category --------------------------------------------------------------------------------

def test_rename_is_written_at_once_and_commits_a_new_revision(flows):
    add_skeleton(flows)
    flows.start()
    rev = flows.request_ok("engine", "cmd.flow.get", {"flowId": FLOW})["rev"]
    answer = flows.request_ok("engine", "cmd.flow.meta.update", {"flowId": FLOW, "name": "Renamed"})
    assert answer["rev"] == rev + 1
    assert on_disk(flows.datadir, FLOW)["name"] == "Renamed"       # the file is there when the answer comes
    assert snapshot_flow(flows, FLOW)["name"] == "Renamed"
    committed = flows.wait_message(lambda m: m.get("type") == "evt.flow.committed"
                                   and m["payload"].get("rev") == rev + 1, timeout=WAIT_S)
    assert committed is not None and committed[1]["payload"]["byMeta"] is True


def test_rename_to_a_taken_name_or_an_empty_name_is_refused_and_nothing_changes(flows):
    add_skeleton(flows)
    flows.start()
    flows.request_ok("engine", "cmd.flow.create", {"name": "Second"})
    before = name_of(flows, FLOW)
    assert error_code(flows.request("engine", "cmd.flow.meta.update", {"flowId": FLOW, "name": "second"})) == "bad_payload"
    assert error_code(flows.request("engine", "cmd.flow.meta.update", {"flowId": FLOW, "name": ""})) == "bad_payload"
    assert error_code(flows.request("engine", "cmd.flow.meta.update", {"flowId": FLOW, "name": "x|y"})) == "bad_payload"
    assert name_of(flows, FLOW) == before
    assert on_disk(flows.datadir, FLOW)["name"] == before


def test_rename_that_only_changes_the_case_of_the_own_name_is_allowed(flows):
    add_skeleton(flows)
    flows.start()
    upper = name_of(flows, FLOW).upper()
    flows.request_ok("engine", "cmd.flow.meta.update", {"flowId": FLOW, "name": upper})
    assert name_of(flows, FLOW) == upper


def test_category_is_written_and_the_name_stays(flows):
    add_skeleton(flows)
    flows.start()
    flows.request_ok("engine", "cmd.category.create", {"name": "Tests"})
    before = name_of(flows, FLOW)
    flows.request_ok("engine", "cmd.flow.meta.update", {"flowId": FLOW, "category": "Tests"})
    text = on_disk(flows.datadir, FLOW)
    assert text["category"] == "Tests" and text["name"] == before
    assert snapshot_flow(flows, FLOW)["category"] == "Tests"


def test_a_rename_survives_a_restart_of_the_session(flows):
    add_skeleton(flows)
    flows.start()
    flows.request_ok("engine", "cmd.flow.meta.update", {"flowId": FLOW, "name": "Kept"})
    flows.stop()
    flows.start()
    assert name_of(flows, FLOW) == "Kept"


def test_a_created_flow_survives_a_restart_of_the_session(flows):
    add_skeleton(flows)
    flows.start()
    flow_id = flows.request_ok("engine", "cmd.flow.create", {"name": "Lasting"})["flowId"]
    flows.stop()
    flows.start()
    assert name_of(flows, flow_id) == "Lasting"
    assert snapshot_flow(flows, flow_id)["enabled"] is False


def test_rename_whose_file_cannot_be_written_changes_nothing(flows):
    add_skeleton(flows)
    flows.start()
    path = flows.datadir / "Flows" / (FLOW + ".json")
    before = name_of(flows, FLOW)
    os.chmod(path, stat.S_IREAD)                     # a read-only file cannot be replaced
    try:
        answer = flows.request("engine", "cmd.flow.meta.update", {"flowId": FLOW, "name": "Failed"})
        assert answer["ok"] is False
        assert name_of(flows, FLOW) == before
        assert "Failed" not in path.read_text(encoding="utf-8")
    finally:
        os.chmod(path, stat.S_IREAD | stat.S_IWRITE)


def test_meta_update_of_an_unknown_flow_is_not_found(flows):
    add_skeleton(flows)
    flows.start()
    assert error_code(flows.request("engine", "cmd.flow.meta.update", {"flowId": "nothing", "name": "x"})) == "not_found"


# --- delete --------------------------------------------------------------------------------------------------------

def test_delete_removes_the_flow_its_state_and_its_static_variables(flows):
    add_skeleton(flows)
    (flows.datadir / "FlowStates").mkdir(exist_ok=True)
    (flows.datadir / "FlowStates" / (FLOW + ".json")).write_text('{"formatVersion": 1, "enabled": []}', encoding="utf-8")
    flows.start()
    listen_to_engine(flows)
    flows.request_ok("engine", "cmd.flow.delete", {"flowId": FLOW})
    assert snapshot_flow(flows, FLOW) is None
    assert not (flows.datadir / "Flows" / (FLOW + ".json")).exists()
    assert not (flows.datadir / "FlowStates" / (FLOW + ".json")).exists()
    removed = flows.wait_message(lambda m: m.get("type") == "evt.flow.list.changed"
                                 and FLOW in m["payload"].get("removed", []), timeout=WAIT_S)
    assert removed is not None
    assert error_code(flows.request("engine", "cmd.flow.delete", {"flowId": FLOW})) == "not_found"


def test_delete_keeps_the_backups_of_the_flow(flows):
    add_skeleton(flows)
    flows.start()
    flows.request_ok("engine", "cmd.flow.meta.update", {"flowId": FLOW, "name": "Backed up"})   # a backup is made
    flows.request_ok("engine", "cmd.flow.delete", {"flowId": FLOW})
    backups = list((flows.datadir / "Flows" / "backup").glob(FLOW + "_backup_*.json"))
    assert backups


def test_delete_stops_a_running_instance_at_once_with_reason_flow_deleted(flows):
    fb = FlowBuilder("sleeping")
    fb.chain(fb.trigger(), fb.action("Action_Sleep", Duration=60, Unit="Seconds"))
    flow_id = flows.add(fb)
    flows.start()
    flows.request_ok("engine", "cmd.flow.start", {"flowId": flow_id})
    assert flows.executing(flow_id)
    flows.request_ok("engine", "cmd.flow.delete", {"flowId": flow_id})
    ended = flows.ended(flow_id, count=1, timeout=5)
    assert ended and ended[0]["reason"] == "flow.deleted"
    assert snapshot_flow(flows, flow_id) is None


def test_delete_of_a_flow_whose_state_cannot_be_read_deletes_it_too(flows):
    add_skeleton(flows)
    state = flows.datadir / "FlowStates" / (FLOW + ".json")
    state.mkdir(parents=True)                        # a folder where the state file belongs: the state is unreadable
    flows.start()
    refused = flows.request("engine", "cmd.flow.enable", {"flowId": FLOW})
    assert refused["ok"] is False and "cannot be read" in refused["message"]
    flows.request_ok("engine", "cmd.flow.delete", {"flowId": FLOW})
    assert snapshot_flow(flows, FLOW) is None
    assert not state.exists() and not (flows.datadir / "Flows" / (FLOW + ".json")).exists()


def test_delete_that_storage_cannot_do_keeps_the_flow(flows):
    add_skeleton(flows)
    flows.start()
    path = flows.datadir / "Flows" / (FLOW + ".json")
    os.chmod(path, stat.S_IREAD)                     # a read-only file cannot be deleted
    try:
        answer = flows.request("engine", "cmd.flow.delete", {"flowId": FLOW})
        assert answer["ok"] is False
        assert snapshot_flow(flows, FLOW) is not None and path.exists()
    finally:
        os.chmod(path, stat.S_IREAD | stat.S_IWRITE)
    flows.request_ok("engine", "cmd.flow.delete", {"flowId": FLOW})
    assert snapshot_flow(flows, FLOW) is None


def test_a_deleted_flow_stays_deleted_after_a_restart(flows):
    add_skeleton(flows)
    flows.start()
    flows.request_ok("engine", "cmd.flow.delete", {"flowId": FLOW})
    flows.stop()
    del flows.flows[FLOW]        # the runner loads the flows it has been given: this one is gone
    flows.start()
    assert snapshot_flow(flows, FLOW) is None


def send_delete_then(flows, follow_type, follow_payload):
    """Sends cmd.flow.delete without waiting, then the follow-up command at once, so that the follow-up arrives while
    storage works on the delete. Returns the answer of the follow-up."""
    flows._obs.send("engine", "cmd.flow.delete", {"flowId": FLOW})
    return flows.request("engine", follow_type, follow_payload)


def test_a_save_right_after_a_delete_is_busy_and_does_not_re_create_the_file(flows):
    add_skeleton(flows)
    flows.start()
    listen_to_engine(flows)
    answer = send_delete_then(flows, "cmd.flow.save", {"flowId": FLOW})
    assert error_code(answer) == "busy", answer
    assert flows.wait_message(lambda m: m.get("type") == "evt.flow.list.changed"
                              and FLOW in m["payload"].get("removed", []), timeout=WAIT_S) is not None
    assert snapshot_flow(flows, FLOW) is None
    assert not (flows.datadir / "Flows" / (FLOW + ".json")).exists()
    flows.stop()
    del flows.flows[FLOW]        # the runner loads the flows it was given: this one is gone
    flows.start()
    assert snapshot_flow(flows, FLOW) is None
    assert not (flows.datadir / "Flows" / (FLOW + ".json")).exists()


def test_a_trigger_switch_right_after_a_delete_is_busy(flows):
    add_skeleton(flows)
    flows.start()
    listen_to_engine(flows)
    answer = send_delete_then(flows, "cmd.trigger.enable", {"flowId": FLOW, "elementId": TRIGGER})
    assert error_code(answer) == "busy", answer
    assert flows.wait_message(lambda m: m.get("type") == "evt.flow.list.changed"
                              and FLOW in m["payload"].get("removed", []), timeout=WAIT_S) is not None
    assert not (flows.datadir / "Flows" / (FLOW + ".json")).exists()
