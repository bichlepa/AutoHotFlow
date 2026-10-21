"""WI-0107, REQ-TRG-050 (editor part), REQ-ELM-010, REQ-TRG-030 (the force question of the switch, E0101): the other flows in the
element settings and the switch "Switch with the flow" of a trigger (E0056), under the real supervisor, headless.

The flow ACTION of the skeleton becomes the element of the class under test; a second flow "other" (name "Other flow") has
two manual triggers and one start-up trigger (not manual), so the lists show the manual ones only where v1 did.
The lists of the other flow come from the engine (cmd.flow.triggers, EditorFlowCatalog): a test waits until the answer
has reached the form (the list shows the IDs before that, it does not wait).

The window is answered through cmd.test.form (the calls of the window on EditorSettings), as in test_editor_settings.py.
The gui is tested by the owner (tests/fault, gui tier), not here.
"""

import json
from pathlib import Path

import pytest

from support.timing import scaled
from test_manager import FLOW, SKELETON_SRC, wait_until
from test_manager_editor import finish, op, start_manager
from test_editor import editor_state, open_editor
from test_editor_draft import engine_definition
from test_editor_settings import EDITOR, TRIGGER, ACTION, form, form_state, field_of, wait_settled
from test_editor_menus import canvas_of, click, command, mark_pixel, right_click, trigger_state
from test_manager_flows import _lock_state_file, LOCKS

OTHER = "other"
OTHER_MANUAL = "oth0000000001"
OTHER_SECOND = "oth0000000002"
OTHER_START = "oth0000000003"
OTHER_NAME = "Other flow"

# class, package, type, the stored parameters of the element (the flow "other" is chosen), the ids of the trigger list
# that the class shows (manual ones only where v1 listed manual triggers), the ids that it must not show
CASES = {
    "execute": ("Action_Execute_Flow", "action",
                {"ThisFlow": 0, "flowID": OTHER, "WhichTrigger": "Default", "triggerID": ""},
                [OTHER_MANUAL, OTHER_SECOND], [OTHER_START]),
    "stop": ("Action_Stop_Flow", "action", {"flowID": OTHER}, [], []),
    "running": ("Condition_Flow_Running", "condition", {"flowID": OTHER}, [], []),
    "set_status": ("Action_Set_Flow_Status", "action",
                   {"Enable": "Enable", "ThisFlow": 0, "flowID": OTHER, "WhichTrigger": "Any", "triggerID": ""},
                   [OTHER_MANUAL, OTHER_START], []),
    "enabled": ("Condition_Flow_Enabled", "condition",
                {"ThisFlow": 0, "flowID": OTHER, "WhichTrigger": "Any", "triggerID": ""},
                [OTHER_MANUAL, OTHER_START], []),
}


def write_other_flow(datadir):
    """The flow "other": a default manual trigger, a second manual trigger and a start-up trigger, nothing else."""
    elements = {
        OTHER_MANUAL: {"class": "Trigger_Manual", "package": "Default", "type": "trigger", "name": "Start the other",
                       "DefaultTrigger": "1", "enabled": "0", "ID": OTHER_MANUAL, "pars": {"ID": "OtherDefault"},
                       "StandardName": "1", "packageVersion": "1.2.0", "x": "0", "y": "0"},
        OTHER_SECOND: {"class": "Trigger_Manual", "package": "Default", "type": "trigger", "name": "Second start",
                       "enabled": "0", "ID": OTHER_SECOND, "pars": {"ID": "OtherSecond"}, "StandardName": "1",
                       "packageVersion": "1.2.0", "x": "0", "y": "200"},
        OTHER_START: {"class": "Trigger_Start_up", "package": "Default", "type": "trigger", "name": "At start",
                      "enabled": "0", "ID": OTHER_START, "pars": {}, "StandardName": "1",
                      "packageVersion": "1.2.0", "x": "0", "y": "400"},
    }
    data = {"name": OTHER_NAME, "category": "", "ElementIDCounter": 3,
            "flowSettings": {}, "allElements": elements, "allConnections": {}}
    flows = Path(datadir) / "Flows"
    flows.mkdir(exist_ok=True)
    (flows / (OTHER + ".json")).write_text(json.dumps(data), encoding="utf-8")


def prepare_class(kind, datadir):
    """The skeleton with the action ACTION of the class under test, and the flow "other"."""
    cls, package_type, stored, _, _ = CASES[kind]
    data = json.loads(SKELETON_SRC.read_text(encoding="utf-8"))
    data["allElements"][ACTION] = {"class": cls, "package": "Default", "packageVersion": "1.2.0", "ID": ACTION,
                                   "name": "The element", "type": package_type, "pars": dict(stored),
                                   "StandardName": "1", "x": "0", "y": "210"}
    flows = Path(datadir) / "Flows"
    flows.mkdir(exist_ok=True)
    (flows / (FLOW + ".json")).write_text(json.dumps(data), encoding="utf-8")
    write_other_flow(datadir)


def ids_in(choices_field):
    return set(choices_field.get("values", []))


def wait_choices(obs, parameter, wanted):
    """Waits until the choices of the field hold the wanted values (the answer of the engine reached the form)."""
    def ready():
        try:
            return set(wanted) <= ids_in(field_of(obs, parameter))
        except AssertionError:
            return False
    assert wait_until(ready, scaled(10)), (parameter, form_state(obs))


@pytest.mark.parametrize("kind", sorted(CASES))
def test_the_settings_list_the_flows_and_the_triggers_of_another_flow_with_their_names(kind, procs, datadir, session_id):
    cls, _, _, manual, absent = CASES[kind]
    sup, obs = start_manager(procs, datadir, session_id, prepare=lambda d: prepare_class(kind, d))
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        assert form(obs, "open", id=ACTION)["ok"]
        st = form_state(obs)
        assert st["classId"] == "Default." + cls, st
        # the flow list: the other flow with its name, the own flow too (the IDs are what the engine knows)
        wait_choices(obs, "flowID", [OTHER])
        flow_field = field_of(obs, "flowID")
        assert OTHER in flow_field["values"] and FLOW in flow_field["values"], flow_field
        assert "%s: %s" % (OTHER, OTHER_NAME) in flow_field["choices"], flow_field
        if manual:
            wait_choices(obs, "triggerID", manual)
            trigger_field = field_of(obs, "triggerID")
            for trigger in manual:
                assert trigger in trigger_field["values"], trigger_field
            for trigger in absent:
                assert trigger not in trigger_field["values"], trigger_field
            assert "%s: Start the other" % OTHER_MANUAL in trigger_field["choices"], trigger_field
        # the standard name carries the name of the other flow (v1 showed the name, not the ID)
        assert OTHER_NAME in form_state(obs)["name"], form_state(obs)
    finally:
        finish(sup, obs)


def test_a_trigger_dialog_has_switch_with_the_flow_and_it_is_written_as_the_key_of_the_element(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        assert form(obs, "open", id=TRIGGER)["ok"]
        field = field_of(obs, "followsFlow")
        assert field["label"] == "Switch with the flow" and field["type"] == "checkbox", field
        assert field["value"] == 1, field          # a missing key is on (E0056)
        assert form(obs, "set", id="followsFlow", value=0)["ok"]
        assert form(obs, "ok")["changed"] is True
        def stored_off():
            value = engine_definition(obs)["allElements"][TRIGGER].get("followsFlow", "missing")
            return value in (False, 0, "0", "false")       # the engine keeps JSON false as 0 on the wire; both are off
        assert wait_until(stored_off, scaled(10)), engine_definition(obs)["allElements"][TRIGGER]
        wait_settled(obs)
        assert "followsFlow" not in engine_definition(obs)["allElements"][TRIGGER]["pars"]
        # opened again, the checkbox shows the stored value
        assert form(obs, "open", id=TRIGGER)["ok"]
        assert field_of(obs, "followsFlow")["value"] == 0
        assert form(obs, "cancel")["ok"]
    finally:
        finish(sup, obs)


def test_an_action_has_no_switch_with_the_flow(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        assert form(obs, "open", id=ACTION)["ok"]
        assert all("followsFlow" not in item["ids"] for item in form_state(obs)["fields"])
    finally:
        finish(sup, obs)


def asked(obs):
    return (editor_state(obs, EDITOR) or {}).get("asked", [])


def test_a_switch_of_a_trigger_whose_state_cannot_be_read_asks_the_force_question_no_changes_nothing_yes_writes_it(
        procs, datadir, session_id):
    """E0101: the trigger switch asks the question of the flow commands (E0087). The mark and the context menu switch the
    trigger with the same answers (the driver answers the question; the default answer is no)."""
    sup, obs = start_manager(procs, datadir, session_id, prepare=_lock_state_file())
    try:
        op(obs, "select", flowId=FLOW)
        st = open_editor(obs)
        assert wait_until(lambda: TRIGGER in ((editor_state(obs, EDITOR) or {}).get("triggers") or {}), scaled(10)), \
            editor_state(obs, EDITOR)
        before = trigger_state(obs)["enabled"]
        px, py = mark_pixel(st, 0, 0, "switch")
        click(obs, px, py)
        assert wait_until(lambda: asked(obs) == ["force"], scaled(10)), editor_state(obs, EDITOR)
        assert trigger_state(obs)["enabled"] is before, "no: nothing changes"
        cx, cy = canvas_of(st, 70, 60)
        right_click(obs, cx, cy)
        command(obs, "ctx:toggleTrigger", answer="yes")
        assert wait_until(lambda: trigger_state(obs)["enabled"] is (not before), scaled(10)), editor_state(obs, EDITOR)
        assert asked(obs) == ["force", "force"], asked(obs)
    finally:
        finish(sup, obs)
        import ctypes
        kernel = ctypes.WinDLL("kernel32")
        for handle in LOCKS:
            kernel.CloseHandle(handle)
        LOCKS.clear()
