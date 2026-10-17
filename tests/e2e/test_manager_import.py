"""WI-0076: the import of the flows and variables of v1 through the manager (REQ-MIG-060, REQ-SEC-060, E0068), headless.

The v1 data folder is a copy of tests/data/flows/v1_examples (laid out as a v1 data folder: Saved Flows/, a demo flow in
Saved Flows/demo flows/, Variables/, one broken flow file). The import runs through cmd.test.op "importV1" (the same chain
as the button; the folder dialog is not part of it). Questions are answered by the test ("answers"). The startup folder
is a folder of the test, never the real one: without it the headless manager leaves the autostart step out.

Checked: every flow of the folder is created with its ID and disabled; a flow with an existing ID is skipped and the v2 file
stays unchanged, or comes as a copy when the user says yes; a broken file is listed and the others go on; the demo flows are
not imported; a global variable that v2 has keeps its value, a static variable comes along with its flow; the source
folder is only read (hash before and after); the autostart shortcut of v1 is removed only after the yes, and a shortcut of
another program is kept.
"""

import hashlib
import json
import shutil
import subprocess
from pathlib import Path

import pytest

from test_manager import FLOW, Sup, connect_obs, flow_data, wait_flow_loaded, wait_ready, wait_until
from support.timing import scaled

EXAMPLES = Path(__file__).resolve().parents[1] / "data" / "flows" / "v1_examples"
EXAMPLE_COUNT = len(list(EXAMPLES.glob("*.json")))
DEMO_NAME = "Demo flow from v1"
BROKEN_NAME = "Broken flow"
ONE_EXAMPLE = "Flow 369404488"      # a v1 example flow (its name is the flow ID)


def make_v1(root, examples=None):
    """A v1 data folder under root: Saved Flows/ (examples, a demo flow, a broken file), Variables/ (global and static)."""
    saved = root / "Saved Flows"
    saved.mkdir(parents=True)
    for path in EXAMPLES.glob("*.json"):
        if examples is None or path.stem in examples:
            shutil.copy(path, saved / path.name)
    if examples is None:
        (saved / "demo flows").mkdir()
        shutil.copy(EXAMPLES / (ONE_EXAMPLE + ".json"), saved / "demo flows" / (DEMO_NAME + ".json"))
    (saved / (BROKEN_NAME + ".json")).write_text("{ this is not json", encoding="utf-8")
    variables = root / "Variables"
    variables.mkdir()
    (variables / "gx.ahfvd").write_text(json.dumps({"name": "gx", "type": "normal"}), encoding="utf-8")
    (variables / "gx.ahfvar").write_text("42", encoding="utf-8")
    static = variables / ONE_EXAMPLE
    static.mkdir()
    (static / "sv.ahfvd").write_text(json.dumps({"name": "sv", "type": "object"}), encoding="utf-8")
    (static / "sv.ahfvar").write_text('{"a": 1}', encoding="utf-8")
    return root


def tree_hash(root):
    """The bytes of every file under root, by relative path (the source folder must not change)."""
    out = {}
    for path in sorted(Path(root).rglob("*")):
        if path.is_file():
            out[str(path.relative_to(root))] = hashlib.sha256(path.read_bytes()).hexdigest()
    return out


def v1_exe(tmp_path):
    """The executable of v1 that the shortcut points to: in the folder that the test imports from (the portable layout)."""
    return tmp_path / "legacy" / "AutoHotFlow.exe"


def make_shortcut(folder, target):
    """A shortcut AutoHotFlow.lnk in the test startup folder that points to target (WScript.Shell, as v1 wrote it)."""
    folder.mkdir(parents=True, exist_ok=True)
    lnk = folder / "AutoHotFlow.lnk"
    script = ("$s = (New-Object -ComObject WScript.Shell).CreateShortcut('%s'); $s.TargetPath = '%s'; $s.Save()"
              % (lnk, target))
    subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", script], check=True, timeout=60)
    return lnk


def op(obs, op_name, **args):
    ans = obs.request("manager", "cmd.test.op", dict(op=op_name, **args), timeout=scaled(10))
    assert ans["payload"]["ok"], ans
    return ans["payload"]


def run_import(obs, v1, startup=None, answers=None):
    """The import through the manager's chain. answers: question kind -> "yes"/"no"; startup: the test startup folder.
    Returns the report (a Map: ok, error, flows, vars, autostart)."""
    op(obs, "answers", answers=answers or {})
    args = {"dir": str(v1)}
    if startup is not None:
        args["startupDir"] = str(startup)
    ans = obs.request("manager", "cmd.test.op", dict(op="importV1", **args), timeout=scaled(240))
    assert ans["payload"]["ok"] is not None, ans
    return ans["payload"]


def state(obs):
    return obs.request("manager", "cmd.test.state", {}, timeout=5)["payload"]["state"]


def flows_by_name(result):
    return {f["name"]: f for f in result["flows"]}


def v2_flows(obs):
    return {f["flowId"]: f for f in state(obs)["flows"]}


@pytest.fixture
def started(procs, datadir, session_id):
    """Opens a supervisor (storage, engine, headless manager) after the setup; closes it at the end."""
    running = []

    def make(setup=None):
        if setup is not None:
            setup(datadir)
        else:
            flow_data(datadir)
        sup = Sup(procs, datadir, session_id, ["--start=storage,engine,manager", "--headless"])
        obs = connect_obs(sup.pipe)
        wait_ready(obs, ["storage", "engine", "manager"])
        wait_flow_loaded(obs)
        assert wait_until(lambda: FLOW in v2_flows(obs), scaled(10)), "the manager has no snapshot"
        running.append((sup, obs))
        return sup, obs

    yield make
    for sup, obs in running:
        obs.close()
        sup.close_files()


# --- the flows ------------------------------------------------------------------------------------------------------

def test_every_flow_of_the_folder_is_imported_with_its_id_and_disabled(started, tmp_path):
    v1 = make_v1(tmp_path / "v1")
    before = tree_hash(v1)
    sup, obs = started()
    result = run_import(obs, v1)

    flows = flows_by_name(result)
    assert len(flows) == EXAMPLE_COUNT + 1, sorted(flows)        # the examples and the broken file; the demo flow is not listed
    assert DEMO_NAME not in flows
    assert flows[BROKEN_NAME]["state"] == "failed", flows[BROKEN_NAME]
    created = [f for f in result["flows"] if f["state"] == "created"]
    assert len(created) == EXAMPLE_COUNT, [(f["name"], f["state"], f["message"]) for f in result["flows"] if f["state"] != "created"][:4]
    for f in created:
        assert f["flowId"] == f["name"], f                     # the v1 file name is the ID

    assert wait_until(lambda: len(v2_flows(obs)) == EXAMPLE_COUNT + 1, scaled(20)), sorted(v2_flows(obs))
    for f in created:
        rec = v2_flows(obs)[f["name"]]
        assert not rec["enabled"], rec                         # imported flows are disabled (E0058, REQ-SEC-060)
    assert (sup.datadir / "Flows" / (ONE_EXAMPLE + ".json")).is_file()
    assert tree_hash(v1) == before, "the v1 folder changed"    # only read (E0068)


def test_a_flow_whose_id_exists_is_skipped_and_the_v2_file_stays(started, tmp_path):
    v1 = make_v1(tmp_path / "v1", examples=[ONE_EXAMPLE])

    def setup(d):
        flow_data(d)
        shutil.copy(EXAMPLES / (ONE_EXAMPLE + ".json"), d / "Flows" / (ONE_EXAMPLE + ".json"))

    sup, obs = started(setup)
    v2_file = sup.datadir / "Flows" / (ONE_EXAMPLE + ".json")
    before = v2_file.read_bytes()
    result = run_import(obs, v1, answers={"importCopies": "no"})
    assert flows_by_name(result)[ONE_EXAMPLE]["state"] == "skipped"
    assert v2_file.read_bytes() == before, "the v2 flow was changed"


def test_with_the_copy_answer_the_existing_flow_comes_as_a_copy_with_a_number(started, tmp_path):
    v1 = make_v1(tmp_path / "v1", examples=[ONE_EXAMPLE])

    def setup(d):
        flow_data(d)
        shutil.copy(EXAMPLES / (ONE_EXAMPLE + ".json"), d / "Flows" / (ONE_EXAMPLE + ".json"))

    sup, obs = started(setup)
    result = run_import(obs, v1, answers={"importCopies": "yes"})
    copy = flows_by_name(result)[ONE_EXAMPLE]
    assert copy["state"] == "copy", copy
    assert copy["flowId"] != ONE_EXAMPLE
    assert wait_until(lambda: len(v2_flows(obs)) == 3, scaled(10)), sorted(v2_flows(obs))
    assert copy["as"] == "string test 2", copy        # the name of the v1 flow with the next number (v1 name, not the file name)
    assert v2_flows(obs)[copy["flowId"]]["name"] == copy["as"]
    assert not v2_flows(obs)[copy["flowId"]]["enabled"]
    assert (sup.datadir / "Flows" / (ONE_EXAMPLE + ".json")).is_file()


def test_a_question_about_copies_is_asked_only_when_a_flow_exists(started, tmp_path):
    v1 = make_v1(tmp_path / "v1", examples=[ONE_EXAMPLE])
    sup, obs = started()
    result = run_import(obs, v1, answers={"importCopies": "yes"})
    assert flows_by_name(result)[ONE_EXAMPLE]["state"] == "created"


# --- the variables ---------------------------------------------------------------------------------------------------

def test_a_global_variable_that_v2_has_keeps_its_value_and_statics_come_with_their_flow(started, tmp_path):
    v1 = make_v1(tmp_path / "v1", examples=[ONE_EXAMPLE])

    def setup(d):
        flow_data(d)
        (d / "Variables").mkdir()
        (d / "Variables" / "gx.ahfvd").write_text(json.dumps({"name": "gx", "type": "normal"}), encoding="utf-8")
        (d / "Variables" / "gx.ahfvar").write_text("7", encoding="utf-8")

    sup, obs = started(setup)
    result = run_import(obs, v1)
    states = {(v["scope"], v["name"]): v["state"] for v in result["vars"]}
    assert states[("global", "gx")] == "kept", result["vars"]
    assert states[("static", "sv")] == "taken", result["vars"]
    assert (sup.datadir / "Variables" / "gx.ahfvar").read_text(encoding="utf-8") == "7"
    static_file = sup.datadir / "Variables" / ONE_EXAMPLE / "sv.ahfvar"
    assert wait_until(static_file.is_file, scaled(10)), "the static variable was not written"
    assert json.loads(static_file.read_text(encoding="utf-8")) == {"a": 1}


# --- the autostart shortcut of v1 ------------------------------------------------------------------------------------

def test_the_autostart_shortcut_of_v1_is_kept_when_the_user_says_no(started, tmp_path):
    v1 = make_v1(tmp_path / "legacy", examples=[ONE_EXAMPLE])
    startup = tmp_path / "startup"
    lnk = make_shortcut(startup, str(v1_exe(tmp_path)))
    sup, obs = started()
    result = run_import(obs, v1, startup=startup, answers={"autostartV1": "no"})
    assert result["autostart"] == "kept", result
    assert lnk.is_file()


def test_the_autostart_shortcut_of_v1_is_removed_when_the_user_says_yes(started, tmp_path):
    v1 = make_v1(tmp_path / "legacy", examples=[ONE_EXAMPLE])
    startup = tmp_path / "startup"
    lnk = make_shortcut(startup, str(v1_exe(tmp_path)))
    sup, obs = started()
    result = run_import(obs, v1, startup=startup, answers={"autostartV1": "yes"})
    assert result["autostart"] == "removed", result
    assert not lnk.exists()


def test_a_shortcut_of_another_program_is_not_asked_and_not_removed(started, tmp_path):
    v1 = make_v1(tmp_path / "v1", examples=[ONE_EXAMPLE])
    startup = tmp_path / "startup"
    lnk = make_shortcut(startup, r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe")
    sup, obs = started()
    result = run_import(obs, v1, startup=startup, answers={"autostartV1": "yes"})
    assert result["autostart"] == "other", result
    assert lnk.is_file()


def test_without_a_startup_folder_the_autostart_step_is_left_out(started, tmp_path):
    v1 = make_v1(tmp_path / "v1", examples=[ONE_EXAMPLE])
    sup, obs = started()
    result = run_import(obs, v1)
    assert result["autostart"] == "none", result


# --- the report and the source folder ----------------------------------------------------------------------------------

def test_the_report_has_the_places_the_engine_marked(started, tmp_path):
    v1 = make_v1(tmp_path / "v1", examples=[ONE_EXAMPLE])
    sup, obs = started()
    result = run_import(obs, v1)
    created = flows_by_name(result)[ONE_EXAMPLE]
    assert created["state"] == "created", created
    assert isinstance(created["places"], list), created
    assert result["error"] == ""


def test_a_missing_v1_folder_is_an_error_and_nothing_is_created(started, tmp_path):
    sup, obs = started()
    result = run_import(obs, tmp_path / "nowhere")
    assert not result["ok"] and result["error"] != "", result
    assert result["flows"] == [], result
    assert not (sup.datadir / "Flows" / (ONE_EXAMPLE + ".json")).exists()


def test_a_global_variable_that_v2_lacks_is_taken_over_and_written(started, tmp_path):
    v1 = make_v1(tmp_path / "v1", examples=[ONE_EXAMPLE])
    sup, obs = started()
    result = run_import(obs, v1)
    states = {(v["scope"], v["name"]): v["state"] for v in result["vars"]}
    assert states[("global", "gx")] == "taken", result["vars"]
    gx = sup.datadir / "Variables" / "gx.ahfvar"
    assert wait_until(gx.is_file, scaled(10)), "the global variable was not written"
    assert gx.read_text(encoding="utf-8") == "42"


def test_the_report_names_the_migration_places_of_an_imported_flow(started, tmp_path):
    v1 = make_v1(tmp_path / "v1", examples=[])
    # a v1 flow with expressions that the converter marks (MIGRATION IDs, the same flow as tests/test_migration_report.py)
    marked = {
        "name": "Marked flow", "category": "Tests", "ElementIDCounter": "4",
        "allElements": {
            "e1": {"ID": "e1", "type": "action", "package": "Default", "class": "Action_Sleep",
                   "pars": {"Duration": 'x < "abc"', "Unit": "Seconds"}},
            "e3": {"ID": "e3", "type": "action", "package": "default", "class": "Action_Sleep",
                   "pars": {"Duration": "7 % 3"}},
        },
        "allConnections": {},
    }
    (v1 / "Saved Flows" / "Marked flow.json").write_text(json.dumps(marked), encoding="utf-8")
    sup, obs = started()
    result = run_import(obs, v1)
    created = flows_by_name(result)["Marked flow"]
    assert created["state"] == "created", created
    places = created["places"]
    assert places, "the flow carries MIGRATION places, the report must list them"
    assert all(p["ids"] for p in places), places
    assert all(p["element"] and p["par"] for p in places), places


def test_a_flow_id_with_a_path_is_refused_by_the_engine(started):
    sup, obs = started()
    for bad in ["../x", "a/b", "a\\b", "."]:
        ans = obs.request("engine", "cmd.flow.create", {"flowId": bad, "definition": {"name": "Bad id"}}, timeout=scaled(10))
        payload = ans["payload"]
        assert not payload.get("ok", 0), (bad, payload)
        assert payload["error"]["code"] == "bad_payload", (bad, payload)
    assert not (sup.datadir / "Flows" / "x.json").exists()


def test_storage_refuses_to_remove_a_shortcut_of_another_program(started, tmp_path):
    sup, obs = started()
    startup = tmp_path / "startup"
    lnk = make_shortcut(startup, r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe")
    ans = obs.request("storage", "cmd.storage.autostart.remove", {"startupDir": str(startup)}, timeout=scaled(10))
    assert ans["payload"]["error"]["code"] == "denied", ans
    assert lnk.is_file()


def test_storage_does_not_take_the_running_v2_product_for_v1(started, tmp_path):
    sup, obs = started()
    startup = tmp_path / "startup"
    make_shortcut(startup, str(tmp_path / "src" / "AutoHotFlow.ahk"))
    ans = obs.request("storage", "cmd.storage.autostart.check", {"startupDir": str(startup)}, timeout=scaled(10))
    assert ans["payload"]["ok"] and not ans["payload"]["v1"], ans
