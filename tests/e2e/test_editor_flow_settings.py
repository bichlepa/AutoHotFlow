"""WI-0109, REQ-EDT-140 (the flow settings dialog), REQ-EXE-050, REQ-EXE-130, REQ-EXE-170, REQ-VAR-100 (the keys it writes):
the flow settings dialog of the editor under the real supervisor, headless. The dialog is driven through cmd.test.flowsettings
(the same calls as the window makes on EditorFlowSettings); the menu entry Settings is checked through cmd.test.command.
What is checked: OK sends one patch with the changed keys and it is one undo step; Cancel and an OK without a change send
nothing; an invalid limit keeps the dialog open and sends nothing; the state says whether the flow is migrated.
The window itself is checked by tests/fault/test_editor_flow_settings_gui.py (owner) and tests/ahk/editor_flow_settings_window.test.ahk.

Deterministic: a test waits for a condition of the editor or of the engine (wait_until), never for a fixed time.
"""

import test_editor_select as sel
from support.timing import scaled
from test_manager import FLOW, wait_until
from test_manager_editor import finish, op, start_manager, state as manager_state
from test_editor import editor_state, open_editor
from test_editor_draft import engine_definition, settled, step

EDITOR = "editor:" + FLOW


def start(procs, datadir, session_id):
    return sel.start(procs, datadir, session_id)


def dialog(obs, action, **payload):
    """cmd.test.flowsettings: the answer's payload (ok, changed or error)."""
    ans = obs.request(EDITOR, "cmd.test.flowsettings", dict(action=action, **payload), timeout=scaled(5))
    return ans["payload"]


def dialog_state(obs):
    return editor_state(obs, EDITOR)["flowSettings"]


def rev(obs):
    return editor_state(obs, EDITOR)["rev"]


def wait_settled(obs):
    assert wait_until(lambda: settled(obs), scaled(10)), editor_state(obs, EDITOR)


def flow_settings(obs):
    return dict(engine_definition(obs).get("flowSettings", {}))


def test_the_menu_entry_settings_opens_the_dialog_of_the_flow(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        ans = obs.request(EDITOR, "cmd.test.command", {"item": "settings"}, timeout=scaled(5))
        assert ans["payload"]["ok"] and ans["payload"]["ran"] == 1, ans
        st = dialog_state(obs)
        assert st["open"] is True and st["name"] == engine_definition(obs)["name"], st
        assert st["changed"] is False, "nothing changed yet"
        assert dialog(obs, "cancel")["ok"]
        assert dialog_state(obs)["open"] is False
    finally:
        finish(sup, obs)


def test_ok_sends_the_changed_keys_as_one_patch_and_one_undo_step(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = flow_settings(obs)
        before_rev = rev(obs)
        assert dialog(obs, "open")["ok"]
        assert dialog(obs, "set", field="policy", value="wait")["ok"]
        assert dialog(obs, "set", field="limit:maxParallelInstances", value="7")["ok"]
        assert dialog_state(obs)["changed"] is True
        answer = dialog(obs, "ok")
        assert answer["ok"] is True and answer["changed"] is True, answer
        assert dialog_state(obs)["open"] is False, "the dialog closes after OK"
        assert wait_until(lambda: rev(obs) > before_rev and settled(obs), scaled(10)), editor_state(obs, EDITOR)
        after = flow_settings(obs)
        assert after["ExecutionPolicy"] == "wait", after
        assert int(after["maxParallelInstances"]) == 7, after
        assert step(obs, "undo", EDITOR)["done"], "the change is one undo step"
        wait_settled(obs)
        restored = flow_settings(obs)
        assert restored.get("ExecutionPolicy") == before.get("ExecutionPolicy"), (before, restored)
        assert restored.get("maxParallelInstances") == before.get("maxParallelInstances"), (before, restored)
    finally:
        finish(sup, obs)


def test_cancel_and_an_ok_without_a_change_send_nothing(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before_rev = rev(obs)
        assert dialog(obs, "open")["ok"]
        assert dialog(obs, "set", field="policy", value="skip")["ok"]
        assert dialog(obs, "cancel")["ok"]
        assert dialog_state(obs)["open"] is False
        assert dialog(obs, "open")["ok"]
        answer = dialog(obs, "ok")
        assert answer["ok"] is True and answer["changed"] is False, answer
        assert wait_until(lambda: settled(obs), scaled(10))
        assert rev(obs) == before_rev, "nothing changed, nothing was sent"
    finally:
        finish(sup, obs)


def test_an_invalid_limit_keeps_the_dialog_open_and_sends_nothing(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before_rev = rev(obs)
        assert dialog(obs, "open")["ok"]
        assert dialog(obs, "set", field="limit:maxWaitingInstances", value="many")["ok"]
        answer = dialog(obs, "ok")
        assert answer["ok"] is False and answer["error"]["code"] == "bad_payload", answer
        assert dialog_state(obs)["open"] is True, "the dialog stays open to correct the value"
        assert dialog(obs, "set", field="limit:maxWaitingInstances", value="default")["ok"]
        assert dialog(obs, "ok")["changed"] is False, "back to the value of the flow: nothing to send"
        assert wait_until(lambda: settled(obs), scaled(10))
        assert rev(obs) == before_rev
    finally:
        finish(sup, obs)


def test_the_state_says_whether_the_flow_is_migrated(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        assert dialog(obs, "open")["ok"]
        st = dialog_state(obs)
        assert st["migrated"] is ("strictTypes" not in flow_settings(obs)), (st, flow_settings(obs))
        assert dialog(obs, "cancel")["ok"]
    finally:
        finish(sup, obs)


def test_show_log_asks_the_supervisor_and_the_manager_opens_its_log_for_the_flow(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        assert dialog(obs, "open")["ok"]
        assert dialog(obs, "log")["ok"]
        assert wait_until(lambda: manager_state(obs)["log"]["open"] is True
                          and manager_state(obs)["log"]["flowId"] == FLOW, scaled(10)), manager_state(obs)["log"]
        assert dialog_state(obs)["open"] is True, "the dialog stays open after Show log"
        assert dialog(obs, "cancel")["ok"]
    finally:
        finish(sup, obs)
