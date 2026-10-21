"""WI-0098, REQ-EDT-060 (select and move), REQ-EDT-030 (the right button moves the view), E0094: the mouse and the keys of the
editor (src/editor/EditorPointer.ahk, EditorKeys.ahk) under the real supervisor, headless. The mouse goes through
cmd.test.mouse, which calls the same pointer methods as the window (down, move, up); the keys through cmd.test.key.

The flow is the skeleton (trigger at (0, 0), actions at (0, 210) and (0, 420), two connections). Without a zoom the canvas
pixel of a flow point is the flow point minus the offset, so the tests compute the pixels from the view of the editor.
Every change is checked in the engine's definition (cmd.flow.get) after the editor has sent its patch (settled).

Deterministic: a test waits for a condition of the editor or of the engine (wait_until), never for a fixed time, except the
2 s of the view save, which the test waits for with a margin.
"""

import pytest

from support.timing import scaled
from test_manager import FLOW, wait_until
from test_manager_editor import finish, op, start_manager
from test_editor import editor_state, open_editor, render, view_command
from test_editor_draft import edit, engine_definition, settled, step

EDITOR = "editor:" + FLOW
TRIGGER = "element0000000001"
ACTION = "element0000000002"
LAST = "element0000000003"
CONN_TA = "connection0000000004"       # trigger -> action
CONN_AL = "connection0000000005"       # action -> last
LOOP = "element0000000010"
ALL_IDS = {TRIGGER, ACTION, LAST, CONN_TA, CONN_AL}
EMPTY = (500, 500)                     # right of the flow, nothing there


def add_loop(eid, x, y, height):
    return {"op": "element.add", "element": {"ID": eid, "type": "loop", "class": "Loop_SimpleLoop", "package": "Default",
                                             "packageVersion": "1.2.0", "x": x, "y": y, "HeightOfVerticalBar": height,
                                             "name": "Loop", "StandardName": "Loop", "pars": {}}}


def start(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    op(obs, "select", flowId=FLOW)
    open_editor(obs)
    render(obs)                        # the canvas takes its size; the view is the one of the flow
    move_out_of_the_fields(obs)
    return sup, obs


def move_out_of_the_fields(obs):
    """The four fields for new elements lie over the top left corner of the canvas (WI-0099, NewElementFields: up to 480 by
    90 pixels at 96 DPI), so at the start view the top left flow elements are under them. The view moves 200 by 100 pixels
    (the content follows the drag) and the test waits for the view to be saved (a patch of the flow settings), so that no
    save comes during a test that checks the revision."""
    rev = editor_state(obs)["rev"]
    view_command(obs, drag={"dx": 200, "dy": 100})
    assert wait_until(lambda: editor_state(obs)["rev"] > rev, scaled(10)), "the view was not saved"


def mouse(obs, action, x, y, button="left", ctrl=False):
    ans = obs.request(EDITOR, "cmd.test.mouse", {"button": button, "action": action, "x": x, "y": y, "ctrl": ctrl},
                      timeout=scaled(5))
    assert ans["payload"]["ok"], ans
    return ans["payload"]


def canvas(obs, fx, fy):
    """The canvas pixel of a flow point in the current view (zoom and DPI of the editor, as the window computes it)."""
    v = editor_state(obs)["view"]
    s = v["zoom"] * v["dpi"] / 96
    return round((fx - v["offsetX"]) * s), round((fy - v["offsetY"]) * s)


def click(obs, flow_point, ctrl=False):
    x, y = canvas(obs, *flow_point)
    mouse(obs, "down", x, y, ctrl=ctrl)
    return mouse(obs, "up", x, y, ctrl=ctrl)


def drag(obs, start_point, end_point, steps=5, button="left", ctrl=False):
    """Presses at start_point, moves in steps to end_point, releases there (flow points)."""
    x0, y0 = canvas(obs, *start_point)
    x1, y1 = canvas(obs, *end_point)
    mouse(obs, "down", x0, y0, button=button, ctrl=ctrl)
    for i in range(1, steps + 1):
        mouse(obs, "move", x0 + (x1 - x0) * i // steps, y0 + (y1 - y0) * i // steps, button=button)
    return mouse(obs, "up", x1, y1, button=button)


def key(obs, name, ctrl=False):
    ans = obs.request(EDITOR, "cmd.test.key", {"key": name, "ctrl": ctrl}, timeout=scaled(5))
    assert ans["payload"]["ok"], ans
    return ans["payload"]


def selection(obs):
    return set(editor_state(obs)["selection"])


def definition_positions(obs):
    d = engine_definition(obs)["allElements"]
    # The skeleton flow keeps some positions as JSON texts ("0", "420", v1 style); float() compares them as numbers.
    return {eid: (float(d[eid]["x"]), float(d[eid]["y"])) for eid in (TRIGGER, ACTION, LAST)}


def wait_settled(obs):
    assert wait_until(lambda: settled(obs), scaled(10)), editor_state(obs)


def test_a_click_selects_one_element_and_an_empty_place_unselects_all(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        rev = editor_state(obs)["rev"]
        click(obs, (70, 52))
        assert selection(obs) == {TRIGGER}, editor_state(obs)["selection"]
        click(obs, (70, 262))
        assert selection(obs) == {ACTION}, "a click on another element replaces the selection"
        click(obs, (70, 472), ctrl=True)
        assert selection(obs) == {ACTION, LAST}, "Ctrl adds"
        click(obs, (70, 262), ctrl=True)
        assert selection(obs) == {LAST}, "Ctrl on a selected element removes it"
        click(obs, (70, 472))
        click(obs, (70, 262), ctrl=True)
        click(obs, (70, 472))
        assert selection(obs) == {LAST}, "a click on a selected element with others selected selects it alone"
        click(obs, EMPTY)
        assert selection(obs) == set(), "a click on an empty place unselects all"
        assert editor_state(obs)["rev"] == rev, "a click changes no flow"
    finally:
        finish(sup, obs)


def test_a_click_on_a_connection_selects_the_connection_alone(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        # the connection runs from (70, 157) down to the top of the second action at (70, 210) (its centre line)
        click(obs, (70, 185))
        assert selection(obs) == {CONN_TA}, editor_state(obs)["selection"]
    finally:
        finish(sup, obs)


def test_the_status_bar_names_the_selection(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        click(obs, (70, 52))
        status = editor_state(obs)["status"]
        assert "1 selected element: " + TRIGGER in status, status
        click(obs, (70, 262), ctrl=True)
        assert "2 selected elements" in editor_state(obs)["status"], editor_state(obs)["status"]
        click(obs, EMPTY)
        assert "3 elements" in editor_state(obs)["status"], editor_state(obs)["status"]
    finally:
        finish(sup, obs)


def test_ctrl_a_selects_every_element_and_connection_and_escape_unselects(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        ans = key(obs, "A", ctrl=True)
        assert ans["handled"] is True, ans
        assert selection(obs) == ALL_IDS, editor_state(obs)["selection"]
        key(obs, "Esc")
        assert selection(obs) == set(), "Esc unselects all when nothing is dragged"
        assert key(obs, "B")["handled"] is False, "a key the table does not have is not handled"
    finally:
        finish(sup, obs)


def test_a_rectangle_selects_the_elements_it_touches_and_the_connection_between_them(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        click(obs, (70, 472))                        # a selection that the rectangle replaces
        drag(obs, (200, 300), (-20, -20))            # touches the trigger (0..140, 0..105) and the action (210..315)
        assert selection(obs) == {TRIGGER, ACTION, CONN_TA}, editor_state(obs)["selection"]
        assert editor_state(obs)["pointer"] == "", "the drag has ended"
    finally:
        finish(sup, obs)


def test_ctrl_adds_the_rectangle_to_the_selection(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        click(obs, (70, 472))
        drag(obs, (200, 50), (120, -20), ctrl=True)     # touches the trigger (x 0 to 140, y 0 to 105), not the action
        assert selection(obs) == {LAST, TRIGGER}, editor_state(obs)["selection"]
    finally:
        finish(sup, obs)


def test_escape_cancels_a_rectangle_and_the_selection_goes_back_to_the_press(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        click(obs, (70, 52))
        x0, y0 = canvas(obs, 200, 300)
        mouse(obs, "down", x0, y0)
        xa, ya = canvas(obs, -20, -20)
        mouse(obs, "move", xa, ya)
        assert editor_state(obs)["pointer"] == "rect"
        assert selection(obs) == {TRIGGER, ACTION, CONN_TA}, editor_state(obs)["selection"]
        key(obs, "Esc")
        assert selection(obs) == {TRIGGER}, "the press selected nothing: the selection at the press comes back"
        assert editor_state(obs)["pointer"] == ""
        mouse(obs, "move", xa + 5, ya + 5)           # the button is still down in the test: no drag any more
        mouse(obs, "up", xa + 5, ya + 5)
        assert selection(obs) == {TRIGGER}
    finally:
        finish(sup, obs)


def test_a_drag_moves_the_selection_snapped_to_the_grid_as_one_patch_and_one_undo_step(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        wait_settled(obs)
        click(obs, (70, 52))
        click(obs, (70, 262), ctrl=True)
        before = editor_state(obs)
        x0, y0 = canvas(obs, 70, 262)
        mouse(obs, "down", x0, y0)
        xa, ya = canvas(obs, 110, 282)               # +40, +20 flow units
        mouse(obs, "move", xa, ya)
        assert editor_state(obs)["pointer"] == "move"
        assert editor_state(obs)["rev"] == before["rev"], "nothing is sent during the drag"
        mouse(obs, "up", xa, ya)
        wait_settled(obs)
        st = editor_state(obs)
        assert st["rev"] == before["rev"] + 1, st
        assert st["undo"] == before["undo"] + 1, "the drop is one undo step"
        # 40 and 20 snapped to the grid of 35: 35 and 35 (the trigger), 35 and 210 + 20 -> 245 (the action)
        assert definition_positions(obs)[TRIGGER] == (35, 35), definition_positions(obs)
        assert definition_positions(obs)[ACTION] == (35, 245), definition_positions(obs)
        assert definition_positions(obs)[LAST] == (0, 420), "an element not selected stays"
        step(obs, "undo")
        wait_settled(obs)
        assert definition_positions(obs)[TRIGGER] == (0, 0) and definition_positions(obs)[ACTION] == (0, 210)
        step(obs, "redo")
        wait_settled(obs)
        assert definition_positions(obs)[ACTION] == (35, 245)
    finally:
        finish(sup, obs)


def test_a_drop_where_nothing_changed_sends_nothing(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        wait_settled(obs)
        before = editor_state(obs)
        click(obs, (70, 262))
        drag(obs, (70, 262), (80, 262))              # moved by 10 units: snapped back to x 0, the drag is a move
        wait_settled(obs)
        st = editor_state(obs)
        assert st["rev"] == before["rev"] and st["undo"] == before["undo"], st
    finally:
        finish(sup, obs)


def test_escape_and_the_right_button_cancel_a_move_without_a_patch(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        wait_settled(obs)
        before = editor_state(obs)
        click(obs, (70, 262))
        x0, y0 = canvas(obs, 70, 262)
        mouse(obs, "down", x0, y0)
        xa, ya = canvas(obs, 150, 300)
        mouse(obs, "move", xa, ya)
        assert editor_state(obs)["pointer"] == "move"
        key(obs, "Esc")
        assert editor_state(obs)["pointer"] == ""
        mouse(obs, "move", xa + 40, ya + 40)         # the button is still down: nothing moves any more
        mouse(obs, "up", xa + 40, ya + 40)
        wait_settled(obs)
        assert definition_positions(obs)[ACTION] == (0, 210), "Esc cancelled the move"
        # the right button during a left drag cancels it too (and starts no view drag)
        mouse(obs, "down", x0, y0)
        mouse(obs, "move", xa, ya)
        view_before = editor_state(obs)["view"]
        mouse(obs, "down", xa, ya, button="right")
        assert editor_state(obs)["pointer"] == "", "the right button ended the left drag"
        mouse(obs, "up", xa, ya, button="right")
        mouse(obs, "move", xa + 30, ya + 30, button="none")
        wait_settled(obs)
        assert definition_positions(obs)[ACTION] == (0, 210), "the right button cancelled the move"
        assert editor_state(obs)["view"] == view_before, "no view drag started"
        st = editor_state(obs)
        assert st["undo"] == before["undo"], "a cancelled move is no undo step"
    finally:
        finish(sup, obs)


def test_the_right_button_moves_the_view_and_the_left_button_on_an_empty_place_does_not(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        v0 = editor_state(obs)["view"]
        x0, y0 = canvas(obs, *EMPTY)
        drag_px = (30, 20)
        mouse(obs, "down", x0, y0, button="right")
        for i in range(1, 4):
            mouse(obs, "move", x0 + drag_px[0] * i // 3, y0 + drag_px[1] * i // 3, button="right")
        mouse(obs, "up", x0 + drag_px[0], y0 + drag_px[1], button="right")
        v1 = editor_state(obs)["view"]
        assert v1["offsetX"] == pytest.approx(v0["offsetX"] - 30 / v0["zoom"], abs=0.5), (v0, v1)
        assert v1["offsetY"] == pytest.approx(v0["offsetY"] - 20 / v0["zoom"], abs=0.5), (v0, v1)
        assert v1["zoom"] == v0["zoom"], "a drag does not zoom"
        drag(obs, EMPTY, (EMPTY[0] + 30, EMPTY[1] + 20))
        assert editor_state(obs)["view"] == v1, "the left button on an empty place moves no view (E0094)"
        assert selection(obs) == set(), "and it selects nothing where nothing is"
    finally:
        finish(sup, obs)


def test_a_wheel_zoom_survives_a_change_of_the_flow_by_someone_else(procs, datadir, session_id):
    """F-0166: a definition that comes from the engine (here a rename by the manager) does not take the zoom back."""
    sup, obs = start(procs, datadir, session_id)
    try:
        ans = obs.request(EDITOR, "cmd.test.view", {"zoomAt": {"x": 100, "y": 100, "direction": 1}}, timeout=scaled(5))
        zoomed = ans["payload"]["view"]["zoom"]
        assert zoomed == pytest.approx(1.1), ans
        rev = editor_state(obs)["rev"]
        obs.request("manager", "cmd.test.op", {"op": "rename", "flowId": FLOW, "name": "Renamed flow"}, timeout=scaled(5))
        assert wait_until(lambda: editor_state(obs)["name"] == "Renamed flow", scaled(10)), "the rename did not arrive"
        assert editor_state(obs)["view"]["zoom"] == pytest.approx(zoomed), editor_state(obs)["view"]
    finally:
        finish(sup, obs)


def test_a_loop_tail_changes_its_height_on_the_grid_and_not_below_two_steps(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        edit(obs, [add_loop(LOOP, 700, 0, 70)])
        wait_settled(obs)
        click(obs, (770, 50))                        # the head of the loop
        assert selection(obs) == {LOOP}, editor_state(obs)["selection"]
        before = editor_state(obs)
        # the foot (part 3) of the loop: below the head (105) and the bar (70), at x 700 to 805
        drag(obs, (752, 192), (752, 232))            # +40: 70 + 40 = 110 -> the grid gives 105
        wait_settled(obs)
        assert engine_definition(obs)["allElements"][LOOP]["HeightOfVerticalBar"] == 105
        assert editor_state(obs)["undo"] == before["undo"] + 1
        assert selection(obs) == {LOOP}
        # the foot is now at 210 (105 + 105): drag it up far beyond the minimum of two steps
        drag(obs, (752, 227), (752, 27))
        wait_settled(obs)
        assert engine_definition(obs)["allElements"][LOOP]["HeightOfVerticalBar"] == 70, "at least two grid steps"
    finally:
        finish(sup, obs)
