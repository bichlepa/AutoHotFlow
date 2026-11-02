"""WI-0134: a demonstration flow opens read only in the editor (EditorModel.readOnly, EditorDraft.Commit, SaveView): the
edit is refused with demo_read_only and nothing reaches the engine, the status bar says that a duplicate can be changed.
Headless through cmd.test.* of the editor (EditorDriver); the look of the window is checked by the owner (manual check 12).
"""

from test_manager import wait_until
from test_manager_editor import finish, op, start_manager
from test_editor import editor_state, open_editor
from support.timing import scaled

DEMO = "Flow 806132298"            # Joke teller
EDITOR = "editor:" + DEMO
NEW = "element0000000010"


def add_action(eid):
    return {"op": "element.add", "element": {"ID": eid, "type": "action", "class": "Action_Sleep", "package": "Default",
                                             "packageVersion": "1.2.0", "x": 0, "y": 900, "name": "Added",
                                             "StandardName": "Sleep", "pars": {}}}


def engine_rev(obs):
    return obs.request("engine", "cmd.flow.get", {"flowId": DEMO}, timeout=scaled(5))["payload"]["rev"]


def test_a_demonstration_flow_opens_read_only_with_the_hint(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=DEMO)
        st = open_editor(obs, flow=DEMO)
        assert st["readOnly"] is True
        assert "duplicate" in st["status"].lower()
    finally:
        finish(sup, obs)


def test_an_edit_of_a_demonstration_flow_is_refused_and_the_engine_keeps_its_revision(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=DEMO)
        open_editor(obs, flow=DEMO)
        before = engine_rev(obs)
        ans = obs.request(EDITOR, "cmd.test.edit", {"ops": [add_action(NEW)]}, timeout=scaled(5))
        assert ans["payload"]["ok"] is False
        assert ans["payload"]["error"]["code"] == "demo_read_only", ans
        assert wait_until(lambda: (editor_state(obs, EDITOR) or {}).get("pending", 1) == 0, scaled(5))
        assert engine_rev(obs) == before
        assert editor_state(obs, EDITOR)["elements"] == open_editor(obs, flow=DEMO)["elements"]
    finally:
        finish(sup, obs)
