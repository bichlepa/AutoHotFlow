"""WI-0091, REQ-EDT-230, REQ-EDT-110 (run and enable from the editor, part): the tray icon and the tray menu of an editor
(src/editor/EditorTray.ahk, EditorFlowOps.ahk, PROTOCOL 4.11) under the real supervisor, headless. The editor is started the
way the user does it (the manager's operation "edit"). The menu entries run through the driver (cmd.test.command {item,
answer}), which calls the same methods as a click; the questions of the flow commands are answered by the driver. The result
of an entry is read in tray.lastResult of cmd.test.state, the icon in tray.icon.

The icon itself (a real icon, a real open menu) is tested in tests/fault/test_editor_tray.py (gui), not here.
"""

import json
from pathlib import Path

import pytest

from support.timing import scaled
from test_manager import FLOW, SKELETON_SRC, wait_until
from test_manager_editor import finish, op, start_manager, supervisor_log
from test_editor import editor_state, editor_process, open_editor, prepare_running, write_flow
from test_manager_flows import add_independent_trigger, INDEPENDENT, _lock_state_file, LOCKS

EDITOR = "editor:" + FLOW
ICON_STATES = ("disabled", "enabled", "running")


def tray(obs, item, answer="no"):
    """Runs one menu entry as the click does; the answer comes at once, the result is in tray.lastResult."""
    ans = obs.request(EDITOR, "cmd.test.command", {"item": item, "answer": answer}, timeout=scaled(5))
    assert ans["payload"]["ok"], ans
    return ans["payload"]


def tray_state(obs):
    return (editor_state(obs, EDITOR) or {}).get("tray", {})


def flow_state(obs):
    return (editor_state(obs, EDITOR) or {}).get("flowState", {})


def asked(obs):
    return (editor_state(obs, EDITOR) or {}).get("asked", [])


def prepare_policy_skip(datadir):
    """The skeleton with an action of 8 s and the policy skip: a second start while it runs is refused (busy)."""
    write_flow(datadir, FLOW, duration=8000)
    path = Path(datadir) / "Flows" / (FLOW + ".json")
    data = json.loads(path.read_text(encoding="utf-8"))
    data["flowSettings"]["ExecutionPolicy"] = "skip"
    path.write_text(json.dumps(data), encoding="utf-8")


def prepare_independent(datadir):
    """The skeleton with one independent trigger that is enabled: the flow is not enabled, but independentActive is 1."""
    data = json.loads(SKELETON_SRC.read_text(encoding="utf-8"))
    add_independent_trigger(data)
    flows = Path(datadir) / "Flows"
    flows.mkdir(exist_ok=True)
    (flows / (FLOW + ".json")).write_text(json.dumps(data), encoding="utf-8")
    (Path(datadir) / "FlowStates").mkdir(exist_ok=True)
    (Path(datadir) / "FlowStates" / (FLOW + ".json")).write_text(
        json.dumps({"formatVersion": 1, "enabled": [INDEPENDENT]}), encoding="utf-8")


def test_the_editor_has_an_icon_a_tooltip_and_the_four_entries_and_the_icon_is_hidden_when_headless(
        procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        st = open_editor(obs)
        t = st["tray"]
        assert t["iconHidden"] is True, t                                  # --headless: no icon
        assert t["tip"] == "Flow: " + st["name"], t
        assert t["items"][0] == "Show" and t["items"][1] == "Run" and t["items"][3] == "Close", t
        enabled = st["flowState"]["enabled"] or st["flowState"]["independentActive"] > 0
        assert t["items"][2] == ("Disable" if enabled else "Enable"), t
        assert t["icon"] == ("enabled" if st["flowState"]["enabled"] else "disabled"), t
        assert st["flowState"]["enabled"] is False, st                      # the skeleton starts disabled
        assert st["ended"] == "", st
    finally:
        finish(sup, obs)


def test_the_menu_enables_and_disables_the_flow_and_the_icon_follows(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        tray(obs, "toggle")
        assert wait_until(lambda: flow_state(obs).get("enabled") is True, scaled(10)), editor_state(obs, EDITOR)
        t = tray_state(obs)
        assert t["icon"] == "enabled" and t["items"][2] == "Disable" and t["lastResult"] == "toggle: ok", t
        tray(obs, "toggle")
        assert wait_until(lambda: flow_state(obs).get("enabled") is False, scaled(10)), editor_state(obs, EDITOR)
        t = tray_state(obs)
        assert t["icon"] == "disabled" and t["items"][2] == "Enable" and t["notices"] == 0, t
    finally:
        finish(sup, obs)


def test_run_starts_the_flow_and_the_icon_shows_running_until_the_end(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, prepare=prepare_running)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        tray(obs, "run")
        assert wait_until(lambda: tray_state(obs).get("icon") == "running", scaled(10)), editor_state(obs, EDITOR)
        assert tray_state(obs)["lastResult"] == "run: ok", tray_state(obs)
        assert wait_until(lambda: tray_state(obs).get("icon") != "running", scaled(30)), editor_state(obs, EDITOR)
        assert tray_state(obs)["notices"] == 0, tray_state(obs)
    finally:
        finish(sup, obs)


def test_a_run_refused_while_the_flow_runs_is_a_tray_notice_and_no_second_instance_starts(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, prepare=prepare_policy_skip)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        tray(obs, "run")
        assert wait_until(lambda: tray_state(obs).get("icon") == "running", scaled(10)), editor_state(obs, EDITOR)
        tray(obs, "run")                              # policy skip: refused as busy
        assert wait_until(lambda: tray_state(obs).get("notices") == 1, scaled(10)), tray_state(obs)
        t = tray_state(obs)
        assert t["lastResult"] == "run: busy", t
        assert "refused" in t["lastNotice"], t
    finally:
        finish(sup, obs)


def test_the_question_of_the_independent_triggers_no_leaves_them_on(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, prepare=prepare_independent)
    try:
        op(obs, "select", flowId=FLOW)
        st = open_editor(obs)
        assert st["flowState"]["independentActive"] == 1 and st["flowState"]["enabled"] is False, st
        assert tray_state(obs)["items"][2] == "Disable", tray_state(obs)     # an independent trigger is on
        tray(obs, "toggle", answer="no")
        assert wait_until(lambda: tray_state(obs).get("lastResult") == "toggle: cancelled", scaled(10)), tray_state(obs)
        assert asked(obs) == ["independent"], asked(obs)
        assert flow_state(obs)["independentActive"] == 1, editor_state(obs, EDITOR)
    finally:
        finish(sup, obs)


def test_the_question_of_the_independent_triggers_yes_disables_them_too(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, prepare=prepare_independent)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        tray(obs, "toggle", answer="yes")
        assert wait_until(lambda: flow_state(obs).get("independentActive") == 0, scaled(10)), editor_state(obs, EDITOR)
        assert tray_state(obs)["lastResult"] == "toggle: ok", tray_state(obs)
        assert asked(obs) == ["independent"], asked(obs)
        assert tray_state(obs)["items"][2] == "Enable", tray_state(obs)
    finally:
        finish(sup, obs)


def test_a_state_that_cannot_be_read_asks_for_the_force_no_changes_nothing_yes_writes_it(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, prepare=_lock_state_file())
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        tray(obs, "toggle", answer="no")
        assert wait_until(lambda: tray_state(obs).get("lastResult") == "toggle: cancelled", scaled(10)), tray_state(obs)
        assert asked(obs) == ["force"], asked(obs)
        assert flow_state(obs)["enabled"] is False, editor_state(obs, EDITOR)
        tray(obs, "toggle", answer="yes")
        assert wait_until(lambda: flow_state(obs).get("enabled") is True, scaled(10)), editor_state(obs, EDITOR)
        assert tray_state(obs)["lastResult"] == "toggle: ok", tray_state(obs)
    finally:
        finish(sup, obs)
        import ctypes
        kernel = ctypes.WinDLL("kernel32")
        for handle in LOCKS:
            kernel.CloseHandle(handle)
        LOCKS.clear()


def test_show_brings_the_window_and_close_ends_the_editor_as_a_planned_end(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        tray(obs, "show")
        assert tray_state(obs)["lastResult"] == "show: ok", tray_state(obs)
        tray(obs, "close")
        assert wait_until(lambda: editor_process(obs).get("state") == "exited", scaled(15)), editor_process(obs)
        assert editor_process(obs).get("clean") in (True, None), editor_process(obs)
        assert not any("unexpectedly" in t for t in supervisor_log(obs)), supervisor_log(obs)
    finally:
        finish(sup, obs)


def test_a_rename_changes_the_tooltip_of_the_icon(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        ans = obs.request("manager", "cmd.test.op", {"op": "rename", "flowId": FLOW, "name": "Renamed flow"},
                          timeout=scaled(10))
        assert ans["payload"]["ok"], ans
        assert wait_until(lambda: tray_state(obs).get("tip") == "Flow: Renamed flow", scaled(10)), tray_state(obs)
    finally:
        finish(sup, obs)


def test_a_bad_item_of_the_test_command_is_bad_payload(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        ans = obs.request(EDITOR, "cmd.test.command", {"item": "exit"}, timeout=scaled(5))
        assert ans["payload"].get("error", {}).get("code") == "bad_payload", ans
    finally:
        finish(sup, obs)
