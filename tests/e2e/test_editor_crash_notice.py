"""WI-0103, REQ-ROB-120, E0093: an editor that ends unexpectedly is told to the user, and a click opens it again.

The real supervisor with the storage, the engine, the headless manager and the headless tray role (started with --tray,
it stays hidden). What is checked: a killed editor gives one notice (kind editor, topic notice, seen by the manager's
list and the tray role, which links its balloon to the flow); a closed editor and a deleted flow give none; the click on
the balloon (the test command item "notice" of the tray) and the button "Open editor" of the manager's list (the test
operation openNotice) start the editor again. Nothing reopens it by itself (E0093): the process stays down until a click.

The real balloon click (the message of the shell) is in tests/fault/test_editor_crash_notice_gui.py (gui, owner only).
"""

import psutil

from support.timing import scaled
from test_manager import FLOW, process_states, wait_until
from test_manager_editor import finish, op, start_manager, state as manager_state
from test_editor import editor_process, editor_state, open_editor

EDITOR = "editor:" + FLOW
TRAY_ARGS = ("--tray",)


def start(procs, datadir, session_id):
    """The session with the tray role, once the tray has subscribed to topic notice (a notice sent before that is lost)."""
    sup, obs = start_manager(procs, datadir, session_id, extra=TRAY_ARGS)

    def subscribed():
        ans = obs.request("supervisor", "cmd.diag.snapshot", {}, timeout=scaled(5))["payload"]["snapshot"]
        links = ans.get("hub", {}).get("links", [])
        return {l["name"] for l in links if "notice" in l.get("topics", [])} >= {"manager", "tray"}
    assert wait_until(subscribed, scaled(20)), "manager or tray did not subscribe to topic notice"
    return sup, obs


def editor_notices(obs):
    return [n for n in manager_state(obs)["notices"] if n["kind"] == "editor"]


def tray_info(obs):
    return obs.request("tray", "cmd.diag.snapshot", {}, timeout=scaled(5))["payload"]["snapshot"]["info"]


def tray_click(obs):
    """The click on the balloon, as the tray role runs it (item notice of cmd.test.command)."""
    ans = obs.request("tray", "cmd.test.command", {"item": "notice"}, timeout=scaled(5))
    assert ans["payload"]["ok"], ans
    return ans["payload"]["sent"]


def kill_editor(obs):
    pid = editor_process(obs)["pid"]
    psutil.Process(pid).kill()
    assert wait_until(lambda: editor_process(obs).get("state") == "crashed", scaled(15)), editor_process(obs)
    return pid


def wait_editor_again(obs, old_pid):
    """The editor process runs again with a new pid and has loaded its flow."""
    def again():
        proc = editor_process(obs)
        return proc.get("state") == "ready" and proc.get("pid") not in (None, old_pid) and \
            (editor_state(obs) or {}).get("rev", -1) >= 1
    assert wait_until(again, scaled(30)), editor_process(obs)


def test_a_killed_editor_gives_one_notice_and_the_tray_links_its_balloon(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        kill_editor(obs)
        assert wait_until(lambda: len(editor_notices(obs)) == 1, scaled(15)), manager_state(obs)["notices"]
        n = editor_notices(obs)[0]
        assert (n["kind"], n["level"], n["flowId"], n["key"], n["args"]) == \
            ("editor", "error", FLOW, "Notice_editor_crashed", [FLOW]), n
        assert wait_until(lambda: tray_info(obs)["editorFlow"] == FLOW, scaled(15)), tray_info(obs)
        assert tray_info(obs)["notices"] == 1, tray_info(obs)
        assert editor_process(obs).get("restarts", 0) == 0, editor_process(obs)
    finally:
        finish(sup, obs)


def test_a_closed_editor_gives_no_notice(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        ans = obs.request(EDITOR, "cmd.test.close", {}, timeout=scaled(5))
        assert ans["payload"]["ok"], ans
        assert wait_until(lambda: editor_process(obs).get("state") == "exited", scaled(15)), editor_process(obs)
        assert editor_process(obs).get("clean") in (True, None), editor_process(obs)
        assert editor_notices(obs) == [], manager_state(obs)["notices"]
        assert tray_info(obs)["notices"] == 0, tray_info(obs)
        assert tray_info(obs)["editorFlow"] == "", tray_info(obs)
    finally:
        finish(sup, obs)


def test_a_deleted_flow_gives_no_notice(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        op(obs, "answers", answers={"delete": "yes"})
        op(obs, "delete", flowIds=[FLOW])
        assert wait_until(lambda: editor_process(obs).get("state") == "exited", scaled(15)), editor_process(obs)
        assert editor_notices(obs) == [], manager_state(obs)["notices"]
    finally:
        finish(sup, obs)


def test_a_click_on_the_balloon_opens_the_editor_again_once(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        old = kill_editor(obs)
        assert wait_until(lambda: tray_info(obs)["editorFlow"] == FLOW, scaled(15)), tray_info(obs)
        assert tray_click(obs) is True
        wait_editor_again(obs, old)
        assert tray_info(obs)["editorFlow"] == "", "the click must clear the link"
        assert tray_click(obs) is False, "a second click on the same balloon sends nothing"
        # nothing reopened it before the click, and the editor is not restarted by the supervisor on its own
        assert editor_process(obs).get("restarts", 0) == 0, editor_process(obs)
    finally:
        finish(sup, obs)


def test_the_button_open_editor_of_the_list_opens_the_editor_again(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        old = kill_editor(obs)
        assert wait_until(lambda: len(editor_notices(obs)) == 1, scaled(15)), manager_state(obs)["notices"]
        n = editor_notices(obs)[0]["n"]
        answer = op(obs, "openNotice", n=n)
        assert answer["sent"] is True, answer
        wait_editor_again(obs, old)
    finally:
        finish(sup, obs)


def test_a_process_that_is_not_running_is_not_started_by_a_notice_alone(procs, datadir, session_id):
    """No automatic reopen (E0093): after the notice the editor stays down until a click or the button."""
    sup, obs = start(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        kill_editor(obs)
        assert wait_until(lambda: len(editor_notices(obs)) == 1, scaled(15)), manager_state(obs)["notices"]
        assert not wait_until(lambda: editor_process(obs).get("state") == "ready", scaled(3)), editor_process(obs)
        assert process_states(obs)[EDITOR]["state"] == "crashed", process_states(obs)[EDITOR]
    finally:
        finish(sup, obs)
