"""WI-0081: export and import of flows as .ahf files through the manager (REQ-MGR-050, REQ-SEC-060), headless.

An .ahf file is a ZIP archive (as v1 writes it): the flow files at its root and the static variables in Variables/<flowId>/.
The import runs through cmd.test.op "importFile" (the same chain as the file dialog and the drop; the dialogs are not part of
it), the export through "exportFlows". The questions are answered by the test ("answers") and read back ("asked").

Checked: a round trip (the exported file, the definition and the static variable come back, the flow is a new copy, disabled);
a v1 archive (flat, a v1 flow) loads; a broken file and a file with another extension are reported; an archive with an entry
outside the layout (a path with "..", an absolute name, a backslash, a drive) is refused as a whole and nothing is written
outside the data folder; a name conflict with each answer (next number, typed name, skip, cancel); the warning lists the
elements that act on the system (and says so when there are none) and "no" creates nothing; an export without a selection is
refused.
"""

import json
import zipfile
from pathlib import Path

import pytest

from test_manager import FLOW, flow_data, wait_until
from test_manager_import import started, v2_flows, ONE_EXAMPLE, EXAMPLES
from support.timing import scaled

ROOT = Path(__file__).resolve().parents[2]
TRIGGERS_FLOW = ROOT / "tests" / "data" / "manual" / "triggers_check.json"
SKELETON_NAME = "Skeleton"


def call(obs, op_name, **args):
    """A cmd.test.op of the headless manager; returns its payload (the operation's answer), no assertion on ok."""
    ans = obs.request("manager", "cmd.test.op", dict(op=op_name, **args), timeout=scaled(10))
    return ans["payload"]


def import_file(obs, path, answers=None):
    """The import of one .ahf file through the manager's chain. Returns the report (a Map: ok, error, flows, vars)."""
    call(obs, "answers", answers=answers or {})
    ans = obs.request("manager", "cmd.test.op", dict(op="importFile", path=str(path)), timeout=scaled(240))
    assert ans["payload"] is not None, ans
    return ans["payload"]


def questions(obs):
    return call(obs, "asked")["asked"]


def make_ahf(path, members):
    """A ZIP archive with the members (name -> text), written as Python's zipfile writes it (names as given)."""
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for name, text in members.items():
            z.writestr(name, text)
    return path


def archive_files(path):
    with zipfile.ZipFile(path) as z:
        return sorted(n for n in z.namelist() if not n.endswith("/"))


def flows_named(report):
    return {f["name"]: f for f in report["flows"]}


def set_static(datadir, flow_id):
    """A static variable of one flow: its two files in the data folder layout."""
    static = datadir / "Variables" / flow_id
    static.mkdir(parents=True)
    (static / "sv.ahfvd").write_text(json.dumps({"name": "sv", "type": "object"}), encoding="utf-8")
    (static / "sv.ahfvar").write_text('{"a": 1}', encoding="utf-8")


# --- export and round trip -------------------------------------------------------------------------------------------

def test_export_then_import_gives_a_new_disabled_flow_with_its_definition_and_static_variables(started, tmp_path):
    sup, obs = started(lambda d: (flow_data(d), set_static(d, FLOW)))
    target = tmp_path / "out.ahf"
    res = call(obs, "exportFlows", flowIds=[FLOW], path=str(target))
    assert res["ok"] and res["count"] == 1, res
    assert archive_files(target) == ["Variables/skeleton/sv.ahfvar", "Variables/skeleton/sv.ahfvd", "skeleton.json"]
    with zipfile.ZipFile(target) as z:
        assert z.read("skeleton.json") == (sup.datadir / "Flows" / (FLOW + ".json")).read_bytes()

    report = import_file(obs, target, answers={"importWarning": "yes", "importConflict": 1})
    assert report["ok"], report
    copy = flows_named(report)[SKELETON_NAME]
    assert copy["state"] == "copy" and copy["as"] == SKELETON_NAME + " 2", copy
    new_id = copy["flowId"]
    assert new_id != FLOW
    assert wait_until(lambda: new_id in v2_flows(obs), scaled(10)), sorted(v2_flows(obs))
    assert not v2_flows(obs)[new_id]["enabled"], v2_flows(obs)[new_id]          # every imported flow is disabled

    old = json.loads((sup.datadir / "Flows" / (FLOW + ".json")).read_text(encoding="utf-8"))
    new = json.loads((sup.datadir / "Flows" / (new_id + ".json")).read_text(encoding="utf-8"))
    assert new["name"] == SKELETON_NAME + " 2"
    assert {k: (v["package"], v["class"]) for k, v in new["allElements"].items()} == \
        {k: (v["package"], v["class"]) for k, v in old["allElements"].items()}

    taken = [v for v in report["vars"] if v["state"] == "taken"]
    assert [(v["scope"], v["name"]) for v in taken] == [("static", "sv")], report["vars"]
    static_file = sup.datadir / "Variables" / new_id / "sv.ahfvar"
    assert wait_until(static_file.is_file, scaled(10)), "the static variable was not written"
    assert json.loads(static_file.read_text(encoding="utf-8")) == {"a": 1}


def test_a_v1_archive_loads_as_flat_zip_of_v1_flow_files(started, tmp_path):
    sup, obs = started()
    v1_text = (EXAMPLES / (ONE_EXAMPLE + ".json")).read_text(encoding="utf-8")
    archive = make_ahf(tmp_path / "v1.ahf", {ONE_EXAMPLE + ".json": v1_text})
    report = import_file(obs, archive, answers={"importWarning": "yes"})
    assert report["ok"], report
    assert len(report["flows"]) == 1, report["flows"]
    created = [f for f in report["flows"] if f["state"] in ("created", "copy")]
    assert created, report["flows"]
    new_id = created[0]["flowId"]
    assert wait_until(lambda: new_id in v2_flows(obs), scaled(20)), sorted(v2_flows(obs))
    assert not v2_flows(obs)[new_id]["enabled"]
    assert not any((sup.datadir / "Archive").glob("*")), "a job folder of the import was left behind"


# --- broken files and refused entries --------------------------------------------------------------------------------

def test_a_broken_file_is_reported_and_nothing_is_created(started, tmp_path):
    sup, obs = started()
    before = sorted(v2_flows(obs))
    broken = tmp_path / "broken.ahf"
    broken.write_text("this is not a ZIP archive", encoding="utf-8")
    report = import_file(obs, broken)
    assert not report["ok"], report
    assert "ZIP" in report["error"], report["error"]
    assert report["flows"] == []
    assert sorted(v2_flows(obs)) == before


def test_a_file_without_the_extension_is_refused(started, tmp_path):
    sup, obs = started()
    other = make_ahf(tmp_path / "flows.zip", {"x.json": "{}"})
    report = import_file(obs, other)
    assert not report["ok"] and "extension" in report["error"], report


ENTRIES = ["../evil.json", "..\\evil.json", "/abs.json", "Variables/../../evil.json", "sub/flow.json", "C:evil.json",
           "Variables/x.txt"]


def test_an_archive_with_an_entry_outside_the_layout_is_refused_as_a_whole(started, tmp_path):
    # one data folder for all entries: a refused file changes nothing, so the cases can follow each other
    sup, obs = started()
    before = sorted(v2_flows(obs))
    good = (EXAMPLES / (ONE_EXAMPLE + ".json")).read_text(encoding="utf-8")
    for n, entry in enumerate(ENTRIES):
        archive = make_ahf(tmp_path / ("bad%d.ahf" % n), {"good.json": good, entry: '{"name": "evil"}'})
        report = import_file(obs, archive, answers={"importWarning": "yes"})
        assert not report["ok"], (entry, report)
        assert "not allowed" in report["error"], (entry, report["error"])
        assert sorted(v2_flows(obs)) == before, "a flow of a refused archive was created: %r" % entry
    assert not (tmp_path / "evil.json").exists()
    assert not any(p.name == "evil.json" for p in sup.datadir.rglob("*"))


# --- name conflicts --------------------------------------------------------------------------------------------------

def _export_skeleton(obs, tmp_path):
    target = tmp_path / "skeleton.ahf"
    assert call(obs, "exportFlows", flowIds=[FLOW], path=str(target))["ok"]
    return target


def test_a_name_conflict_with_skip_creates_nothing(started, tmp_path):
    sup, obs = started(lambda d: flow_data(d))
    target = _export_skeleton(obs, tmp_path)
    before = sorted(v2_flows(obs))
    report = import_file(obs, target, answers={"importWarning": "yes", "importConflict": 3})
    assert flows_named(report)[SKELETON_NAME]["state"] == "skipped", report["flows"]
    assert sorted(v2_flows(obs)) == before


def test_a_name_conflict_with_a_typed_name_creates_the_flow_under_that_name(started, tmp_path):
    sup, obs = started(lambda d: flow_data(d))
    target = _export_skeleton(obs, tmp_path)
    report = import_file(obs, target, answers={"importWarning": "yes", "importConflict": 2, "importName": "My copy"})
    copy = flows_named(report)["Skeleton"]
    assert copy["state"] == "copy" and copy["as"] == "My copy", copy
    assert wait_until(lambda: copy["flowId"] in v2_flows(obs), scaled(10))
    assert v2_flows(obs)[copy["flowId"]]["name"] == "My copy"


def test_a_name_conflict_with_cancel_stops_the_import(started, tmp_path):
    sup, obs = started(lambda d: flow_data(d))
    target = _export_skeleton(obs, tmp_path)
    before = sorted(v2_flows(obs))
    report = import_file(obs, target, answers={"importWarning": "yes", "importConflict": 4})
    assert "cancelled" in report["error"], report
    assert sorted(v2_flows(obs)) == before


def test_a_name_conflict_with_the_next_number_gives_a_copy(started, tmp_path):
    sup, obs = started(lambda d: flow_data(d))
    target = _export_skeleton(obs, tmp_path)
    report = import_file(obs, target, answers={"importWarning": "yes", "importConflict": 1})
    assert flows_named(report)["Skeleton"]["as"] == "Skeleton 2"
    assert [q["kind"] for q in questions(obs)].count("importConflict") == 1


# --- the warning -----------------------------------------------------------------------------------------------------

def test_the_warning_lists_the_elements_that_act_on_the_system_and_no_creates_nothing(started, tmp_path):
    sup, obs = started()
    flow = json.loads(TRIGGERS_FLOW.read_text(encoding="utf-8"))
    flow["allElements"]["element0000000099"] = {"type": "action", "package": "Default",
                                                "class": "Action_Unknown_Thing", "pars": {}}
    archive = make_ahf(tmp_path / "triggers.ahf", {"triggers_check.json": json.dumps(flow)})
    before = sorted(v2_flows(obs))
    report = import_file(obs, archive, answers={"importWarning": "no"})
    assert "cancelled" in report["error"], report                           # "no" ends the import
    assert sorted(v2_flows(obs)) == before
    warning = [q for q in questions(obs) if q["kind"] == "importWarning"]
    assert len(warning) == 1, warning
    text = warning[0]["args"][0]
    assert "Default.Trigger_Hotkey" in text, text                        # acts on keys and mouse
    assert "Default.Action_Unknown_Thing (unknown element)" in text, text  # unknown classes count as acting
    assert "Default.Trigger_Periodic_Timer" not in text, text            # computes nothing that acts
    assert "rights" in text


def test_the_warning_says_so_when_no_element_acts(started, tmp_path):
    sup, obs = started(lambda d: flow_data(d))
    target = _export_skeleton(obs, tmp_path)
    import_file(obs, target, answers={"importWarning": "no"})
    warning = [q for q in questions(obs) if q["kind"] == "importWarning"]
    assert len(warning) == 1
    assert "None of the elements" in warning[0]["args"][0], warning[0]


# --- export ----------------------------------------------------------------------------------------------------------

def test_an_export_without_a_selection_is_refused(started, tmp_path):
    sup, obs = started(lambda d: flow_data(d))
    res = call(obs, "exportFlows", flowIds=[], path=str(tmp_path / "none.ahf"))
    assert not res["ok"] and "Select at least one" in res["error"], res
    assert not (tmp_path / "none.ahf").exists()
