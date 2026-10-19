"""WI-0078: the settings dialog of the manager and the change of the language without a restart (headless).

REQ-SET-010, REQ-SET-020, REQ-SET-050, REQ-SET-070, REQ-LNG-020, REQ-MGR-140 (the tray menu follows the language).

The OK of the dialog runs through the same path as the test command: cmd.test.op "settings" checks the values with
SettingsForm.Collect and sends the checked set with ManagerModel.SetSettings (cmd.settings.set). A refused value is named
and nothing is sent. The window itself is not checked here (the gui tier, tests/fault/test_manager_settings_window.py).
The tray menu changes its texts when the language changes: its snapshot lists them (the role's info items).
"""

import json
import time

from test_manager_import import started  # noqa: F401  (fixture: supervisor with storage, engine and the headless manager)
from test_manager_import_settings import engine_settings
from support.flowrun import FlowRunner, flows  # noqa: F401  (fixture)
from support.timing import scaled

WAIT_S = scaled(8.0)


def wait_for(predicate, timeout=WAIT_S):
    deadline = time.monotonic() + timeout
    while True:
        value = predicate()
        if value:
            return value
        if time.monotonic() > deadline:
            return None
        time.sleep(0.05)


def settings_op(obs, settings):
    """The OK of the dialog: the payload of cmd.test.op settings (ok, sent, errors, code, message)."""
    ans = obs.request("manager", "cmd.test.op", {"op": "settings", "settings": settings}, timeout=scaled(10))
    return ans["payload"]


def on_disk(sup):
    return json.loads((sup.datadir / "Settings.json").read_text(encoding="utf-8-sig"))


def test_a_checked_set_from_the_dialog_reaches_the_engine_and_the_file(started):  # noqa: F811
    sup, obs = started()
    answer = settings_op(obs, {"workers": "4", "logLevelApp": "3", "language": "DE", "notifyUnhandledErrors": 0,
                               "userLevel": "Advanced"})
    assert answer["ok"] is True and answer["sent"] is True, answer
    s = engine_settings(obs)
    assert s["workers"] == 4 and s["logLevelApp"] == 3 and s["language"] == "de" and s["userLevel"] == "Advanced", s
    assert s["notifyUnhandledErrors"] is False
    stored = on_disk(sup)
    assert stored["workers"] == 4 and stored["notifyUnhandledErrors"] is False and stored["language"] == "de", stored


def test_a_refused_value_is_named_and_nothing_is_sent(started):  # noqa: F811
    sup, obs = started()
    before = engine_settings(obs)
    answer = settings_op(obs, {"workers": "17", "executionPolicy": "sometimes", "logLevelFlow": "3"})
    assert answer["ok"] is False and answer["sent"] is False, answer
    assert set(answer["errors"]) == {"workers", "executionPolicy"}, answer["errors"]
    assert "1 to 16" in answer["errors"]["workers"] and "setting" not in answer["errors"]["workers"], answer["errors"]
    assert engine_settings(obs) == before, "a refused set changes nothing"
    assert not (sup.datadir / "Settings.json").exists(), "nothing was written: the defaults stay"


def test_a_setting_the_dialog_does_not_show_is_refused_by_name(started):  # noqa: F811
    sup, obs = started()
    answer = settings_op(obs, {"startWithWindows": True})
    assert answer["ok"] is False and answer["sent"] is False, answer
    assert "startWithWindows" in answer["errors"], answer
    assert engine_settings(obs)["startWithWindows"] is False, "the autostart keys belong to WI-0079"


def role_info(runner, name):
    """The role part of the snapshot of one role, or None while the role is not connected yet."""
    answer = runner.request(name, "cmd.diag.snapshot", {})
    return answer["snapshot"]["info"] if answer.get("ok") else None


def tray_items(runner):
    info = role_info(runner, "tray")
    return [item.strip() for item in info["items"]] if info else None


def test_the_language_changes_the_tray_menu_and_the_manager_without_a_restart(procs, datadir, session_id):
    runner = FlowRunner(procs, datadir, session_id, roles="storage,engine,manager,tray")
    runner.start(extra=("--headless",))
    try:
        assert wait_for(lambda: tray_items(runner)), "the tray role is not there"
        assert tray_items(runner) == ["Show manager", "Exit"], tray_items(runner)
        assert role_info(runner, "manager")["language"] == "en"

        answer = runner.request("manager", "cmd.test.op", {"op": "settings", "settings": {"language": "de"}})
        assert answer["ok"] is True and answer["sent"] is True, answer
        assert wait_for(lambda: tray_items(runner) == ["Manager zeigen", "Beenden"]), tray_items(runner)
        assert wait_for(lambda: role_info(runner, "manager")["language"] == "de"), "the manager has not taken the language"

        runner.request("manager", "cmd.test.op", {"op": "settings", "settings": {"language": ""}})
        assert wait_for(lambda: tray_items(runner) == ["Show manager", "Exit"]), "empty means the language of Windows"
    finally:
        runner.close()
