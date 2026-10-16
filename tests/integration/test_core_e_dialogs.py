"""WI-0056: end-to-end tests of the dialog elements with the flow builder, in real sessions (supervisor, storage, engine,
workers). Action_Message_Box, Condition_Confirmation_Dialog, Condition_Debug_Dialog and Action_Tooltip are worker
elements; the test entries answer their windows from the script (support/dialogs.py, TestDialogProvider). Nothing opens a
window here (the gui tests are in test_dialog_windows_gui.py).

Results are read from the flow (the branch or the thread variable A_UserAction, probes) and from the log of the provider
(requests: kind, args, pid, role).
"""

import json
import time

import pytest

from support.coreflows import answer as branch_answer
from support.coreflows import branch, run_all
from support.dialogs import DialogScript, answer, no_answer
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)


# --- Message box -----------------------------------------------------------------------------------------------------
def message_flow(name, **pars):
    """trigger -> Message_Box -> probe A_UserAction -> DONE"""
    fb = FlowBuilder(name)
    box = fb.action("Action_Message_Box", **pars)
    probe = fb.probe("A_UserAction", location="thread")
    done = fb.action("Action_Do_nothing", name="DONE")
    fb.chain(fb.trigger(), box, probe, done)
    return fb


def test_ok_button_ends_normal_and_the_window_has_the_text_of_the_element(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("ok"))
    runs = run_all(flows, [message_flow("mb-ok", title="Hello", message="Text", ButtonLabel="Got it", Width=320,
                                        Height=240)])
    run = runs[0]
    assert run.reason == "finished" and not run.exceptions, run.steps
    assert run.names[-1] == "DONE"
    assert run.seen["A_UserAction"].text == "ok"
    request = dialogs.requests()[0]
    assert request["kind"] == "Window"
    assert request["args"]["title"] == "Hello" and request["args"]["text"] == "Text"
    assert request["args"]["buttons"] == [{"id": "ok", "label": "Got it"}]
    assert (request["args"]["width"], request["args"]["height"]) == (320, 240)
    assert request["args"]["timeoutMs"] == 0 and request["args"]["defaultId"] == "ok"
    assert request["role"] == "worker"


def test_timeout_ends_with_the_result_on_timeout(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(no_answer(), no_answer())
    pars = dict(IsTimeout="Timeout", TimeoutUnits=1, Unit="Seconds")
    runs = run_all(flows, [message_flow("mb-to-normal", OnTimeout="Normal", **pars),
                           message_flow("mb-to-exception", OnTimeout="Exception", **pars)])
    normal, exception = runs
    assert normal.reason == "finished" and not normal.exceptions, normal.steps
    assert normal.seen["A_UserAction"].text == "timeout"
    assert dialogs.requests()[0]["args"]["timeoutMs"] == 1000
    assert exception.exceptions and "Timeout reached" in exception.exceptions[0], exception.steps


def test_timeout_in_minutes_is_converted_to_milliseconds(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("ok"))
    fb = message_flow("mb-minutes", IsTimeout="Timeout", TimeoutUnits=2, Unit="Minutes")
    run_all(flows, [fb])
    assert dialogs.requests()[0]["args"]["timeoutMs"] == 120000


def test_cancel_button_has_its_own_result(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("cancel"), answer("cancel"))
    pars = dict(ShowCancelButton=1, ButtonLabelCancel="Later")
    runs = run_all(flows, [message_flow("mb-cancel-normal", IfDismiss="Normal", **pars),
                           message_flow("mb-cancel-exception", IfDismiss="Exception", **pars)])
    normal, exception = runs
    assert normal.reason == "finished" and not normal.exceptions, normal.steps
    assert normal.seen["A_UserAction"].text == "cancel"
    assert dialogs.requests()[0]["args"]["buttons"] == [{"id": "ok", "label": "OK"},
                                                       {"id": "cancel", "label": "Later"}]
    assert exception.exceptions and "User cancelled the dialog" in exception.exceptions[0], exception.steps


@pytest.mark.parametrize("ifclose, expected", [("Normal", "normal"), ("Exception", "exception")])
def test_closed_window_has_its_own_result(flows, ifclose, expected):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("close"))
    run = run_all(flows, [message_flow("mb-close-%s" % ifclose, IfClose=ifclose)])[0]
    if expected == "normal":
        assert run.reason == "finished" and not run.exceptions, run.steps
        assert run.seen["A_UserAction"].text == "close"
    else:
        assert run.exceptions and "User closed the dialog" in run.exceptions[0], run.steps


# --- Confirmation dialog ---------------------------------------------------------------------------------------------
def confirmation_flow(name, **pars):
    """trigger -> Confirmation_Dialog -> YES / NO"""
    fb = FlowBuilder(name)
    cond = fb.condition("Condition_Confirmation_Dialog", **pars)
    fb.connect(fb.trigger(), cond)
    branch(fb, cond)
    return fb


def test_yes_and_no_buttons_are_the_outputs(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("yes"), answer("no"))
    runs = run_all(flows, [confirmation_flow("cd-yes", title="Really?", message="Delete it?"),
                           confirmation_flow("cd-no", title="Really?", message="Delete it?")])
    assert [branch_answer(run) for run in runs] == ["YES", "NO"]
    request = dialogs.requests()[0]
    assert request["args"]["text"] == "Delete it?" and request["args"]["title"] == "Really?"
    assert request["args"]["buttons"] == [{"id": "yes", "label": "Yes"}, {"id": "no", "label": "No"}]
    assert request["args"]["defaultId"] == "no", "the default button of v1 is No"


def test_default_button_and_button_labels_are_passed_on(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("no"))
    run_all(flows, [confirmation_flow("cd-labels", ButtonLabelYes="Sure", ButtonLabelNo="Nope", DefaultButton="Yes")])
    args = dialogs.requests()[0]["args"]
    assert args["buttons"] == [{"id": "yes", "label": "Sure"}, {"id": "no", "label": "Nope"}]
    assert args["defaultId"] == "yes"


def test_cancel_and_close_use_result_if_dismissed(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("cancel"), answer("close"), answer("cancel"))
    cancel = dict(ShowCancelButton=1, DefaultButton="Cancel")
    runs = run_all(flows, [confirmation_flow("cd-cancel-yes", IfDismiss="Yes", **cancel),
                           confirmation_flow("cd-close-no", IfDismiss="No", **cancel),
                           confirmation_flow("cd-cancel-exc", IfDismiss="Exception", **cancel)])
    assert [branch_answer(run) for run in runs] == ["YES", "NO", "EXCEPTION"]
    assert dialogs.requests()[0]["args"]["defaultId"] == "cancel"
    assert runs[2].exceptions and "User cancelled the dialog" in runs[2].exceptions[0]


def test_timeout_uses_result_on_timeout(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(no_answer(), no_answer(), no_answer())
    pars = dict(IsTimeout=1, TimeoutUnits=1, Unit="Seconds")
    runs = run_all(flows, [confirmation_flow("cd-to-yes", OnTimeout="Yes", **pars),
                           confirmation_flow("cd-to-no", OnTimeout="No", **pars),
                           confirmation_flow("cd-to-exc", OnTimeout="Exception", **pars)])
    assert [branch_answer(run) for run in runs] == ["YES", "NO", "EXCEPTION"]
    assert dialogs.requests()[0]["args"]["timeoutMs"] == 1000
    assert runs[2].exceptions and "Timeout reached" in runs[2].exceptions[0]


# --- Debug dialog (REQ-DBG-060) --------------------------------------------------------------------------------------
def debug_flow(name, probes=("Foo",), setup=(), only_new=False):
    """trigger -> New variables (setup) -> Debug_Dialog -> YES -> probes -> DONE; NO -> NO. The actions the window
    takes are in the script of the provider (DialogScript), not in the flow."""
    fb = FlowBuilder(name)
    prev = fb.trigger()
    for varname, value in setup:
        pars = dict(onlyIfNotExist=1) if only_new else {}
        step = fb.action("Action_New_variable", Varname=varname, VarValue=value, expression="string", **pars)
        fb.connect(prev, step)
        prev = step
    cond = fb.condition("Condition_Debug_Dialog")
    fb.connect(prev, cond)
    yes = fb.action("Action_Do_nothing", name="YES")
    no = fb.action("Action_Do_nothing", name="NO")
    fb.connect(cond, yes, "yes")
    fb.connect(cond, no, "no")
    if probes:
        fb.chain(yes, fb.probe(*probes), fb.action("Action_Do_nothing", name="DONE"))
    return fb


def debug_entry(actions=(), answer_value="yes"):
    return {"answer": answer_value, "actions": list(actions)}


def test_every_scope_the_branch_can_see_is_listed(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(debug_entry([{"op": "rows"}]))
    fb = debug_flow("dbg-scopes", probes=(),
                       setup=[("Foo", "1"), ("static_S", "2"), ("global_G", "3")])
    run = run_all(flows, [fb])[0]
    assert run.reason == "finished" and "YES" in run.names, run.steps
    rows = dialogs.requests()[0]["args"]["rows"]
    seen = {(row["name"], row["scope"]) for row in rows}
    assert {("Foo", "instance"), ("static_S", "static"), ("global_G", "global")} <= seen, rows


def test_the_loop_variables_are_listed_inside_a_loop(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(debug_entry())
    fb = FlowBuilder("dbg-loop")
    loop = fb.loop("Loop_SimpleLoop", repeatCount=1)
    cond = fb.condition("Condition_Debug_Dialog")
    fb.connect(fb.trigger(), loop)
    fb.connect(loop, cond, "head")
    fb.connect(cond, loop, "yes", into="tail")
    fb.connect(loop, fb.action("Action_Do_nothing", name="DONE"), "tail")
    run = run_all(flows, [fb])[0]
    assert run.reason == "finished" and not run.exceptions, run.steps
    rows = dialogs.requests()[0]["args"]["rows"]
    assert {"name": "A_Index", "scope": "loop"} in rows, rows


def test_a_changed_value_and_type_and_a_deleted_variable(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(debug_entry([
        {"op": "set", "name": "Foo", "value": "changed"},
        {"op": "set", "name": "Obj", "value": '{"a": 1, "b": [2, 3]}', "object": True},
        {"op": "delete", "name": "Bar"},
    ]))
    fb = debug_flow("dbg-change", probes=("Foo", "Obj", "Bar"), setup=[("Foo", "1"), ("Bar", "2")])
    run = run_all(flows, [fb])[0]
    assert run.reason == "finished" and "YES" in run.names, run.steps
    assert run.seen["Foo"].text == "changed" and run.seen["Foo"].type == "String"
    assert run.seen["Obj"].type == "Map"
    assert json.loads(run.seen["Obj"].text) == {"a": 1, "b": [2, 3]}
    assert run.seen["Bar"].type == "<missing>"


def test_a_text_that_is_no_object_stays_out_of_the_variable(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(debug_entry([
        {"op": "set", "name": "Foo", "value": "{ not json", "object": True},
        {"op": "set", "name": "Foo", "value": "plain"},
    ]))
    fb = debug_flow("dbg-type", probes=("Foo",), setup=[("Foo", "1")])
    run = run_all(flows, [fb])[0]
    assert run.reason == "finished" and "YES" in run.names, run.steps
    results = dialogs.requests()[0]["args"]["results"]
    assert results[0]["error"].startswith("The text is not a valid object"), results
    assert results[1]["error"] == ""
    assert run.seen["Foo"].text == "plain" and run.seen["Foo"].type == "String"


def test_a_change_of_a_global_variable_is_seen_by_another_flow_a_static_one_by_the_next_instance(flows):
    """A static variable belongs to its flow (it is kept between the instances of that flow); a global one is seen by
    every flow. The setup of the writer keeps existing variables (onlyIfNotExist), so the second instance does not
    reset them."""
    dialogs = DialogScript(flows.datadir)
    dialogs.script(debug_entry([
        {"op": "set", "name": "static_S", "value": "static changed"},
        {"op": "set", "name": "global_G", "value": "global changed"},
        {"op": "delete", "name": "static_Gone"},
    ]), debug_entry())
    writer = debug_flow("dbg-writer", probes=("static_S", "global_G", "static_Gone"),
                        setup=[("static_S", "1"), ("global_G", "1"), ("static_Gone", "x")], only_new=True)
    reader = FlowBuilder("dbg-reader")
    reader.chain(reader.trigger(), reader.probe("global_G", "static_S"))
    writer_id = flows.add(writer)
    reader_id = flows.add(reader)
    flows.start()
    first = flows.run(writer_id, timeout=30)
    assert first.reason == "finished" and "YES" in first.names, first.steps
    assert first.probe("static_S").text == "static changed"
    assert first.probe("static_Gone").type == "<missing>", "the window deleted it"
    other = flows.run(reader_id, timeout=30)
    assert other.reason == "finished", other.steps
    assert other.probe("global_G").text == "global changed"
    assert other.probe("static_S").type == "<missing>", "a static variable belongs to its flow"
    second = flows.run(writer_id, timeout=30)
    assert second.reason == "finished" and "YES" in second.names, second.steps
    assert second.probe("static_S").text == "static changed", "the next instance of the flow sees it"


def test_closing_the_debug_window_ends_the_element_with_exception(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script({"answer": "close"})
    fb = debug_flow("dbg-close", probes=())
    run = run_all(flows, [fb])[0]
    assert run.exceptions and "User dismissed the dialog" in run.exceptions[0], run.steps


def test_read_shows_the_value_of_a_variable(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(debug_entry([{"op": "read", "name": "Foo"}]))
    fb = debug_flow("dbg-read", probes=(), setup=[("Foo", "shown")])
    run = run_all(flows, [fb])[0]
    assert run.reason == "finished" and "YES" in run.names, run.steps
    assert dialogs.requests()[0]["args"]["results"] == [{"op": "read", "name": "Foo", "type": "normal", "text": "shown"}]


def test_other_branches_go_on_while_the_debug_window_is_open(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script({"noAnswer": True})
    debug_id = flows.add(debug_flow("dbg-open", probes=()))
    other = FlowBuilder("dbg-other")
    other.chain(other.trigger(), other.action("Action_Do_nothing", name="OTHER"))
    other_id = flows.add(other)
    flows.start()
    pending = flows.begin(debug_id)
    time.sleep(0.5)                                    # the window is open now (the request is logged)
    assert dialogs.requests() and dialogs.requests()[0]["kind"] == "Debug"
    finished = flows.run(other_id, timeout=10)
    assert finished.reason == "finished" and "OTHER" in finished.names
    flows.request_ok("engine", "cmd.flow.stop", {"flowId": pending.flow_id})
    flows.wait(pending, timeout=15)
    assert pending.reason == "flow.stop", pending.steps


# --- Tooltip -------------------------------------------------------------------------------------------------------------
def test_tooltip_finishes_at_once_and_is_removed_by_a_timer(flows):
    dialogs = DialogScript(flows.datadir)
    fb = FlowBuilder("tooltip")
    tip = fb.action("Action_Tooltip", text="hello", duration=300, Unit="Milliseconds", follow_mouse=0)
    fb.chain(fb.trigger(), tip, fb.action("Action_Do_nothing", name="DONE"))
    run = run_all(flows, [fb])[0]
    assert run.reason == "finished" and not run.exceptions and "DONE" in run.names, run.steps
    shown = [r for r in dialogs.requests() if r["kind"] == "ToolTip"]
    assert shown and shown[0]["args"]["text"] == "hello" and shown[0]["args"]["which"] == 13
    deadline = time.time() + 5
    while time.time() < deadline and not any(r["args"]["text"] == "" for r in dialogs.requests() if r["kind"] == "ToolTip"):
        time.sleep(0.1)
    assert any(r["args"]["text"] == "" for r in dialogs.requests() if r["kind"] == "ToolTip"), "not removed"
    assert {r["role"] for r in shown} == {"worker"}, "the tooltip was shown in a worker, not in the engine"


# --- two instances, a stop ------------------------------------------------------------------------------------------------
def test_two_dialogs_of_two_instances_are_open_at_the_same_time(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("ok", delay_ms=800), answer("ok"))
    flow_id = flows.add(message_flow("mb-two"))
    flows.start()
    first = flows.begin(flow_id)
    second = flows.begin(flow_id)
    for run in (first, second):
        flows.wait(run, timeout=20)
        assert run.reason == "finished" and not run.exceptions, run.steps
    requests = dialogs.requests()
    assert len(requests) == 2 and all(r["scripted"] for r in requests)
    assert len({r["pid"] for r in requests}) == 2, "two workers answered the two dialogs"
    assert {r["role"] for r in requests} == {"worker"}


@pytest.mark.slow
def test_a_pending_message_box_is_ended_by_the_stop_of_the_flow(flows):
    dialogs = DialogScript(flows.datadir)
    dialogs.script(no_answer())
    fb = message_flow("mb-stop")
    run = flows.begin(fb)
    time.sleep(0.5)
    flows.request_ok("engine", "cmd.flow.stop", {"flowId": run.flow_id})
    flows.wait(run, timeout=15)
    assert run.reason == "flow.stop", run.steps
    assert len(dialogs.requests()) == 1
