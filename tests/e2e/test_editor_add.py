"""WI-0099, REQ-EDT-050 (add elements), REQ-USE-010 (the class list follows the user's level), REQ-USE-020 (experimental
classes are marked; the Default package has none, so the mark is checked in tests/ahk/editor_new_element.test.ahk): a
field at the top left of the canvas starts the placing of a new element, the box follows the pointer, a click or a drag
places it, the class list opens and the answer adds the element as one patch (one undo step), Cancel adds nothing.

The mouse goes through cmd.test.mouse (the same pointer methods as the window), the list is answered with cmd.test.class and
read in cmd.test.state (choice). The four fields are at the canvas pixels of their centres at 96 DPI (NewElementFields: 100 by
75 pixels, lefts 10, 130, 250, 370 and top 7.5; the centre of a field is left + 50, 45).

The skeleton flow: the trigger (manual, the default) at (0, 0), two actions below it, two connections. A new element is placed
with its centre at the pointer and snapped to the grid of 35 (FlowGeometry.CentredOrigin).

Deterministic: a test waits for a condition of the editor or of the engine (wait_until), never for a fixed time.
"""

import pytest

from support.timing import scaled
from test_manager import FLOW, wait_until
from test_manager_editor import finish, op, start_manager
from test_editor import editor_state, open_editor, render
from test_editor_draft import engine_definition, settled, step

EDITOR = "editor:" + FLOW
FIELD = {"action": (60, 45), "condition": (180, 45), "loop": (300, 45), "trigger": (420, 45)}
TARGET = (400, 300)                    # a flow point where the new elements go (the origin snaps to (315, 245))
TARGET_ORIGIN = (315, 245)
TRIGGER = "element0000000001"
ACTION = "element0000000002"
LAST = "element0000000003"


def start(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    op(obs, "select", flowId=FLOW)
    open_editor(obs)
    render(obs)                        # the canvas takes its size; the view is the one of the flow
    return sup, obs


def mouse(obs, action, x, y, button="left"):
    ans = obs.request(EDITOR, "cmd.test.mouse", {"button": button, "action": action, "x": x, "y": y}, timeout=scaled(5))
    assert ans["payload"]["ok"], ans["payload"]
    return ans["payload"]


def canvas(obs, fx, fy):
    """The canvas pixel of a flow point in the current view (zoom and DPI of the editor, as the window computes it)."""
    v = editor_state(obs, EDITOR)["view"]
    s = v["zoom"] * v["dpi"] / 96
    return round((fx - v["offsetX"]) * s), round((fy - v["offsetY"]) * s)


def answer(obs, class_id):
    ans = obs.request(EDITOR, "cmd.test.class", {"id": class_id}, timeout=scaled(5))
    return ans["payload"]


def choice(obs):
    return editor_state(obs, EDITOR)["choice"]


def offered(obs):
    return [item["id"] for item in choice(obs)["items"]]


def wait_settled(obs):
    assert wait_until(lambda: settled(obs), scaled(10)), editor_state(obs, EDITOR)


def place(obs, kind, target=TARGET):
    """Clicks the field of the kind, moves to the target and clicks there: the class list opens."""
    x, y = FIELD[kind]
    mouse(obs, "down", x, y)
    mouse(obs, "up", x, y)
    assert editor_state(obs, EDITOR)["pointer"] == "place", editor_state(obs, EDITOR)
    tx, ty = canvas(obs, *target)
    mouse(obs, "move", tx, ty)
    mouse(obs, "down", tx, ty)
    mouse(obs, "up", tx, ty)
    assert choice(obs) not in ("", None), editor_state(obs, EDITOR)


def new_ids(obs, before):
    return [eid for eid in engine_definition(obs)["allElements"] if eid not in before]


def elements_now(obs):
    return set(engine_definition(obs)["allElements"])


def test_a_field_click_places_the_box_that_follows_the_pointer_until_the_next_click(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = elements_now(obs)
        x, y = FIELD["action"]
        mouse(obs, "down", x, y)
        mouse(obs, "up", x, y)
        st = editor_state(obs, EDITOR)
        assert st["pointer"] == "place", st
        assert st["choice"] == "", "nothing is asked before the placing is done"
        assert st["ghost"]["w"] == 140 and st["ghost"]["h"] == 105, st["ghost"]
        tx, ty = canvas(obs, *TARGET)
        mouse(obs, "move", tx, ty, button="none")
        ghost = editor_state(obs, EDITOR)["ghost"]
        assert (ghost["x"], ghost["y"]) == TARGET_ORIGIN, ghost
        assert editor_state(obs, EDITOR)["pointer"] == "place", "a move without a button keeps the placing"
        mouse(obs, "down", tx, ty)
        mouse(obs, "up", tx, ty)
        st = editor_state(obs, EDITOR)
        assert st["pointer"] == "" and st["ghost"] == "", st
        assert st["choice"]["kind"] == "action", st["choice"]
        assert elements_now(obs) == before, "nothing is added before the class is chosen"
    finally:
        finish(sup, obs)


def test_a_drag_from_a_field_places_the_element_where_the_button_goes_up(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        x, y = FIELD["condition"]
        mouse(obs, "down", x, y)
        for i in range(1, 4):
            mx, my = canvas(obs, 200 + 40 * i, 200 + 30 * i)
            mouse(obs, "move", mx, my)
        assert editor_state(obs, EDITOR)["pointer"] == "place", "the drag is still placing"
        ux, uy = canvas(obs, *TARGET)
        mouse(obs, "up", ux, uy)
        st = editor_state(obs, EDITOR)
        assert st["pointer"] == "" and st["choice"]["kind"] == "condition", st
    finally:
        finish(sup, obs)


def test_the_list_offers_the_classes_of_the_kind_at_the_user_level(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        place(obs, "action")
        ids = offered(obs)
        assert "Default.Action_Sleep" in ids, ids
        assert "Default.Action_Do_nothing" in ids, ids
        assert all(i.startswith("Default.Action_") for i in ids), ids
        assert "Default.Action_Trace_Point" not in ids, "Programmer classes are not shown at the Beginner level"
        assert answer(obs, "")["ok"]
        wait_settled(obs)
        assert choice(obs) == "", choice(obs)
    finally:
        finish(sup, obs)


def test_the_programmer_level_shows_the_programmer_classes(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        ans = obs.request("engine", "cmd.settings.set", {"settings": {"userLevel": "Programmer"}}, timeout=scaled(5))
        assert ans["payload"]["ok"], ans

        def list_shows_the_programmer_class():
            # the editor takes the setting from its event: the list is asked until the event has come
            place(obs, "action")
            shown = "Default.Action_Trace_Point" in offered(obs)
            answer(obs, "")
            wait_settled(obs)
            return shown

        assert wait_until(list_shows_the_programmer_class, scaled(10)), "the Programmer class is not shown"
    finally:
        finish(sup, obs)


def test_the_answer_adds_the_element_at_the_placed_place_with_its_defaults_and_selects_it(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = elements_now(obs)
        place(obs, "action")
        assert answer(obs, "Default.Action_Sleep")["ok"]
        wait_settled(obs)
        added = new_ids(obs, before)
        assert len(added) == 1, added
        el = engine_definition(obs)["allElements"][added[0]]
        assert (float(el["x"]), float(el["y"])) == TARGET_ORIGIN, el
        assert el["type"] == "action" and el["class"] == "Action_Sleep" and el["package"] == "Default", el
        assert el["name"] == "Sleep: 2 s", el
        assert el["pars"]["Duration"] in (2, "2"), el
        assert set(editor_state(obs, EDITOR)["selection"]) == {added[0]}, "the new element is selected"
    finally:
        finish(sup, obs)


def test_undo_takes_the_new_element_back_in_one_step(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = elements_now(obs)
        place(obs, "loop")
        assert answer(obs, "Default.Loop_SimpleLoop")["ok"]
        wait_settled(obs)
        added = new_ids(obs, before)
        assert len(added) == 1, added
        assert engine_definition(obs)["allElements"][added[0]]["HeightOfVerticalBar"] == 150, "a loop has the bar of 150"
        assert step(obs, "undo")["done"], "the new element is one undo step"
        wait_settled(obs)
        assert elements_now(obs) == before, "one undo step removes the whole element"
    finally:
        finish(sup, obs)


def test_a_manual_trigger_is_no_default_when_the_flow_has_one(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = elements_now(obs)
        place(obs, "trigger")
        assert "Default.Trigger_Manual" in offered(obs)
        assert answer(obs, "Default.Trigger_Manual")["ok"]
        wait_settled(obs)
        added = new_ids(obs, before)
        assert len(added) == 1, added
        el = engine_definition(obs)["allElements"][added[0]]
        assert el["type"] == "trigger", el
        assert not el.get("DefaultTrigger"), "the flow has a default manual trigger already: %s" % el
        assert engine_definition(obs)["allElements"][TRIGGER]["DefaultTrigger"] in (1, "1", True)
    finally:
        finish(sup, obs)


def test_escape_and_the_right_button_cancel_the_placing_and_add_nothing(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        rev = editor_state(obs, EDITOR)["rev"]
        before = elements_now(obs)
        x, y = FIELD["action"]
        mouse(obs, "down", x, y)
        mouse(obs, "up", x, y)
        assert editor_state(obs, EDITOR)["pointer"] == "place"
        ans = obs.request(EDITOR, "cmd.test.key", {"key": "Esc"}, timeout=scaled(5))
        assert ans["payload"]["handled"] is True, ans
        st = editor_state(obs, EDITOR)
        assert st["pointer"] == "" and st["ghost"] == "" and st["choice"] == "", st
        mouse(obs, "down", x, y)
        mouse(obs, "up", x, y)
        mouse(obs, "down", *canvas(obs, *TARGET), button="right")
        st = editor_state(obs, EDITOR)
        assert st["pointer"] == "" and st["choice"] == "", st
        assert elements_now(obs) == before
        assert editor_state(obs, EDITOR)["rev"] == rev, "no change of the flow"
    finally:
        finish(sup, obs)


def test_a_cancelled_list_adds_nothing_and_a_new_placing_works_after_it(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        rev = editor_state(obs, EDITOR)["rev"]
        before = elements_now(obs)
        place(obs, "action")
        assert answer(obs, "")["ok"]
        wait_settled(obs)
        assert elements_now(obs) == before, "a cancelled list adds nothing"
        assert editor_state(obs, EDITOR)["rev"] == rev
        place(obs, "condition")
        assert editor_state(obs, EDITOR)["choice"]["kind"] == "condition", "the list is open again"
        assert answer(obs, "Default.Condition_Expression")["ok"]
        wait_settled(obs)
        assert len(new_ids(obs, before)) == 1
    finally:
        finish(sup, obs)


def test_a_class_that_the_list_does_not_offer_is_refused(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        place(obs, "action")
        payload = answer(obs, "Default.Condition_Expression")
        assert payload["ok"] is False and payload["error"]["code"] == "bad_payload", payload
        assert choice(obs)["kind"] == "action", "the list stays open"
        answer(obs, "")
    finally:
        finish(sup, obs)
