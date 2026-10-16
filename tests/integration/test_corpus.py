"""WI-0057: the test corpus, the acceptance of S0002 (REQ-TST-040, REQ-TST-030).

Three flows of the "Automatic tests" category of v1 run headless and green, all three as saved: "variable test", "List
test" and "Loop test". "variable test" needs the trigger variable A_ManualTriggerID, which the engine sets for every start
of a trigger (TriggerVariables, WI-0062, M-0069 is done), so the old copy with its fixes is gone.

Then 16 synthetic flows (flow builder, WI-0049) that use the core set wider than the v1 flows do: each flow is a chain
of checks or steps that ends in the marker DONE; a flow that does not behave as expected goes to FAIL or ends with an
exception. The PENDING table lists the other 13 "Automatic tests" flows with the elements that are still missing and
the step that brings them (S0003 and S0008); a test keeps the table equal to the element registry in src/.
"""

import glob
import json
import os
from pathlib import Path

import pytest

from support.coreflows import run_all, setvar
from support.dialogs import DialogScript, answer
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.timing import scaled

pytestmark = pytest.mark.slow          # each test starts a session (acceptance tier, `-m slow`)

ROOT = Path(__file__).resolve().parents[2]
V1 = ROOT / "tests" / "data" / "flows" / "v1_examples"

# --- the flows that are not in the corpus yet ---------------------------------------------------------------------
# The v1 flow "Automatic tests" flows that are not in this corpus yet: the elements they lack and the step that brings them
# (WI-0057 task 3). The test below keeps this table equal to the element registry.
PENDING = {
    "Flow 100439537": dict(name="HTTP Request", missing={
        "Action_Convert_String_to_List": "S0008", "Action_HTTP_Request": "S0008"}),
    "Flow 1087828277": dict(name="maths test", missing={
        "Action_Absolute_number": "S0008", "Action_Exponentiation": "S0008", "Action_Random_number": "S0008",
        "Action_Rounding_a_number": "S0008", "Action_Set_flow_status": "S0003", "Action_Square_root": "S0008",
        "Action_Trigonometry": "S0008"}),
    "Flow 130786371": dict(name="Dialog test", missing={
        "Action_Close_Window": "S0008", "Action_Convert_String_to_List": "S0008", "Action_Get_Control_Text": "S0008",
        "Action_Input_Box": "S0008", "Action_Send_Keystrokes_to_Control": "S0008", "Condition_Window_Exists": "S0008"}),
    "Flow 1333431302": dict(name="User idle test", missing={
        "Action_Set_flow_status": "S0003", "Trigger_User_Idle_Time": "S0008"}),
    "Flow 1384439262": dict(name="file test", missing={
        "Action_Close_Window": "S0008", "Action_Copy_File": "S0008", "Action_Copy_Folder": "S0008",
        "Action_Create_Folder": "S0008", "Action_Create_Shortcut": "S0008", "Action_Delete_File": "S0008",
        "Action_Delete_Folder": "S0008", "Action_Get_File_Size": "S0008", "Action_Get_File_Time": "S0008",
        "Action_Get_Shortcut_Information": "S0008", "Action_Move_File": "S0008", "Action_Move_Folder": "S0008",
        "Action_Read_From_File": "S0008", "Action_Rename_File": "S0008", "Action_Rename_Folder": "S0008",
        "Action_Run": "S0008", "Action_Set_File_Time": "S0008", "Action_Time_Calculation": "S0008",
        "Action_Time_Difference": "S0008", "Action_Write_to_File": "S0008", "Condition_File_Exists": "S0008",
        "Condition_File_Has_Attribute": "S0008", "Condition_Window_Exists": "S0008"}),
    "Flow 1587447767": dict(name="ini file test", missing={
        "Action_Read_from_INI": "S0008", "Action_Write_to_INI": "S0008"}),
    "Flow 1849072261": dict(name="external script test", missing={
        "Action_AutoHotkey_Script": "S0008 (E0039: v1 code is kept as text, M-0049)"}),
    "Flow 2133155705": dict(name="Hotkey test", missing={
        "Action_Send_Keystrokes": "S0008", "Action_Set_flow_status": "S0003", "Trigger_Hotkey": "S0003"}),
    "Flow 369404488": dict(name="string test", missing={
        "Action_Search_in_a_string": "S0008", "Action_Set_flow_status": "S0003", "Action_Split_a_string": "S0008",
        "Action_Substring": "S0008", "Action_Substring2": "S0008", "Action_Trim_a_string": "S0008",
        "Condition_String_contains_text": "S0008"}),
    "Flow 561135904": dict(name="Process Test", missing={
        "Action_Kill_Process": "S0008", "Action_Run": "S0008", "Action_Set_flow_status": "S0003",
        "Condition_Process_is_running": "S0008", "Trigger_Periodic_Timer": "S0003", "Trigger_Process_closes": "S0008",
        "Trigger_Process_starts": "S0008"}),
    "Flow 65341778": dict(name="_AutomaticTest starter", missing={
        "Action_Play_Sound": "S0008", "Action_Set_flow_status": "S0003"}),
    "Flow 74366368": dict(name="File link test", missing={
        "Action_Delete_File": "S0008", "Action_Run": "S0008", "Action_Set_flow_status": "S0003",
        "Condition_File_Exists": "S0008", "Trigger_Shortcut": "S0008"}),
    "Flow 884290977": dict(name="Trigger test", missing={
        "Action_Set_flow_status": "S0003", "Action_Speech_Output": "S0008", "Condition_Flow_Enabled": "S0003",
        "Trigger_Periodic_Timer": "S0003", "Trigger_Start_Up": "S0003"}),
}


def shown(run, name):
    """The value of a probe: the parsed JSON of a list or object, the text of any other value."""
    probe = run.probe(name)
    assert probe is not None, "probe '%s' was not written" % name
    return json.loads(probe.text) if probe.type == "Map" else probe.text


def finished(run):
    return run.reason == "finished" and not run.exceptions


def check_flow(name, checks, strict=True, setup=()):
    """trigger -> [Action_TestSetVar] -> one Condition_Expression per check -> DONE. A check whose result is not the
    expected one (`want`) goes to FAIL. `setup` is a list of (name, value) for the variables."""
    fb = FlowBuilder(name, strict_types=strict)
    prev = fb.trigger()
    if setup:
        step = fb.action("Action_TestSetVar", Steps=json.dumps([setvar(n, v) for n, v in setup]))
        fb.connect(prev, step)
        prev = step
    fail = fb.action("Action_Do_nothing", name="FAIL")
    pending = "normal"
    for expr, want in checks:
        cond = fb.element("Condition_Expression", "condition", name="check: " + expr, Expression=expr)
        fb.connect(prev, cond, pending)
        good, bad = ("yes", "no") if want else ("no", "yes")
        fb.connect(cond, fail, bad)
        prev, pending = cond, good
    fb.connect(prev, fb.action("Action_Do_nothing", name="DONE"), pending)
    return fb


def check_run(run):
    """A check flow passed when it reached DONE and never FAIL, without an exception."""
    return finished(run) and "DONE" in run.names and "FAIL" not in run.names


def failing(runs_and_names):
    return [name for run, name in runs_and_names if not check_run(run)]


# --- the three v1 flows ------------------------------------------------------------------------------------------------
def test_v1_variable_test_runs_green_as_saved(flows):
    """"variable test" (Flow 1010290492), as saved. The trigger "start" runs the basic test, which writes its trigger name
    into static_results, then the content test (100 Condition_Variable_content_is checks), and the flow adds its name to
    the global list only when both names are in the list. The two elements that write A_ManualTriggerID get it from the
    trigger's TriggerVariables, also at a start by the engine (WI-0062)."""
    flow_id = flows.add_file(V1 / "Flow 1010290492.json")
    flows.start()
    flows.enable(flow_id)                    # F-0099: Execute_Flow needs an enabled trigger; a loaded trigger does not enable its flow (until S0003)
    run = flows.run(flow_id, trigger="element0000000019", timeout=scaled(60))
    assert run.reason == "finished" and not run.exceptions, (run.reason, run.exceptions, run.names[-5:])
    assert run.path[-1] == "element0000000015" and len(run.path) == 130, (len(run.path), run.names[-3:])
    assert "element0000000098" in run.path                       # the content test ran (its last Add to list)
    assert "element0000000027" in run.path and "element0000000101" in run.path   # the two list checks


def test_v1_variable_test_basic_trigger_runs_green(flows):
    """The second trigger of "variable test" (the basic test) runs to its end on the original file, without exception."""
    flow_id = flows.add_file(V1 / "Flow 1010290492.json")
    flows.start()
    basic = flows.run(flow_id, trigger="element0000000002", timeout=scaled(60))
    assert basic.reason == "finished" and not basic.exceptions, (basic.reason, basic.exceptions)


def test_v1_list_test_runs_green(flows):
    """"List test" (Flow 1210127300), unchanged: the Get index of 'asdf' fails on purpose and its exception connection leads
    on; the flow ends with Add to list on a list that does not exist yet (a warning)."""
    flow_id = flows.add_file(V1 / "Flow 1210127300.json")
    flows.start()
    run = flows.run(flow_id, trigger="element0000000008", timeout=scaled(60))
    assert run.reason == "finished"
    assert run.exceptions == ["The list 'russianList' does not contain the value 'asdf'."], run.exceptions
    assert run.path[-1] == "element0000000112"
    assert any("Variable 'global_testResults' is empty" in e["text"] for e in run.log)


def test_v1_loop_test_runs_green(flows):
    """"Loop test" (Flow 634320780), unchanged: nested and sequential loops of every kind with trace points; the check of
    the trace points passes, and the flow writes its name to the global list."""
    flow_id = flows.add_file(V1 / "Flow 634320780.json")
    flows.start()
    run = flows.run(flow_id, timeout=scaled(60))
    assert finished(run), (run.reason, run.exceptions)
    assert run.state_of("element0000000012") == ["finished"] and run.path[-1] == "element0000000030"
    pair = flows.wait_var("global_testResults")
    assert pair is not None and json.loads(pair[1]) == ["Loop test"], pair


# --- the synthetic flows -----------------------------------------------------------------------------------------------
ARITHMETIC = [
    ("2 + 3 * 4 = 14", True), ("(2 + 3) * 4 = 20", True), ("7 / 2 = 3.5", True), ("7 // 2 = 3", True),
    ("x + 1 = 6", True), ("x * 2 >= 10", True), ("x > 5", False), ("x / 2 = 2.5", True), ("-x = -5", True),
]


def test_1_arithmetic_in_conditions_strict(flows):
    """Numbers and calculations in conditions in the strict type mode (E0034): every check passes or goes to FAIL."""
    fb = check_flow("c-arith-strict", ARITHMETIC, strict=True, setup=[("x", 5)])
    run = run_all(flows, [fb])[0]
    assert check_run(run), run.names


def test_2_arithmetic_in_conditions_compatibility(flows):
    """The same calculations in the compatibility mode (migrated flows, M-0047). A missing variable is the empty text,
    and `<` with a text that is no number gives the empty text (false) with an f1 entry in the compatibility mode (M-0025)."""
    checks = ARITHMETIC + [("missing < 3", False)]
    fb = check_flow("c-arith-compat", checks, strict=None, setup=[("x", 5)])
    run = run_all(flows, [fb])[0]
    assert check_run(run), run.names
    assert any(e["level"] == "f1" for e in run.log), run.log


TEXT = [
    ('name = "Paul"', True), ('name = "paul"', True), ('name == "paul"', False), ('name . "!" = "Paul!"', True),
    ('"a" < "b"', False), ('name != "Anna"', True),
]


def test_3_text_in_conditions_strict_the_comparison_of_texts_is_the_one_of_autohotkey(flows):
    """Texts in conditions in the strict mode: `=` ignores the case, `==` does not (AutoHotkey v2 operators)."""
    fb = check_flow("c-text-strict", TEXT[:4] + TEXT[5:], strict=True, setup=[("name", "Paul")])
    run = run_all(flows, [fb])[0]
    assert check_run(run), run.names


def test_4_text_comparison_with_less_than_ends_with_exception_in_strict_and_false_in_compatibility(flows):
    """`<` between two texts is a type error: in strict mode the element ends with exception (E0034, M-0025); in the
    compatibility mode the result is the empty text (false) with an f1 entry (M-0025). v1 compared alphabetically."""
    strict = FlowBuilder("c-lt-strict", strict_types=True)
    strict.chain(strict.trigger(), strict.condition("Condition_Expression", Expression='"abc" < "abd"'))
    compat = check_flow("c-lt-compat", [('"abc" < "abd"', False)], strict=None)
    strict_run, compat_run = run_all(flows, [strict, compat])
    assert strict_run.reason == "exception" and strict_run.exceptions, strict_run.steps
    assert check_run(compat_run), compat_run.names
    assert any(e["level"] == "f1" for e in compat_run.log), compat_run.log


def test_5_nested_loops_over_lists_count_every_round(flows):
    """A loop over 2 rounds, inside a loop over the list of 3 items: 6 rounds of the inner body, each writes its item to
    the list `out`. The outer loop counts its rounds in a variable."""
    fb = FlowBuilder("nested-lists")
    start = fb.trigger()
    setup = fb.action("Action_TestSetVar", Steps=json.dumps([setvar("l", ["a", "b", "c"]),
                                                              setvar("out", [])]))
    outer = fb.loop("Loop_SimpleLoop", Infinite=0, repeatCount=2)
    inner = fb.loop("Loop_Work_through_a_list", VarValue="l")
    add = fb.action("Action_Add_To_List", Varname="out", NumberOfElements="One", VarValue="%a_loopfield%",
                    WhichPosition="Last")
    rounds = fb.action("Action_New_variable", Varname="rounds", VarValue="%a_index%", expression="String")
    fb.chain(start, setup, outer)
    fb.connect(outer, inner, "head")
    fb.connect(inner, add, "head")
    fb.connect(add, inner, into="tail")
    fb.connect(inner, rounds, "tail")
    fb.connect(rounds, outer, into="tail")
    fb.connect(outer, fb.probe("out", "rounds"), "tail")
    run = run_all(flows, [fb])[0]
    assert finished(run), (run.reason, run.exceptions, run.names[-4:])
    assert shown(run, "out") == ["a", "b", "c", "a", "b", "c"], run.seen
    assert shown(run, "rounds") == "2", run.seen


def test_6_a_loop_over_a_list_is_left_early_with_a_break(flows):
    """A loop over the list stops at the item "b" (the break connection of the loop); the items before it are kept."""
    fb = FlowBuilder("list-break")
    setup = fb.action("Action_TestSetVar", Steps=json.dumps([setvar("l", ["a", "b", "c"]), setvar("out", [])]))
    loop = fb.loop("Loop_Work_through_a_list", VarValue="l")
    check = fb.condition("Condition_Expression", Expression='a_loopfield = "b"')
    add = fb.action("Action_Add_To_List", Varname="out", NumberOfElements="One", VarValue="%a_loopfield%",
                    WhichPosition="Last")
    fb.chain(fb.trigger(), setup, loop)
    fb.connect(loop, check, "head")
    fb.connect(check, loop, "yes", into="break")
    fb.connect(check, add, "no")
    fb.connect(add, loop, into="tail")
    fb.connect(loop, fb.probe("out"), "tail")
    run = run_all(flows, [fb])[0]
    assert finished(run), (run.reason, run.exceptions, run.names[-4:])
    assert shown(run, "out") == ["a"], run.seen


def test_7_a_flow_calls_itself_recursively_with_variables(flows):
    """The flow "recursion" calls itself with its variables (SendLocalVars). Every call raises `depth` and calls again
    until depth 3, where the call ends; each caller then writes its own depth to the global list on the way back.
    The start trigger writes 0 first: the list is 3, 2, 1, 0 (the unwinding order)."""
    fb = FlowBuilder("recursion")
    start = fb.trigger()
    rec = fb.trigger(ID="rec")
    clear = fb.action("Action_New_List", Varname="global_returns", NumberOfElements="None")
    zero = fb.action("Action_New_variable", Varname="depth", VarValue="0", expression="Expression")
    call = fb.action("Action_Execute_Flow", name="call (start)", ThisFlow=1, flowID="", WhichTrigger="Specified",
                     triggerID=rec.id, SendLocalVars=1, WaitToFinish=1, ReturnVariables=0, SkipDisabled=0)
    fb.chain(start, clear, zero, call)
    cond = fb.condition("Condition_Expression", Expression="depth >= 3")
    fb.connect(rec, cond)
    inc = fb.action("Action_New_variable", Varname="depth", VarValue="depth + 1", expression="Expression")
    again = fb.action("Action_Execute_Flow", name="call (recursive)", ThisFlow=1, flowID="", WhichTrigger="Specified",
                      triggerID=rec.id, SendLocalVars=1, WaitToFinish=1, ReturnVariables=0, SkipDisabled=0)
    note = fb.action("Action_Add_To_List", Varname="global_returns", NumberOfElements="One", VarValue="%depth%",
                     WhichPosition="Last")
    fb.connect(cond, fb.action("Action_Do_nothing", name="DEEPEST"), "yes")
    fb.connect(cond, inc, "no")
    fb.chain(inc, again, note)
    note0 = fb.action("Action_Add_To_List", Varname="global_returns", NumberOfElements="One", VarValue="%depth%",
                      WhichPosition="Last")
    fb.chain(call, note0, fb.probe("global_returns"))
    flow_id = flows.add(fb)
    flows.start()
    flows.enable(flow_id)    # F-0099: the flow must be enabled for Execute_Flow (until S0003)
    run = flows.run(flow_id, timeout=scaled(60), trigger=start.id)
    assert finished(run), (run.reason, run.exceptions, run.names[-4:])
    assert shown(run, "global_returns") == ["3", "2", "1", "0"], run.seen
    assert run.names.count("DEEPEST") == 1


def test_8_a_flow_waits_for_two_called_flows_one_after_the_other(flows):
    """"waiter" calls "slow" (waits for it) and then "fast" (waits). "slow" sleeps before it writes, so only a waiting
    caller writes the order A, B."""
    slow = FlowBuilder("slow")
    st = slow.trigger()
    slow_sleep = slow.action("Action_Sleep", Duration=300, Unit="Milliseconds")
    slow_add = slow.action("Action_Add_To_List", Varname="global_order", NumberOfElements="One", VarValue="slow",
                           WhichPosition="Last")
    slow.chain(st, slow_sleep, slow_add)
    fast = FlowBuilder("fast")
    ft = fast.trigger()
    fast_add = fast.action("Action_Add_To_List", Varname="global_order", NumberOfElements="One", VarValue="fast",
                           WhichPosition="Last")
    fast.chain(ft, fast_add)
    waiter = FlowBuilder("waiter")
    wt = waiter.trigger()
    clear = waiter.action("Action_New_List", Varname="global_order", NumberOfElements="None")
    call_slow = waiter.action("Action_Execute_Flow", name="call slow", ThisFlow=0, flowID="slow", WhichTrigger="Default",
                              triggerID="", SendLocalVars=0, WaitToFinish=1, ReturnVariables=0, SkipDisabled=0)
    call_fast = waiter.action("Action_Execute_Flow", name="call fast", ThisFlow=0, flowID="fast", WhichTrigger="Default",
                              triggerID="", SendLocalVars=0, WaitToFinish=1, ReturnVariables=0, SkipDisabled=0)
    waiter.chain(wt, clear, call_slow, call_fast, waiter.probe("global_order"), waiter.action("Action_Do_nothing",
                                                                                          name="DONE"))
    ids = [flows.add(slow), flows.add(fast), flows.add(waiter)]
    flows.start()
    for flow_id in ids[:2]:
        flows.enable(flow_id)
    run = flows.run(ids[2], timeout=scaled(60))
    assert finished(run), (run.reason, run.exceptions, run.names[-4:])
    assert json.loads(run.probe("global_order").text) == ["slow", "fast"], run.probe("global_order").text


def test_9_a_message_box_in_a_loop_gets_its_answers_in_order(flows):
    """A loop of three rounds shows a message box each round; each answer (OK) is added to the list of answers."""
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("ok"), answer("ok"), answer("ok"))
    fb = FlowBuilder("box-loop")
    setup = fb.action("Action_TestSetVar", Steps=json.dumps([setvar("answers", [])]))
    loop = fb.loop("Loop_SimpleLoop", Infinite=0, repeatCount=3)
    box = fb.action("Action_Message_Box", title="Loop", message="Round", ButtonLabel="OK")
    add = fb.action("Action_Add_To_List", Varname="answers", NumberOfElements="One", VarValue="%A_UserAction%",
                    WhichPosition="Last")
    fb.chain(fb.trigger(), setup, loop)
    fb.connect(loop, box, "head")
    fb.connect(box, add)
    fb.connect(add, loop, into="tail")
    fb.connect(loop, fb.probe("answers"), "tail")
    run = run_all(flows, [fb])[0]
    assert finished(run), (run.reason, run.exceptions, run.steps[-3:])
    assert shown(run, "answers") == ["ok", "ok", "ok"], run.seen
    assert len(dialogs.requests()) == 3


def test_10_a_confirmation_in_a_loop_ends_the_loop_with_no(flows):
    """A confirmation is asked up to five times; yes asks again, no leaves the loop early (break). Scripted: yes, yes, no:
    three windows, then the flow goes on."""
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer("yes"), answer("yes"), answer("no"))
    fb = FlowBuilder("confirm-loop")
    loop = fb.loop("Loop_SimpleLoop", Infinite=0, repeatCount=5)
    ask = fb.condition("Condition_Confirmation_Dialog", title="Again?", message="Continue?")
    fb.chain(fb.trigger(), loop)
    fb.connect(loop, ask, "head")
    fb.connect(ask, loop, "yes", into="tail")
    fb.connect(ask, loop, "no", into="break")
    fb.connect(loop, fb.action("Action_Do_nothing", name="AFTER"), "tail")
    run = run_all(flows, [fb])[0]
    assert finished(run) and "AFTER" in run.names, (run.reason, run.exceptions, run.names[-4:])
    assert run.names.count("Condition_Confirmation_Dialog") == 3 and len(dialogs.requests()) == 3
    assert [r["args"]["title"] for r in dialogs.requests()] == ["Again?"] * 3


def test_11_the_debug_dialog_in_a_loop_shows_and_keeps_a_changed_variable(flows):
    """REQ-DBG-060: the debug dialog runs in a loop of two rounds; in the first round the window changes Foo, and the flow
    reads the change after the loop. The second window lists Foo."""
    dialogs = DialogScript(flows.datadir)
    dialogs.script(
        {"answer": "yes", "actions": [{"op": "set", "name": "Foo", "value": "changed"}]},
        {"answer": "yes", "actions": []})
    fb = FlowBuilder("debug-loop")
    setup = fb.action("Action_New_variable", Varname="Foo", VarValue="start", expression="String")
    loop = fb.loop("Loop_SimpleLoop", Infinite=0, repeatCount=2)
    dbg = fb.condition("Condition_Debug_Dialog")
    fb.chain(fb.trigger(), setup, loop)
    fb.connect(loop, dbg, "head")
    fb.connect(dbg, loop, "yes", into="tail")
    fb.connect(loop, fb.probe("Foo"), "tail")
    run = run_all(flows, [fb])[0]
    assert finished(run), (run.reason, run.exceptions, run.names[-4:])
    assert shown(run, "Foo") == "changed", run.seen
    # the request log has the names of the rows only (no values): the second window lists Foo, the flow reads the change
    assert any(r["name"] == "Foo" for r in dialogs.requests()[1]["args"]["rows"]), dialogs.requests()[1]["args"]


def test_12_a_loop_is_left_through_the_exception_connection(flows):
    """Round 3 of a five-round loop: the element of the yes branch ends with an exception (an empty list value), and its
    exception connection leaves the loop. The body ran three times, the flow went on at CAUGHT, not AFTER."""
    fb = FlowBuilder("loop-exception")
    loop = fb.loop("Loop_SimpleLoop", Infinite=0, repeatCount=5)
    cond = fb.condition("Condition_Expression", Expression="a_index = 3")
    broken = fb.action("Action_New_List", Varname="broken", NumberOfElements="One", VarValue="",
                       WhichPosition="First")
    fb.chain(fb.trigger(), loop)
    fb.connect(loop, cond, "head")
    fb.connect(cond, broken, "yes")
    fb.connect(cond, loop, "no", into="tail")
    fb.connect(broken, loop, into="tail")
    fb.connect(broken, fb.action("Action_Do_nothing", name="CAUGHT"), "exception")
    fb.connect(loop, fb.action("Action_Do_nothing", name="AFTER"), "tail")
    run = run_all(flows, [fb])[0]
    assert run.reason == "finished", (run.reason, run.steps)
    assert run.names.count("Condition_Expression") == 3, run.names
    assert run.names[-1] == "CAUGHT" and "AFTER" not in run.names
    assert [s.message for s in run.steps if s.state == "exception"] == ["String 'VarValue' is empty"]


def test_13_a_flow_with_an_element_of_a_missing_package_loads_and_its_caller_sees_the_exception(flows):
    """E0047: the flow of the missing package is loaded and kept as it is; its element fails when it runs. Its caller
    waits for it and goes on with the outcome."""
    missing = FlowBuilder("missing-package")
    missing.chain(missing.trigger(), missing.action("Missing_Package.Action_Do_nothing", name="GONE"))
    caller = FlowBuilder("caller-missing")
    ex = caller.action("Action_Execute_Flow", name="call", ThisFlow=0, flowID="missing-package",
                       WhichTrigger="Default", triggerID="", SendLocalVars=0, WaitToFinish=1, ReturnVariables=0,
                       SkipDisabled=0)
    caller.chain(caller.trigger(), ex, caller.action("Action_Do_nothing", name="AFTER"))
    ids = [flows.add(missing), flows.add(caller)]
    flows.start()
    flows.enable(ids[0])
    mark = flows.mark()
    run = flows.run(ids[1], timeout=scaled(30))
    assert run.reason == "exception", (run.reason, run.steps)            # the caller's element ends with the outcome
    assert run.exceptions and run.exceptions[0].startswith("The called flow 'missing-package' ended with an exception"),         run.exceptions
    ends = flows.ended(ids[0], mark, count=1)
    assert [e["reason"] for e in ends] == ["exception"], ends
    assert "AFTER" not in run.names
    assert (flows.datadir / "Flows" / "missing-package.json").exists()


def test_14_global_and_static_variables_survive_two_runs(flows):
    """A global variable (preset) and a static variable of the flow (preset) count up in each run: 6, 7 and 1, 2."""
    fb = FlowBuilder("globals-static")
    inc_g = fb.action("Action_New_variable", Varname="global_g", VarValue="global_g + 1", expression="Expression")
    inc_s = fb.action("Action_New_variable", Varname="static_n", VarValue="static_n + 1", expression="Expression")
    fb.chain(fb.trigger(), inc_g, inc_s, fb.probe("global_g", "static_n"))
    flow_id = flows.add(fb)
    flows.preset_var("global_g", "5")
    flows.preset_var("static_n", "0", flow_id=flow_id)
    flows.start()
    flows.enable(flow_id)
    first = flows.run(flow_id, timeout=scaled(30))
    assert finished(first)
    seen_first = (first.probe("global_g").text, first.probe("static_n").text)     # a run clears the probes
    second = flows.run(flow_id, timeout=scaled(30))
    assert finished(second)
    assert seen_first == ("6", "1")
    assert (second.probe("global_g").text, second.probe("static_n").text) == ("7", "2")


def test_15_global_and_static_variables_survive_an_engine_restart(flows):
    """The same flow after a restart of the session (the engine loads the variables again): the counts go on at 8 and 3."""
    fb = FlowBuilder("globals-restart")
    inc_g = fb.action("Action_New_variable", Varname="global_g", VarValue="global_g + 1", expression="Expression")
    inc_s = fb.action("Action_New_variable", Varname="static_n", VarValue="static_n + 1", expression="Expression")
    fb.chain(fb.trigger(), inc_g, inc_s, fb.probe("global_g", "static_n"))
    flow_id = flows.add(fb)
    flows.preset_var("global_g", "5")
    flows.preset_var("static_n", "0", flow_id=flow_id)
    flows.start()
    flows.enable(flow_id)
    assert finished(flows.run(flow_id, timeout=scaled(30)))
    assert finished(flows.run(flow_id, timeout=scaled(30)))
    flows.stop()
    flows.start()
    flows.enable(flow_id)
    third = flows.run(flow_id, timeout=scaled(30))
    assert finished(third)
    assert (third.probe("global_g").text, third.probe("static_n").text) == ("8", "3")


def test_16_a_chain_of_checks_uses_the_core_set_across_packages(flows):
    """A chain of checks with a number, a text and a missing variable in the compatibility mode."""
    fb = check_flow("chain-mixed", [
        ("x = 5", True), ('name = "Paul"', True), ("x + 1 = 6", True), ("count < 3", False)],
        strict=None, setup=[("x", 5), ("name", "Paul")])
    run = run_all(flows, [fb])[0]
    assert check_run(run), run.names


# --- the table of the other flows -------------------------------------------------------------------------------------
def test_pending_flows_list_the_elements_that_are_still_missing():
    """The table PENDING equals the element classes of the 13 remaining "Automatic tests" flows that have no registered
    element file in src/elements. A class that arrives with S0003 or S0008 must leave the table, and a flow that
    becomes green moves to the corpus (WI-0057 task 3)."""
    registered = {os.path.basename(p)[:-4].lower()
                  for p in glob.glob(str(ROOT / "src" / "elements" / "Default" / "*" / "*.ahk"))}
    for stem, entry in PENDING.items():
        data = json.loads((V1 / (stem + ".json")).read_text(encoding="utf-8-sig"))
        assert data["category"] == "Automatic tests", stem
        classes = {e["class"] for e in data["allElements"].values()}
        missing = {c for c in classes if c.lower() not in registered}
        table = {c for c in entry["missing"]}
        assert {c.lower() for c in missing} == {c.lower() for c in table}, (stem, sorted(missing), sorted(table))
