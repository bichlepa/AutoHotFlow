"""WI-0100, REQ-EDT-070 (connect elements, choose and change the type, move the ends of a connection): the buttons of the
selection (plus, plus2, move1, move2, edit) and the double click of the editor (src/editor/EditorConnect.ahk, EditorPointer.ahk)
under the real supervisor, headless. The mouse goes through cmd.test.mouse (the same pointer methods as the window), the
questions (kind, type, class) are answered with cmd.test.pick and cmd.test.class, the buttons are read from cmd.test.state
(buttons, at their flow centres).

The flow is the skeleton (trigger at (0, 0), actions at (0, 210) and (0, 420), connections trigger -> action and action ->
last). Every change is checked in the engine's definition (cmd.flow.get) after the editor has sent its patch.

Deterministic: a test waits for a condition of the editor or of the engine (wait_until), never for a fixed time.
"""

from support.timing import scaled
from test_manager import FLOW, wait_until
from test_manager_editor import finish, op, start_manager
from test_editor import editor_state, open_editor, render
from test_editor_draft import edit, engine_definition, settled, step
from test_editor_select import canvas, click, drag, key, mouse, move_out_of_the_fields

EDITOR = "editor:" + FLOW
TRIGGER = "element0000000001"
ACTION = "element0000000002"
LAST = "element0000000003"
CONN_TA = "connection0000000004"       # trigger -> action
CONN_AL = "connection0000000005"       # action -> last
COND = "element0000000020"             # a condition, added by the test
LOOP = "element0000000021"            # a loop, added by the test
OTHER = "element0000000022"            # an action, added by the test, the end of the long connection
LONG = "connection0000000023"          # trigger -> last, long enough for move buttons, added by the test
LOOPCONN = "connection0000000024"
EMPTY = (500, 500)                     # right of the flow, nothing there
ON_ACTION = (70, 262)                  # a point in the action at (0, 210)
ON_LAST = (70, 472)                    # a point in the last action at (0, 420)
ON_TRIGGER = (70, 52)                  # a point in the trigger at (0, 0)
ON_CONN_TA = (70, 130)                 # on the first segment of trigger -> action (flow units)
ON_OTHER = (470, 680)                  # a point in the action OTHER at (400, 630)


def start(procs, datadir, session_id):
    sup, obs = start_manager(procs, datadir, session_id)
    op(obs, "select", flowId=FLOW)
    open_editor(obs)
    render(obs)                        # the canvas takes its size; the view is the one of the flow
    move_out_of_the_fields(obs)
    return sup, obs


def state(obs):
    return editor_state(obs, EDITOR)


def rev(obs):
    return state(obs)["rev"]


def definition(obs):
    return engine_definition(obs)


def connections(obs):
    return definition(obs)["allConnections"]


def elements(obs):
    return definition(obs)["allElements"]


def button(obs, name, eid):
    """The flow point of a button of the selection (the state lists the buttons of the single selected item)."""
    for b in state(obs)["buttons"]:
        if b["name"] == name and b["id"] == eid:
            return b["x"], b["y"]
    raise AssertionError("no button %s of %s in %s" % (name, eid, state(obs)["buttons"]))


def select(obs, eid):
    ans = obs.request(EDITOR, "cmd.test.select", {"mode": "one", "ids": [eid]}, timeout=scaled(5))
    assert ans["payload"]["ok"], ans


def answer_pick(obs, button_id):
    ans = obs.request(EDITOR, "cmd.test.pick", {"id": button_id}, timeout=scaled(5))
    assert ans["payload"]["ok"], ans


def answer_class(obs, class_id):
    ans = obs.request(EDITOR, "cmd.test.class", {"id": class_id}, timeout=scaled(5))
    assert ans["payload"]["ok"], ans


def after_patch(obs, before):
    """The editor has sent its patch and the engine has committed it: the revision is above before."""
    assert wait_until(lambda: settled(obs) and rev(obs) > before, scaled(10)), state(obs)


def no_patch(obs, before):
    """Nothing was sent: the editor has no patch on its way and the revision is the same."""
    assert wait_until(lambda: settled(obs), scaled(10)), state(obs)
    assert rev(obs) == before, state(obs)


def connection_between(obs, source, target):
    found = [c for c in connections(obs).values() if c["from"] == source and c["to"] == target]
    assert len(found) == 1, (found, connections(obs))
    return found[0]


def add_condition_and_long_connection_and_other_action(obs):
    """A condition (for the type question), an action that is the new end of the long connection, and the long connection
    trigger -> last (long enough for the move buttons, whose segments are far apart)."""
    before = rev(obs)
    edit(obs, [
        {"op": "element.add", "element": {"ID": COND, "type": "condition", "class": "Condition_Do_nothing",
                                          "package": "Default", "packageVersion": "1.2.0", "x": 0, "y": 630,
                                          "name": "Condition", "StandardName": "Do nothing", "pars": {}}},
        {"op": "element.add", "element": {"ID": OTHER, "type": "action", "class": "Action_Sleep", "package": "Default",
                                          "packageVersion": "1.2.0", "x": 400, "y": 630, "name": "Other",
                                          "StandardName": "Sleep", "pars": {}}},
        {"op": "connection.add", "connection": {"ID": LONG, "from": TRIGGER, "to": LAST, "type": "Connection",
                                                "ConnectionType": "normal"}},
    ])
    after_patch(obs, before)


def test_a_plus_and_a_click_on_an_element_connects_them_and_undo_takes_it_back(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = rev(obs)
        select(obs, LAST)
        click(obs, button(obs, "plus", LAST))
        assert state(obs)["pointer"] == "connect"        # the connection follows the pointer until the next click
        click(obs, ON_ACTION)
        after_patch(obs, before)
        new = connection_between(obs, LAST, ACTION)
        assert new["ConnectionType"] == "normal", new
        assert state(obs)["pointer"] == ""
        assert state(obs)["selection"] == [new["ID"]], state(obs)["selection"]
        step(obs, "undo")
        assert wait_until(lambda: settled(obs) and len(connections(obs)) == 2, scaled(10)), connections(obs)
    finally:
        finish(sup, obs)


def test_a_drag_from_the_plus_connects_where_the_button_goes_up(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = rev(obs)
        select(obs, LAST)
        drag(obs, button(obs, "plus", LAST), ON_ACTION)
        after_patch(obs, before)
        connection_between(obs, LAST, ACTION)
        assert state(obs)["pointer"] == ""
    finally:
        finish(sup, obs)


def test_a_drop_on_empty_space_asks_the_kind_and_the_class_and_adds_both_in_one_undo_step(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = rev(obs)
        select(obs, LAST)
        click(obs, button(obs, "plus", LAST))
        click(obs, EMPTY)
        pick = state(obs)["pick"]
        assert pick["ids"] == ["action", "condition", "loop"], pick     # a new target takes no trigger
        answer_pick(obs, "action")
        choice = state(obs)["choice"]
        assert choice is not None and choice["kind"] == "action", state(obs)
        answer_class(obs, choice["items"][0]["id"])
        after_patch(obs, before)
        d = definition(obs)
        assert len(d["allElements"]) == 4, d["allElements"]
        new_id = [eid for eid in d["allElements"] if eid not in (TRIGGER, ACTION, LAST)][0]
        connection_between(obs, LAST, new_id)
        step(obs, "undo")
        assert wait_until(lambda: settled(obs) and len(elements(obs)) == 3 and len(connections(obs)) == 2, scaled(10))
    finally:
        finish(sup, obs)


def test_a_condition_asks_its_type_and_a_cancel_makes_nothing(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        add_condition_and_long_connection_and_other_action(obs)
        before = rev(obs)
        select(obs, COND)
        click(obs, button(obs, "plus", COND))
        click(obs, ON_ACTION)
        assert state(obs)["pick"]["ids"] == ["yes", "no", "exception"], state(obs)["pick"]
        answer_pick(obs, "")                             # Cancel: nothing is sent
        no_patch(obs, before)
        assert state(obs)["pick"] == "" and len(connections(obs)) == 3

        select(obs, COND)
        click(obs, button(obs, "plus", COND))
        click(obs, ON_ACTION)
        answer_pick(obs, "no")
        after_patch(obs, before)
        assert connection_between(obs, COND, ACTION)["ConnectionType"] == "no"
    finally:
        finish(sup, obs)


def test_a_connection_into_a_trigger_is_refused_with_a_text_and_nothing_is_sent(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = rev(obs)
        select(obs, ACTION)
        click(obs, button(obs, "plus", ACTION))
        click(obs, ON_TRIGGER)
        no_patch(obs, before)
        assert state(obs)["status"].endswith("You cannot connect to trigger!"), state(obs)["status"]
        assert len(connections(obs)) == 2
    finally:
        finish(sup, obs)


def test_an_identical_connection_and_a_connection_to_the_same_element_are_refused(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = rev(obs)
        select(obs, ACTION)
        click(obs, button(obs, "plus", ACTION))
        click(obs, ON_LAST)                              # action -> last exists already
        no_patch(obs, before)
        assert state(obs)["status"].endswith("This connection already exists!"), state(obs)["status"]
        click(obs, button(obs, "plus", ACTION))
        click(obs, ON_ACTION)
        no_patch(obs, before)
        assert state(obs)["status"].endswith("The connection cannot start and end on the same element!"), state(obs)
    finally:
        finish(sup, obs)


def test_escape_cancels_a_connection_that_follows_the_pointer(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = rev(obs)
        select(obs, LAST)
        click(obs, button(obs, "plus", LAST))
        assert state(obs)["pointer"] == "connect"
        key(obs, "Esc")
        assert state(obs)["pointer"] == "" and state(obs)["pick"] == ""
        no_patch(obs, before)
        assert len(connections(obs)) == 2
    finally:
        finish(sup, obs)


def test_the_move_buttons_move_the_end_and_then_the_start_of_a_connection(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        add_condition_and_long_connection_and_other_action(obs)
        select(obs, LONG)
        before = rev(obs)
        click(obs, button(obs, "move2", LONG))           # the end moves ...
        click(obs, ON_OTHER)
        after_patch(obs, before)
        assert connections(obs)[LONG]["to"] == OTHER and connections(obs)[LONG]["from"] == TRIGGER
        select(obs, LONG)
        before = rev(obs)
        click(obs, button(obs, "move1", LONG))           # ... then the start
        click(obs, ON_ACTION)
        after_patch(obs, before)
        long = connections(obs)[LONG]
        assert long["from"] == ACTION and long["to"] == OTHER, long
        assert "fromPart" not in long and "toPart" not in long, long
    finally:
        finish(sup, obs)


def test_a_loop_end_is_attached_to_its_head_or_its_foot_as_v1_does(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = rev(obs)
        edit(obs, [{"op": "element.add", "element": {
            "ID": LOOP, "type": "loop", "class": "Loop_SimpleLoop", "package": "Default", "packageVersion": "1.2.0",
            "x": 400, "y": 0, "HeightOfVerticalBar": 150, "name": "Loop", "StandardName": "Loop", "pars": {}}}])
        assert wait_until(lambda: settled(obs) and rev(obs) > before, scaled(10))
        before = rev(obs)
        select(obs, LOOP)
        click(obs, button(obs, "plus2", LOOP))          # the foot: the connection starts at the tail
        click(obs, ON_ACTION)
        after_patch(obs, before)
        tail = connection_between(obs, LOOP, ACTION)
        assert tail["fromPart"] == "TAIL" and "toPart" not in tail, tail
        before = rev(obs)
        select(obs, LOOP)
        click(obs, button(obs, "plus", LOOP))           # the head
        click(obs, ON_LAST)
        after_patch(obs, before)
        head = connection_between(obs, LOOP, LAST)
        assert head["fromPart"] == "HEAD", head
    finally:
        finish(sup, obs)


def test_a_split_puts_a_new_element_into_a_connection_and_undo_takes_it_back(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = rev(obs)
        select(obs, CONN_AL)
        click(obs, button(obs, "plus", CONN_AL))
        click(obs, EMPTY)
        answer_pick(obs, "action")
        answer_class(obs, state(obs)["choice"]["items"][0]["id"])
        after_patch(obs, before)
        d = definition(obs)
        new_id = [eid for eid in d["allElements"] if eid not in (TRIGGER, ACTION, LAST)][0]
        assert d["allConnections"][CONN_AL]["to"] == new_id, d["allConnections"][CONN_AL]
        connection_between(obs, new_id, LAST)
        assert len(d["allConnections"]) == 3
        step(obs, "undo")
        assert wait_until(lambda: settled(obs) and len(connections(obs)) == 2 and len(elements(obs)) == 3, scaled(10))
        assert connections(obs)[CONN_AL]["to"] == LAST
    finally:
        finish(sup, obs)


def test_a_double_click_on_a_connection_asks_its_type_and_the_answer_changes_it(procs, datadir, session_id):
    sup, obs = start(procs, datadir, session_id)
    try:
        before = rev(obs)
        x, y = canvas(obs, *ON_CONN_TA)
        mouse(obs, "double", x, y)
        assert state(obs)["pick"]["ids"] == ["normal", "exception"], state(obs)["pick"]
        answer_pick(obs, "exception")
        after_patch(obs, before)
        assert connections(obs)[CONN_TA]["ConnectionType"] == "exception"
    finally:
        finish(sup, obs)
