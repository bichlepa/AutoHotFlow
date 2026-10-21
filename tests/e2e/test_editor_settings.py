"""WI-0106, REQ-EDT-120 (the settings of an element), REQ-MIG-070 (the migration places and an unknown class in the settings),
REQ-USE-020 (the note of an experimental class), REQ-USE-090 (the dialog): the settings window of an element under the real
supervisor, headless. The window is answered through cmd.test.form (the same calls as the window makes on EditorSettings).
The gui of the window is checked by tests/fault/test_editor_settings_gui.py (owner).

The opening by the mouse (a double click, the edit button, the context menu) goes through cmd.test.mouse and cmd.test.command,
the same pointer methods as the window. The flow is the skeleton of test_editor_select: the action ACTION is Action_Sleep
with the parameter Duration, the trigger TRIGGER is the default manual trigger.

Deterministic: a test waits for a condition of the editor or of the engine (wait_until), never for a fixed time.
"""

import test_editor_select as sel
from support.timing import scaled
from test_manager import FLOW, wait_until
from test_manager_editor import finish
from test_editor import editor_state
from test_editor_draft import engine_definition, settled, step

EDITOR = "editor:" + FLOW
TRIGGER = "element0000000001"
ACTION = "element0000000002"
NEW = "element0000000010"
UNKNOWN = "element0000000011"


def form(obs, action, **payload):
    """cmd.test.form: the answer's payload (ok, changed or error)."""
    ans = obs.request(EDITOR, "cmd.test.form", dict(action=action, **payload), timeout=scaled(5))
    return ans["payload"]


def form_state(obs):
    return editor_state(obs, EDITOR)["form"]


def field_of(obs, parameter):
    for item in form_state(obs)["fields"]:
        if parameter in item["ids"]:
            return item
    raise AssertionError("no field of %s in %s" % (parameter, form_state(obs)))


def rev(obs):
    return editor_state(obs, EDITOR)["rev"]


def wait_settled(obs):
    assert wait_until(lambda: settled(obs), scaled(10)), editor_state(obs, EDITOR)


def element(obs, eid):
    return engine_definition(obs)["allElements"][eid]


def elements_now(obs):
    return set(engine_definition(obs)["allElements"])


def select_alone(obs, eid):
    """Selects the element alone (cmd.test.select: no click, so no double click is counted) and returns the editor state."""
    ans = obs.request(EDITOR, "cmd.test.select", {"mode": "one", "ids": [eid]}, timeout=scaled(5))
    assert ans["payload"]["ok"], ans
    return editor_state(obs, EDITOR)


def sel_point(obs, eid):
    """A flow point inside the element (the skeleton places its actions at x 0 and the top left of the box is its origin)."""
    el = engine_definition(obs)["allElements"][eid]
    return float(el["x"]) + 60, float(el["y"]) + 40


def start(procs, datadir, session_id):
    return sel.start(procs, datadir, session_id)


def place_action(obs):
    """Clicks the action field and then the empty place (400, 300): the class list opens (WI-0099)."""
    sel.mouse(obs, "down", 60, 45)
    sel.mouse(obs, "up", 60, 45)
    tx, ty = sel.canvas(obs, 400, 300)
    sel.mouse(obs, "move", tx, ty)
    sel.mouse(obs, "down", tx, ty)
    sel.mouse(obs, "up", tx, ty)


def test_the_settings_of_an_element_show_its_fields_and_one_change_is_one_patch_and_one_undo_step(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        assert form(obs, "open", id=ACTION)["ok"]
        st = form_state(obs)
        assert st["mode"] == "edit" and st["id"] == ACTION and st["classId"] == "Default.Action_Sleep", st
        assert st["changed"] is not True and st["unknown"] is not True, st
        duration = field_of(obs, "Duration")
        assert duration["type"] == "edit" and duration["enabled"] is True, duration
        before = rev(obs)
        original = str(element(obs, ACTION)["pars"]["Duration"])
        assert form(obs, "set", id="Duration", value="7")["ok"]
        assert form_state(obs)["changed"] is True
        assert form(obs, "ok")["changed"] is True
        assert wait_until(lambda: rev(obs) > before and settled(obs), scaled(10)), editor_state(obs, EDITOR)
        assert str(element(obs, ACTION)["pars"]["Duration"]) == "7", element(obs, ACTION)
        assert editor_state(obs, EDITOR)["form"]["open"] is False, "the window closes after OK"
        assert step(obs, "undo", EDITOR)["done"], "the change is one undo step"
        wait_settled(obs)
        assert str(element(obs, ACTION)["pars"]["Duration"]) == original, element(obs, ACTION)
    finally:
        finish(sup, obs)


def test_ok_without_a_change_sends_nothing(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = rev(obs)
        assert form(obs, "open", id=ACTION)["ok"]
        answer = form(obs, "ok")
        assert answer["ok"] is True and answer["changed"] is False, answer
        assert editor_state(obs, EDITOR)["form"]["open"] is False
        assert wait_until(lambda: settled(obs), scaled(10))
        assert rev(obs) == before, "nothing changed, nothing was sent"
    finally:
        finish(sup, obs)


def test_cancel_sends_nothing_and_keeps_the_value(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = rev(obs)
        original = str(element(obs, ACTION)["pars"]["Duration"])
        assert form(obs, "open", id=ACTION)["ok"]
        assert form(obs, "set", id="Duration", value="9")["ok"]
        assert form(obs, "cancel")["ok"]
        assert editor_state(obs, EDITOR)["form"]["open"] is False
        assert wait_until(lambda: settled(obs), scaled(10))
        assert rev(obs) == before
        assert str(element(obs, ACTION)["pars"]["Duration"]) == original
    finally:
        finish(sup, obs)


def test_the_name_goes_with_the_change_and_the_standard_name_regenerates_it(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        assert form(obs, "open", id=ACTION)["ok"]
        assert form(obs, "standardName", flag=1)["ok"]
        assert form(obs, "set", id="Duration", value="4")["ok"]
        assert form_state(obs)["name"] == "Sleep: 4 ms", form_state(obs)     # the skeleton's unit is milliseconds
        assert form(obs, "ok")["ok"]
        assert wait_until(lambda: settled(obs) and element(obs, ACTION)["name"] == "Sleep: 4 ms", scaled(10)), \
            element(obs, ACTION)
        assert element(obs, ACTION)["StandardName"] in (1, "1", True)
    finally:
        finish(sup, obs)


def test_a_second_settings_window_is_refused_while_one_is_open(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        assert form(obs, "open", id=ACTION)["ok"]
        refused = form(obs, "open", id=TRIGGER)
        assert refused["ok"] is False and refused["error"]["code"] == "busy", refused
        assert form_state(obs)["id"] == ACTION, "the first window stays"
        assert form(obs, "cancel")["ok"]
    finally:
        finish(sup, obs)


def test_a_double_click_on_an_element_and_its_edit_button_open_the_settings(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        x, y = sel.canvas(obs, *sel_point(obs, ACTION))
        sel.mouse(obs, "double", x, y)
        assert editor_state(obs, EDITOR)["form"]["open"] is True, "a double click opens the settings"
        assert form(obs, "cancel")["ok"]
        st = select_alone(obs, ACTION)
        edit = [b for b in st["buttons"] if b["name"] == "edit"]
        assert edit, st["buttons"]
        bx, by = sel.canvas(obs, edit[0]["x"], edit[0]["y"])
        sel.mouse(obs, "down", bx, by)
        sel.mouse(obs, "up", bx, by)
        assert editor_state(obs, EDITOR)["form"]["id"] == ACTION, "the edit button opens the settings"
        assert form(obs, "cancel")["ok"]
    finally:
        finish(sup, obs)


def test_the_context_menu_entry_edit_opens_the_settings_of_the_element(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        x, y = sel.canvas(obs, *sel_point(obs, ACTION))
        sel.mouse(obs, "down", x, y, button="right")
        sel.mouse(obs, "up", x, y, button="right")
        ans = obs.request(EDITOR, "cmd.test.command", {"item": "ctx:edit"}, timeout=scaled(5))
        assert ans["payload"]["ok"] and ans["payload"]["ran"] is True, ans
        assert editor_state(obs, EDITOR)["form"]["id"] == ACTION
        assert form(obs, "cancel")["ok"]
    finally:
        finish(sup, obs)


def test_an_unknown_class_shows_its_parameters_read_only_and_ok_changes_nothing(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        el = {"ID": UNKNOWN, "type": "action", "class": "Action_Not_Installed", "package": "Default",
              "packageVersion": "1.2.0", "x": 0, "y": 1200, "name": "Unknown", "StandardName": 0, "pars": {"Duration": "3"}}
        ans = obs.request(EDITOR, "cmd.test.edit", {"ops": [{"op": "element.add", "element": el}]}, timeout=scaled(5))
        assert ans["payload"]["ok"], ans
        wait_settled(obs)
        before = rev(obs)
        assert form(obs, "open", id=UNKNOWN)["ok"]
        st = form_state(obs)
        assert st["unknown"] is True and st["fields"] == [{"id": "Duration", "value": "3"}], st
        assert "Action_Not_Installed" in st["placeholder"], st
        assert form(obs, "ok")["changed"] is False
        assert wait_until(lambda: settled(obs), scaled(10))
        assert rev(obs) == before
    finally:
        finish(sup, obs)


def test_a_migration_place_is_shown_and_the_change_of_its_value_resolves_it(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        el = {"ID": NEW, "type": "action", "class": "Action_Sleep", "package": "Default", "packageVersion": "1.2.0",
              "x": 0, "y": 1200, "name": "Sleep", "StandardName": 0, "pars": {"Duration": "2"},
              "migration": [{"par": "Duration", "ids": ["M-0025"], "v1": "v1 text of the place"}]}
        ans = obs.request(EDITOR, "cmd.test.edit", {"ops": [{"op": "element.add", "element": el}]}, timeout=scaled(5))
        assert ans["payload"]["ok"], ans
        wait_settled(obs)
        assert form(obs, "open", id=NEW)["ok"]
        places = field_of(obs, "Duration")["migration"]
        assert places and places[0]["ids"] == ["M-0025"] and places[0]["v1"] == "v1 text of the place", places
        assert form(obs, "set", id="Duration", value="5")["ok"]
        assert form(obs, "ok")["changed"] is True
        assert wait_until(lambda: settled(obs) and not element(obs, NEW).get("migration"), scaled(10)), element(obs, NEW)
    finally:
        finish(sup, obs)


def test_a_new_element_gets_its_settings_before_it_is_added_and_ok_adds_it_with_them(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = elements_now(obs)
        place_action(obs)
        ans = obs.request(EDITOR, "cmd.test.class", {"id": "Default.Action_Sleep"}, timeout=scaled(5))
        assert ans["payload"]["ok"], ans
        st = form_state(obs)
        assert st["mode"] == "new" and st["classId"] == "Default.Action_Sleep", st
        assert elements_now(obs) == before, "the element is not added before its settings are answered"
        assert form(obs, "set", id="Duration", value="5")["ok"]
        assert form(obs, "ok")["ok"]
        assert wait_until(lambda: settled(obs) and elements_now(obs) - before, scaled(10)), engine_definition(obs)
        added = list(elements_now(obs) - before)
        assert len(added) == 1, added
        el = element(obs, added[0])
        assert str(el["pars"]["Duration"]) == "5" and el["name"] == "Sleep: 5 s", el
    finally:
        finish(sup, obs)


def test_cancel_of_a_new_element_adds_nothing(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = elements_now(obs)
        place_action(obs)
        assert obs.request(EDITOR, "cmd.test.class", {"id": "Default.Action_Sleep"}, timeout=scaled(5))["payload"]["ok"]
        assert form(obs, "cancel")["ok"]
        assert wait_until(lambda: settled(obs), scaled(10))
        assert elements_now(obs) == before, "a cancelled settings window adds nothing"
    finally:
        finish(sup, obs)
