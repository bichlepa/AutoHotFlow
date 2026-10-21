"""WI-0102, REQ-TRG-030, REQ-EXE-060, REQ-EDT-110 (editor part): the switch and the star of a trigger, the menu bar, the context
menus and the keys Ctrl+Z, Ctrl+Y and Ctrl+S (src/editor/EditorTriggers.ahk, EditorMenus.ahk, EditorPointer.ahk, EditorKeys.ahk,
FlowHitTest.ahk "mark"), headless under the real supervisor. The mouse goes through cmd.test.mouse (the same pointer methods as
the window), the menu items through cmd.test.command (the same actions as the click), the keys through cmd.test.key.

The canvas pixels come from the view of cmd.test.state: the centres of the marks are FlowGeometry.TriggerMarks (switch at 80 %
and 25 %, star at 15 % and 20 % of the element). The real menus and the real mouse are the gui test of the owner
(tests/fault/test_editor_menus_gui.py).
"""

import json
from pathlib import Path

from support.timing import scaled
from test_manager import FLOW, SKELETON_SRC, wait_until
from test_manager_editor import finish, op, start_manager
from test_editor import EDITOR, TRIGGER, editor_state, open_editor
from test_editor_draft import edit, engine_definition, settled, step

SECOND_TRIGGER = "element0000000009"    # a manual trigger that is not the default (write_second_trigger)
ACTION = "element0000000002"            # the action of the skeleton flow, at (0, 210)
ELEMENT_WIDTH = 140                     # FlowGeometry.ELEMENT_WIDTH
ELEMENT_HEIGHT = 105                    # FlowGeometry.ELEMENT_HEIGHT


def write_second_trigger(datadir):
    """The skeleton with a second manual trigger, not the default, 600 flow units below the first one."""
    data = json.loads(SKELETON_SRC.read_text(encoding="utf-8"))
    other = dict(data["allElements"][TRIGGER])
    other.pop("DefaultTrigger", None)
    other.update({"ID": SECOND_TRIGGER, "name": "Manual - second", "x": 0, "y": 600})
    data["allElements"][SECOND_TRIGGER] = other
    flows = Path(datadir) / "Flows"
    flows.mkdir(exist_ok=True)
    (flows / (FLOW + ".json")).write_text(json.dumps(data), encoding="utf-8")


def canvas_of(st, fx, fy):
    """The canvas pixel of a flow point, from the view of the state (EditorView.ToCanvas: scale zoom * dpi / 96)."""
    view = st["view"]
    scale = view["zoom"] * view["dpi"] / 96
    return round((fx - view["offsetX"]) * scale), round((fy - view["offsetY"]) * scale)


def mark_pixel(st, x, y, mark):
    """The canvas pixel of the centre of the switch or the star of a trigger at the flow point (x, y)."""
    if mark == "switch":
        return canvas_of(st, x + ELEMENT_WIDTH * 0.8, y + ELEMENT_HEIGHT * 0.25)
    return canvas_of(st, x + ELEMENT_WIDTH * 0.15, y + ELEMENT_HEIGHT * 0.2)


def mouse(obs, button, action, x, y, name=EDITOR):
    ans = obs.request(name, "cmd.test.mouse", {"button": button, "action": action, "x": x, "y": y}, timeout=scaled(5))
    assert ans["payload"]["ok"], ans
    return ans["payload"]


def click(obs, x, y, name=EDITOR):
    """A left click as the window gets it: a button down and up at the canvas pixel."""
    mouse(obs, "left", "down", x, y, name)
    return mouse(obs, "left", "up", x, y, name)


def right_click(obs, x, y, name=EDITOR):
    mouse(obs, "right", "down", x, y, name)
    mouse(obs, "right", "up", x, y, name)


def element_x(obs):
    """The x of the action in the engine: the engine keeps a position as it was written (a text or a number)."""
    return float(engine_definition(obs)["allElements"][ACTION]["x"])


def is_default(element):
    """DefaultTrigger as the engine keeps it: the number 1 (a patch) or the text "1" (the skeleton file)."""
    return str(element.get("DefaultTrigger", "")).lower() in ("1", "true")


def trigger_state(obs, element=TRIGGER):
    return ((editor_state(obs) or {}).get("triggers") or {}).get(element, {})


def menus(obs, name=EDITOR):
    return (editor_state(obs, name) or {}).get("menus", {})


def bar_items(obs):
    """The entries of the menu bar by ID."""
    return {entry["id"]: entry for entry in menus(obs)["bar"]}


def edit_items(obs):
    """The items of the Edit menu by ID."""
    return {item["id"]: item for item in bar_items(obs)["edit"]["items"]}


def context_items(obs):
    return {entry["id"]: entry for entry in menus(obs).get("context", [])}


def command(obs, item, name=EDITOR, answer="no"):
    ans = obs.request(name, "cmd.test.command", {"item": item, "answer": answer}, timeout=scaled(5))
    assert ans["payload"]["ok"], ans
    return ans["payload"]


def test_a_click_on_the_switch_of_a_trigger_switches_it_and_selects_nothing(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        st = open_editor(obs)
        assert wait_until(lambda: TRIGGER in ((editor_state(obs) or {}).get("triggers") or {}), scaled(10)), editor_state(obs)
        before = trigger_state(obs)["enabled"]
        px, py = mark_pixel(st, 0, 0, "switch")
        payload = click(obs, px, py)
        assert payload["selection"] == [] and payload["pointer"] == "", payload      # a mark starts nothing
        assert wait_until(lambda: trigger_state(obs)["enabled"] is (not before), scaled(10)), editor_state(obs)
        assert editor_state(obs)["selection"] == [], editor_state(obs)
        assert editor_state(obs)["undo"] == st["undo"], "a switch is no undo step"
        click(obs, px, py)
        assert wait_until(lambda: trigger_state(obs)["enabled"] is before, scaled(10)), editor_state(obs)
    finally:
        finish(sup, obs)


def test_a_click_on_the_star_of_another_manual_trigger_makes_it_the_default_as_one_undo_step(
        procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, prepare=write_second_trigger)
    try:
        op(obs, "select", flowId=FLOW)
        st = open_editor(obs)
        assert wait_until(lambda: SECOND_TRIGGER in ((editor_state(obs) or {}).get("triggers") or {}), scaled(10)), \
            editor_state(obs)
        undo_before = editor_state(obs)["undo"]
        px, py = mark_pixel(st, 0, 600, "star")
        click(obs, px, py)
        assert wait_until(lambda: settled(obs) and editor_state(obs)["undo"] == undo_before + 1, scaled(10)), \
            editor_state(obs)
        definition = engine_definition(obs)
        assert is_default(definition["allElements"][SECOND_TRIGGER]), definition["allElements"]
        assert not is_default(definition["allElements"][TRIGGER]), "the engine clears the old default"
        step(obs, "undo")
        assert wait_until(lambda: settled(obs) and editor_state(obs)["undo"] == undo_before, scaled(10)), editor_state(obs)
        definition = engine_definition(obs)
        assert is_default(definition["allElements"][TRIGGER]), "undo gives the old default back"
        assert not is_default(definition["allElements"][SECOND_TRIGGER])
    finally:
        finish(sup, obs)


def test_a_click_on_the_star_of_the_default_trigger_changes_nothing(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        st = open_editor(obs)
        rev = editor_state(obs)["rev"]
        px, py = mark_pixel(st, 0, 0, "star")
        click(obs, px, py)
        assert settled(obs), editor_state(obs)
        assert editor_state(obs)["undo"] == st["undo"], "no undo step for the star of the default"
        assert editor_state(obs)["rev"] == rev, "no patch was sent"
    finally:
        finish(sup, obs)


def test_the_menu_bar_has_the_v1_entries_and_their_states(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        assert [e["id"] for e in menus(obs)["bar"]] == ["save", "run", "stop", "toggle", "edit", "settings", "exit"]
        bar = bar_items(obs)
        assert bar["settings"]["enabled"] is True, "the flow settings dialog opens from this entry (WI-0109)"
        assert bar["stop"]["enabled"] is False, "nothing runs"
        assert bar["toggle"]["label"] == "Enable", bar           # the skeleton flow starts disabled
        items = edit_items(obs)
        assert items["undo"]["enabled"] is False and items["redo"]["enabled"] is False, items
        assert items["cut"]["enabled"] is False and items["delete"]["enabled"] is False, "nothing is selected"
        assert items["selectAll"]["enabled"] is True, items
    finally:
        finish(sup, obs)


def test_the_menu_items_run_the_actions_and_a_disabled_one_runs_nothing(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        assert command(obs, "undo")["ran"] == 0, "undo is disabled without a step"
        assert command(obs, "settings")["ran"] == 1, "settings open the flow settings (WI-0109)"
        obs.request("editor:" + FLOW, "cmd.test.flowsettings", {"action": "cancel"}, timeout=scaled(5))
        edit(obs, [{"op": "element.update", "id": ACTION, "fields": {"x": 100}}])
        assert wait_until(lambda: settled(obs) and edit_items(obs)["undo"]["enabled"] is True, scaled(10)), menus(obs)
        assert command(obs, "undo")["ran"] == 1
        assert wait_until(lambda: settled(obs) and element_x(obs) == 0, scaled(10)), \
            engine_definition(obs)
        assert wait_until(lambda: edit_items(obs)["redo"]["enabled"] is True, scaled(10)), menus(obs)
        assert command(obs, "redo")["ran"] == 1
        assert wait_until(lambda: settled(obs) and element_x(obs) == 100, scaled(10)), \
            engine_definition(obs)
    finally:
        finish(sup, obs)


def test_ctrl_z_ctrl_y_and_ctrl_s_are_the_undo_redo_and_save_of_the_keys(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        edit(obs, [{"op": "element.update", "id": ACTION, "fields": {"x": 100}}])
        assert wait_until(lambda: settled(obs), scaled(10)), editor_state(obs)
        ans = obs.request(EDITOR, "cmd.test.key", {"key": "Z", "ctrl": True}, timeout=scaled(5))
        assert ans["payload"]["handled"] is True, ans
        assert wait_until(lambda: settled(obs) and element_x(obs) == 0, scaled(10)), engine_definition(obs)
        ans = obs.request(EDITOR, "cmd.test.key", {"key": "Y", "ctrl": True}, timeout=scaled(5))
        assert ans["payload"]["handled"] is True, ans
        assert wait_until(lambda: settled(obs) and element_x(obs) == 100, scaled(10)), \
            engine_definition(obs)
        ans = obs.request(EDITOR, "cmd.test.key", {"key": "S", "ctrl": True}, timeout=scaled(5))
        assert ans["payload"]["handled"] is True, ans
    finally:
        finish(sup, obs)


def test_a_right_click_on_an_element_selects_it_and_offers_its_actions(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        st = open_editor(obs)
        px, py = canvas_of(st, 70, 260)                      # inside the action (0, 210)
        right_click(obs, px, py)
        assert editor_state(obs)["selection"] == [ACTION], "the element under the right click is selected"
        items = context_items(obs)
        assert items["edit"]["enabled"] is True, "the element settings open from this entry (WI-0106)"
        assert items["cut"]["enabled"] and items["copy"]["enabled"] and items["delete"]["enabled"], items
        assert "toggleTrigger" not in items, "an action has no switch"
        assert command(obs, "ctx:copy")["ran"] == 1
    finally:
        finish(sup, obs)


def test_a_right_click_on_a_trigger_offers_the_switch_and_the_default(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id, prepare=write_second_trigger)
    try:
        op(obs, "select", flowId=FLOW)
        st = open_editor(obs)
        assert wait_until(lambda: SECOND_TRIGGER in ((editor_state(obs) or {}).get("triggers") or {}), scaled(10)), \
            editor_state(obs)
        px, py = canvas_of(st, 70, 60)                       # the body of the default trigger (0, 0)
        right_click(obs, px, py)
        items = context_items(obs)
        assert "toggleTrigger" in items, items
        assert items["setDefault"]["enabled"] is False, "the default trigger has no star action"
        px, py = canvas_of(st, 70, 660)                      # the body of the second manual trigger (0, 600)
        right_click(obs, px, py)
        items = context_items(obs)
        assert items["setDefault"]["enabled"] is True, items
        assert command(obs, "ctx:setDefault")["ran"] == 1
        assert wait_until(lambda: settled(obs) and is_default(engine_definition(obs)["allElements"][SECOND_TRIGGER]),
                          scaled(10)), engine_definition(obs)
    finally:
        finish(sup, obs)


def test_a_right_click_on_an_empty_place_offers_new_elements_at_that_place(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        st = open_editor(obs)
        px, py = canvas_of(st, 900, 900)                     # no element there
        right_click(obs, px, py)
        items = context_items(obs)
        for item in ("paste", "selectAll", "newAction", "newCondition", "newLoop", "newTrigger"):
            assert item in items, items
        assert command(obs, "ctx:newLoop")["ran"] == 1
        choice = editor_state(obs)["choice"]
        assert choice != "" and choice["kind"] == "loop", choice          # the class list of a loop is asked
        ans = obs.request(EDITOR, "cmd.test.class", {"id": ""}, timeout=scaled(5))      # cancel: nothing is added
        assert ans["payload"]["ok"], ans
        assert wait_until(lambda: editor_state(obs)["choice"] == "", scaled(5)), editor_state(obs)
    finally:
        finish(sup, obs)


def test_a_right_drag_moves_the_view_and_opens_no_menu(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    try:
        op(obs, "select", flowId=FLOW)
        st = open_editor(obs)
        px, py = canvas_of(st, 900, 900)
        mouse(obs, "right", "down", px, py)
        mouse(obs, "right", "move", px + 30, py + 30)
        mouse(obs, "right", "up", px + 30, py + 30)
        assert menus(obs).get("context", []) == [], "a drag is no click: no context menu"
        assert editor_state(obs)["view"]["offsetX"] != st["view"]["offsetX"], "the view moved"
    finally:
        finish(sup, obs)
