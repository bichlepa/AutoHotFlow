"""WI-0134: the demonstration flows of v1 (Loop tutorial, Pet guesser, Joke teller), end to end: supervisor, real storage and
engine, the files of assets/demo_flows (the program folder). Rules: E0105, REQ-MGR-060, PROTOCOL 2 (demo_read_only), 4.2
(demonstration flows), 4.6 (Demo/ paths), MIGRATION M-0183 to M-0188.

The manager group, the setting HideDemoFlows in the window and the read only hint of the editor are tested in
tests/e2e/test_manager_demo.py and tests/e2e/test_editor_demo.py (headless drivers).
"""

import json
from pathlib import Path

from support.flowrun import flows  # noqa: F401  (fixture flows)

ROOT = Path(__file__).resolve().parents[2]
SKELETON_SRC = ROOT / "tests" / "data" / "skeleton_flow.json"
DEMOS = {
    "Flow 1369089307": "Loop tutorial",
    "Flow 1428714744": "Pet guesser",
    "Flow 806132298": "Joke teller",
}
UPDATE_CHECKER = "Flow 1638325262"       # left out (REQ-SEC-050, E0105)
DEMO = "Flow 806132298"                  # the Joke teller (its trigger is switched on only by the test, never started)
READ_ONLY = "demo_read_only"


def snapshot(flows):
    return {f["flowId"]: f for f in flows.request_ok("engine", "cmd.engine.snapshot", {})["flows"]}


def error_code(answer):
    assert answer["ok"] is False, answer
    return answer["error"]["code"]


def manual_trigger(flows, flow_id):
    triggers = flows.request_ok("engine", "cmd.flow.triggers", {"flowId": flow_id})["triggers"]
    (trigger,) = [t for t in triggers if t["manual"]]
    return trigger["elementId"]


def test_the_three_demonstration_flows_are_loaded_read_only_and_disabled(flows):
    flows.start()
    flows_now = snapshot(flows)
    for flow_id, name in DEMOS.items():
        f = flows_now[flow_id]
        assert f["name"] == name and f["demo"] is True
        assert f["enabled"] is False and f["independentActive"] == 0
    assert UPDATE_CHECKER not in flows_now
    assert not any(f.get("demo") for f in flows_now.values() if f["flowId"] not in DEMOS)


def test_the_demos_are_not_in_the_category_order(flows):
    flows.start()
    listed = [i for c in flows.request_ok("engine", "cmd.engine.snapshot", {})["categories"] for i in c["flows"]]
    assert not set(DEMOS) & set(listed)


def test_every_change_of_a_demo_is_refused_with_demo_read_only(flows):
    flows.start()
    before = flows.request_ok("engine", "cmd.flow.get", {"flowId": DEMO})
    assert before["demo"] is True
    patch = {"flowId": DEMO, "baseRev": before["rev"], "ops": [
        {"op": "flow.settings", "settings": {"zoomFactor": "2.000000"}, "view": True}]}
    assert error_code(flows.request("engine", "cmd.flow.patch", patch)) == READ_ONLY
    assert error_code(flows.request("engine", "cmd.flow.save", {"flowId": DEMO})) == READ_ONLY
    assert error_code(flows.request("engine", "cmd.flow.meta.update", {"flowId": DEMO, "name": "Renamed"})) == READ_ONLY
    assert error_code(flows.request("engine", "cmd.flow.meta.update", {"flowId": DEMO, "category": "X"})) == READ_ONLY
    assert error_code(flows.request("engine", "cmd.flow.delete", {"flowId": DEMO})) == READ_ONLY
    after = flows.request_ok("engine", "cmd.flow.get", {"flowId": DEMO})
    assert after["rev"] == before["rev"] and after["definition"]["name"] == "Joke teller"
    assert snapshot(flows)[DEMO]["demo"] is True


def test_a_demo_is_read_only_in_storage_and_its_file_is_read(flows):
    flows.start()
    text = flows.request_ok("storage", "cmd.storage.flow.read", {"path": "Demo/" + DEMO + ".json"})["text"]
    assert json.loads(text)["name"] == "Joke teller"
    write = flows.request("storage", "cmd.storage.flow.write",
                          {"path": "Demo/" + DEMO + ".json", "text": "{}", "backup": False})
    assert error_code(write) == READ_ONLY
    listed = flows.request_ok("storage", "cmd.storage.flows.list", {})["files"]
    demo_entries = [e for e in listed if e.get("demo")]
    assert sorted(e["path"] for e in demo_entries) == sorted("Demo/" + d + ".json" for d in DEMOS)


def test_a_trigger_of_a_demo_can_be_switched_on_and_off(flows):
    flows.start()
    trigger = manual_trigger(flows, DEMO)
    flows.request_ok("engine", "cmd.trigger.enable", {"flowId": DEMO, "elementId": trigger})
    assert snapshot(flows)[DEMO]["enabled"] is True
    flows.request_ok("engine", "cmd.trigger.disable", {"flowId": DEMO, "elementId": trigger})
    assert snapshot(flows)[DEMO]["enabled"] is False


def test_a_duplicate_is_a_normal_flow_in_the_data_folder_and_can_be_changed(flows):
    flows.start()
    copy = flows.request_ok("engine", "cmd.flow.duplicate", {"flowId": DEMO})["flowId"]
    assert copy not in DEMOS
    f = snapshot(flows)[copy]
    assert f.get("demo") is None and f["name"].startswith("Joke teller")
    assert (flows.datadir / "Flows" / (copy + ".json")).exists()
    patched = flows.request_ok("engine", "cmd.flow.patch", {"flowId": copy, "baseRev": 1, "ops": [
        {"op": "flow.settings", "settings": {"zoomFactor": "2.000000"}, "view": True}]})
    assert patched["rev"] == 2
    flows.request_ok("engine", "cmd.flow.meta.update", {"flowId": copy, "name": "My joke"})


def test_a_user_flow_with_the_id_of_a_demo_is_not_loaded(flows):
    flows.add_file(SKELETON_SRC, flow_id=DEMO)
    flows.start()
    f = snapshot(flows)[DEMO]
    assert f["demo"] is True and f["name"] == "Joke teller"
    assert (flows.datadir / "Flows" / (DEMO + ".json")).exists()   # the file stays on disk


def test_the_group_name_cannot_be_used_for_a_category(flows):
    flows.start()
    assert error_code(flows.request("engine", "cmd.category.create", {"name": "Demonstration"})) == "bad_payload"


def test_the_setting_hide_demo_flows_is_false_by_default_and_can_be_set(flows):
    flows.start()
    settings = flows.request_ok("engine", "cmd.settings.get", {})["settings"]
    assert settings["HideDemoFlows"] in (False, 0)
    flows.request_ok("engine", "cmd.settings.set", {"settings": {"HideDemoFlows": True}})
    assert flows.request_ok("engine", "cmd.settings.get", {})["settings"]["HideDemoFlows"] in (True, 1)
