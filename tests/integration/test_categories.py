"""WI-0071: categories and the order of the flow list, end to end (supervisor, real storage, engine). The commands are
PROTOCOL 4.2 (categories), the file is PROTOCOL 4.6 (Categories.json). The model is unit tested in
tests/ahk/engine_categories.test.ahk.
"""

import json
import time
from pathlib import Path

from support import pipenames
from support.ahfclient import AhfClient
from support.flowrun import flows  # noqa: F401  (fixture flows)
from support.timing import scaled

ROOT = Path(__file__).resolve().parents[2]
SKELETON_SRC = ROOT / "tests" / "data" / "skeleton_flow.json"
FLOW = "life"
WAIT_S = scaled(5.0)


def skeleton():
    return json.loads(SKELETON_SRC.read_text(encoding="utf-8"))


def flow_file(tmp_path, file_name, name, category):
    """A flow file with the given name and category, to be copied into Flows/ before the start."""
    data = skeleton()
    data["name"] = name
    data["category"] = category
    path = tmp_path / (file_name + ".json")
    path.write_text(json.dumps(data), encoding="utf-8")
    return path


def on_disk(datadir, flow_id):
    return json.loads((datadir / "Flows" / (flow_id + ".json")).read_text(encoding="utf-8"))


def categories_on_disk(datadir):
    return json.loads((datadir / "Categories.json").read_text(encoding="utf-8"))


def wait_for(pred, timeout=WAIT_S):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if pred():
            return True
        time.sleep(0.05)
    return pred()


def order_of(flows):
    """The order of the snapshot as a list of (name, [flowId, ...]), the uncategorized group last."""
    snap = flows.request_ok("engine", "cmd.engine.snapshot", {})
    return [(c["name"], list(c["flows"])) for c in snap["categories"]]


def names_of(flows):
    return [name for name, _ in order_of(flows)]


def error_code(answer):
    assert answer["ok"] is False, answer
    return answer["error"]["code"]


def create_flow(flows, name, category):
    return flows.request_ok("engine", "cmd.flow.create", {"name": name, "category": category})["flowId"]


# --- start -------------------------------------------------------------------------------------------------------

def test_a_first_start_without_a_file_orders_alphabetically_and_writes_the_file(flows, tmp_path):
    flows.add_file(flow_file(tmp_path, "z", "Zulu", "Beta"), flow_id="zulu")
    flows.add_file(flow_file(tmp_path, "a", "alpha", "Beta"), flow_id="alpha")
    flows.add_file(flow_file(tmp_path, "m", "Mike", ""), flow_id="mike")
    flows.start()
    assert order_of(flows) == [("Beta", ["alpha", "zulu"]), ("", ["mike"])], "alphabetical, uncategorized last"
    assert wait_for(lambda: (flows.datadir / "Categories.json").is_file()), "the first start writes the file"
    assert categories_on_disk(flows.datadir)["formatVersion"] == 1


def test_a_broken_file_is_kept_and_the_order_is_built_from_the_flows(flows, tmp_path):
    flows.add_file(flow_file(tmp_path, "k", "Kept flow", "Kept"), flow_id="kept")
    (flows.datadir / "Categories.json").write_text("{broken", encoding="utf-8")
    flows.start()
    kept = flows.datadir / "Categories.json.broken"
    assert wait_for(kept.is_file), "the broken file was not kept"
    assert kept.read_text(encoding="utf-8") == "{broken"
    assert names_of(flows) == ["Kept", ""]
    assert wait_for(lambda: (flows.datadir / "Categories.json").is_file())
    assert categories_on_disk(flows.datadir)["categories"][0]["name"] == "Kept"


def test_a_flow_copied_in_by_hand_is_appended_to_its_category(flows, tmp_path):
    flows.add_file(flow_file(tmp_path, "one", "one", "A"), flow_id="one")
    flows.start()
    flows.request_ok("engine", "cmd.category.create", {"name": "B"})
    assert wait_for(lambda: (flows.datadir / "Categories.json").is_file())
    flows.stop()
    flows.add_file(flow_file(tmp_path, "two", "two", "A"), flow_id="two")
    flows.start()
    assert ("A", ["one", "two"]) in order_of(flows), order_of(flows)


def test_the_order_and_an_empty_category_survive_a_restart(flows):
    flows.add_file(SKELETON_SRC, flow_id=FLOW)
    flows.start()
    flows.request_ok("engine", "cmd.category.create", {"name": "Second"})
    flows.request_ok("engine", "cmd.category.create", {"name": "First"})
    flows.request_ok("engine", "cmd.category.create", {"name": "Empty"})
    flows.request_ok("engine", "cmd.flow.meta.update", {"flowId": FLOW, "category": "Second"})
    # the skeleton flow has the category "Skeleton" in its file: that category stays as an empty one (REQ-MGR-030)
    flows.request_ok("engine", "cmd.category.order", {"categories": ["First", "Second", "Skeleton", "Empty"]})
    expected = [("First", []), ("Second", [FLOW]), ("Skeleton", []), ("Empty", []), ("", [])]
    assert order_of(flows) == expected
    assert wait_for(lambda: "Empty" in (flows.datadir / "Categories.json").read_text(encoding="utf-8"))
    flows.stop()
    flows.start()
    assert order_of(flows) == expected, "the order and the empty categories are kept"


# --- create, rename, delete -----------------------------------------------------------------------------------

def test_a_new_flow_comes_last_in_its_category(flows):
    flows.start()
    flows.request_ok("engine", "cmd.category.create", {"name": "A"})
    first = create_flow(flows, "one", "A")
    second = create_flow(flows, "two", "A")
    assert order_of(flows)[0] == ("A", [first, second])


def test_rename_writes_every_flow_file_and_keeps_the_place(flows):
    flows.start()
    flows.request_ok("engine", "cmd.category.create", {"name": "A"})
    flows.request_ok("engine", "cmd.category.create", {"name": "B"})
    flow_id = create_flow(flows, "one", "A")
    flows.request_ok("engine", "cmd.category.rename", {"name": "A", "newName": "Renamed"})
    assert on_disk(flows.datadir, flow_id)["category"] == "Renamed"
    assert order_of(flows) == [("Renamed", [flow_id]), ("B", []), ("", [])]


def test_rename_to_a_name_of_another_case_is_a_rename(flows):
    flows.start()
    flows.request_ok("engine", "cmd.category.create", {"name": "beta"})
    flows.request_ok("engine", "cmd.category.rename", {"name": "beta", "newName": "Beta"})
    assert names_of(flows) == ["Beta", ""]


def test_delete_moves_the_flows_first_and_then_removes_the_category(flows):
    flows.start()
    flows.request_ok("engine", "cmd.category.create", {"name": "X"})
    flows.request_ok("engine", "cmd.category.create", {"name": "Y"})
    flow_id = create_flow(flows, "one", "X")
    flows.request_ok("engine", "cmd.category.delete", {"name": "X", "moveTo": "Y"})
    assert on_disk(flows.datadir, flow_id)["category"] == "Y"
    assert order_of(flows) == [("Y", [flow_id]), ("", [])]


def test_delete_without_a_target_is_refused_when_flows_are_in_it(flows):
    flows.start()
    flows.request_ok("engine", "cmd.category.create", {"name": "X"})
    flow_id = create_flow(flows, "one", "X")
    answer = flows.request("engine", "cmd.category.delete", {"name": "X"})
    assert error_code(answer) == "bad_payload"
    assert order_of(flows)[0] == ("X", [flow_id]) and on_disk(flows.datadir, flow_id)["category"] == "X"


def test_the_uncategorized_group_cannot_be_renamed_or_deleted(flows):
    flows.start()
    assert error_code(flows.request("engine", "cmd.category.rename", {"name": "", "newName": "X"})) == "bad_payload"
    assert error_code(flows.request("engine", "cmd.category.delete", {"name": "", "moveTo": "X"})) == "bad_payload"
    assert names_of(flows) == [""]


def test_category_names_are_checked(flows):
    flows.start()
    flows.request_ok("engine", "cmd.category.create", {"name": "Beta"})
    for name in ["", "a|b", "beta", "BETA"]:
        assert error_code(flows.request("engine", "cmd.category.create", {"name": name})) == "bad_payload", name
    assert error_code(flows.request("engine", "cmd.category.create", {"name": "Uncategorized"})) == "bad_payload"
    assert names_of(flows) == ["Beta", ""]


def test_an_unknown_category_is_refused_for_create_and_for_a_meta_update(flows):
    flows.add_file(SKELETON_SRC, flow_id=FLOW)
    flows.start()
    assert error_code(flows.request("engine", "cmd.flow.create", {"name": "x", "category": "Nope"})) == "bad_payload"
    assert error_code(flows.request("engine", "cmd.flow.meta.update", {"flowId": FLOW, "category": "Nope"})) == "bad_payload"
    assert on_disk(flows.datadir, FLOW)["category"] == "Skeleton", "the file keeps its category"


# --- the order -------------------------------------------------------------------------------------------------

def test_a_refused_order_changes_nothing(flows):
    flows.start()
    flows.request_ok("engine", "cmd.category.create", {"name": "A"})
    flows.request_ok("engine", "cmd.category.create", {"name": "B"})
    before = order_of(flows)
    assert error_code(flows.request("engine", "cmd.category.order", {"categories": ["A"]})) == "bad_payload"
    assert error_code(flows.request("engine", "cmd.category.order", {"categories": ["A", "B", "C"]})) == "bad_payload"
    assert error_code(flows.request("engine", "cmd.category.order", {"flows": {"A": ["nope"]}})) == "bad_payload"
    assert order_of(flows) == before
    flows.request_ok("engine", "cmd.category.order", {"categories": ["B", "A"]})
    assert names_of(flows) == ["B", "A", ""]


def test_sort_alphabetically_once(flows):
    flows.start()
    for name in ["zeta", "Alpha", "beta"]:
        flows.request_ok("engine", "cmd.category.create", {"name": name})
    flows.request_ok("engine", "cmd.category.sort", {})
    assert names_of(flows) == ["Alpha", "beta", "zeta", ""]


def test_the_order_is_sent_as_an_event_when_it_changes(flows):
    flows.start()
    flows.request_ok("supervisor", "cmd.topic.subscribe", {"topic": "engine"})
    flows.request_ok("engine", "cmd.category.create", {"name": "Evented"})
    found = flows.wait_message(lambda m: m.get("type") == "evt.category.changed"
                               and any(c["name"] == "Evented" for c in m["payload"]["categories"]))
    assert found is not None, "evt.category.changed with the new category"


# --- concurrency: a category command while another one waits for the flow files (WI-0071 review) ----------------

def _run_in_thread(flows, to, type_, payload):
    """Sends one request from a thread on its own client connection (a client is not shared between threads).
    Returns (thread, box); box holds "value" (the payload of the answer) or "error". The thread closes its client."""
    import threading
    box = {}
    pipe = pipenames.hub_pipe(flows.sessions[-1])

    def run():
        client = AhfClient(pipe, "race", connect_timeout=2.0)
        try:
            box["value"] = client.request(to, type_, payload, timeout=scaled(20.0))["payload"]
        except Exception as e:  # reported by the test, not swallowed
            box["error"] = e
        finally:
            client.close()

    thread = threading.Thread(target=run, daemon=True)
    thread.start()
    return thread, box


def _join(thread):
    """Waits for the thread, bounded; a thread that does not end fails the test (it may still use the session)."""
    thread.join(scaled(20.0))
    assert not thread.is_alive(), "the request thread did not end within 20 s"


def test_a_rename_meanwhile_another_flow_changes_leaves_one_category(flows):
    flows.start()
    for round_no in range(3):
        old, new = "Old %d" % round_no, "New %d" % round_no
        other = create_flow(flows, "other %d" % round_no, "")
        flows.request_ok("engine", "cmd.category.create", {"name": old})
        members = [create_flow(flows, "m%d-%d" % (round_no, i), old) for i in range(20)]
        if round_no % 2:
            other_call = ("engine", "cmd.flow.delete", {"flowId": other})
        else:
            other_call = ("engine", "cmd.flow.meta.update", {"flowId": other, "name": "renamed %d" % round_no})
        thread, box = _run_in_thread(flows, "engine", "cmd.category.rename", {"name": old, "newName": new})
        flows.request(*other_call)
        _join(thread)
        assert "error" not in box, box.get("error")
        assert box["value"]["ok"] is True, box["value"]
        names = names_of(flows)
        assert old not in names, "no stale old category: %s" % names
        assert names.count(new) == 1, names
        assert all(on_disk(flows.datadir, f)["category"] == new for f in members)


def test_a_second_category_command_while_a_rename_waits_is_busy_or_after_it(flows):
    flows.start()
    flows.request_ok("engine", "cmd.category.create", {"name": "Busy"})
    for i in range(20):
        create_flow(flows, "b%d" % i, "Busy")
    thread, box = _run_in_thread(flows, "engine", "cmd.category.rename", {"name": "Busy", "newName": "Done"})
    answers = []
    created = []
    deadline = time.monotonic() + scaled(20.0)
    while thread.is_alive() and len(answers) < 200 and time.monotonic() < deadline:
        name = "Tmp %d" % len(answers)
        answers.append(flows.request("engine", "cmd.category.create", {"name": name}))
        if answers[-1]["ok"]:
            created.append(name)
    _join(thread)
    assert "error" not in box, box.get("error")
    assert box["value"]["ok"] is True, box["value"]
    for answer in answers:
        assert answer["ok"] or answer["error"]["code"] == "busy", answer
    for name in created:       # the rename is over: the test categories go, the list is as before
        flows.request_ok("engine", "cmd.category.delete", {"name": name})
    assert names_of(flows) == ["Done", ""]


def test_an_order_of_the_flows_of_one_category_is_kept_across_a_restart(flows):
    flows.start()
    flows.request_ok("engine", "cmd.category.create", {"name": "A"})
    f1 = create_flow(flows, "one", "A")
    f2 = create_flow(flows, "two", "A")
    f3 = create_flow(flows, "three", "A")
    flows.request_ok("engine", "cmd.category.order", {"flows": {"A": [f3, f1, f2]}})
    assert order_of(flows)[0] == ("A", [f3, f1, f2])
    assert wait_for(lambda: categories_on_disk(flows.datadir)["categories"][0]["flows"] == [f3, f1, f2])
    flows.stop()
    flows.start()
    assert order_of(flows)[0] == ("A", [f3, f1, f2]), "the order of the flows is kept"
