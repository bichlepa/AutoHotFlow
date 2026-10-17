"""WI-0077, E0068, REQ-MIG-060: the import of the settings of v1 through the manager (headless).

The v1 data folder gets a settings.json as v1 writes it (`getDefaultSettings` of v1 plus the values of the test). The import
takes over the working directory, the language, the execution policy, the user level and the three log levels; it does not take
over start with Windows and run as administrator, and the options that v2 does not have. A value that v2 refuses is listed and
the v2 value stays. The settings are in force at once (cmd.settings.get) and in Settings.json.
"""

import json

from test_manager import connect_obs, wait_ready, wait_until
from test_manager_import import ONE_EXAMPLE, make_v1, run_import, started, state, tree_hash  # noqa: F401  (fixture)
from support.timing import scaled


def write_v1_settings(v1, **values):
    settings = {"UILanguage": "en", "runAsAdmin": False, "FlowExecutionPolicy": "parallel",
                "FlowWorkingDir": "C:\\Users\\x\\Documents\\AutoHotFlow", "HideDemoFlows": False, "ShowElementsLevel": "Beginner",
                "LogLevelFlow": 0, "LogLevelApp": 0, "LogLevelThread": 0, "LogToFile": False}
    settings.update(values)
    (v1 / "settings.json").write_text(json.dumps(settings, indent=2), encoding="utf-8")


def engine_settings(obs):
    answer = obs.request("engine", "cmd.settings.get", {}, timeout=5)["payload"]
    assert answer["ok"], answer
    return answer["settings"]


def settings_lines(result):
    return {s["name"]: s for s in result["settings"]}


def test_the_settings_of_v1_are_taken_over_as_e0068_says(started, tmp_path):
    v1 = make_v1(tmp_path / "v1", examples=[ONE_EXAMPLE])
    work = tmp_path / "v1 work"
    write_v1_settings(v1, UILanguage="de", FlowExecutionPolicy="skip", FlowWorkingDir=str(work), ShowElementsLevel="Advanced",
                      LogLevelFlow=1, LogLevelApp=3, LogLevelThread=2, runAsAdmin=True, LogToFile=True, HideDemoFlows=True)
    before = tree_hash(v1)
    sup, obs = started()
    result = run_import(obs, v1)
    assert result["ok"], result
    lines = settings_lines(result)
    for name in ("UILanguage", "FlowExecutionPolicy", "FlowWorkingDir", "ShowElementsLevel", "LogLevelFlow", "LogLevelApp",
                 "LogLevelThread"):
        assert lines[name]["state"] == "taken", lines[name]
    for name in ("runAsAdmin", "LogToFile", "HideDemoFlows"):
        assert lines[name]["state"] == "skipped", lines[name]
    s = engine_settings(obs)
    assert s["language"] == "de" and s["executionPolicy"] == "skip" and s["workingDir"] == str(work), s
    assert s["userLevel"] == "Advanced"
    assert (s["logLevelApp"], s["logLevelFlow"], s["logLevelThread"]) == (3, 1, 2)
    assert s["runAsAdmin"] is False and s["startWithWindows"] is False, "start with Windows and administrator are not taken over"
    on_disk = json.loads((sup.datadir / "Settings.json").read_text(encoding="utf-8-sig"))
    assert on_disk["language"] == "de" and on_disk["runAsAdmin"] is False
    assert tree_hash(v1) == before, "the v1 folder changed"


def test_a_value_that_v2_refuses_is_listed_and_the_v2_value_stays(started, tmp_path):
    v1 = make_v1(tmp_path / "v1", examples=[ONE_EXAMPLE])
    write_v1_settings(v1, FlowExecutionPolicy="sometimes", FlowWorkingDir="relative\\dir", LogLevelApp=2, UILanguage="ru")
    sup, obs = started()
    result = run_import(obs, v1)
    lines = settings_lines(result)
    assert lines["FlowExecutionPolicy"]["state"] == "skipped" and "policy" in lines["FlowExecutionPolicy"]["message"].lower()
    assert lines["FlowWorkingDir"]["state"] == "skipped"
    assert lines["UILanguage"]["state"] == "taken"
    s = engine_settings(obs)
    assert s["executionPolicy"] == "parallel" and s["workingDir"].endswith("\\AutoHotFlow") and s["language"] == "ru", s


def test_a_missing_or_broken_settings_file_does_not_stop_the_import(started, tmp_path):
    v1 = make_v1(tmp_path / "v1", examples=[ONE_EXAMPLE])
    sup, obs = started()
    result = run_import(obs, v1)
    assert result["settings"] == [], "no settings.json: no line"
    assert any(f["state"] == "created" for f in result["flows"])
    assert not (sup.datadir / "Settings.json").exists(), "nothing was written for the settings"
    (v1 / "settings.json").write_text("{ broken", encoding="utf-8")
    again = run_import(obs, v1)
    assert settings_lines(again)["settings.json"]["state"] == "failed", again["settings"]
    assert any(f["state"] in ("skipped", "copy") for f in again["flows"]), "the flows are handled anyway"
