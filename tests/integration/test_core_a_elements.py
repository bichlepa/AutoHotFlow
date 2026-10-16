"""WI-0052: end-to-end tests of the core set A elements: variables and conditions, with the flow builder.

Every test builds small flows, adds them all to the data folder of one session and runs them one after the other, so a
test group costs one start of the session (`support/coreflows.py`). The result of a condition is read from the path
(the markers `YES` and `NO`). Where an expression is involved the flows run in strict and in compatibility mode (E0034).

The tables of Variable_content_is and Number_is are those of the v1 example flows (the connections of "variable test"
and "numbers" encode the expected results); the two flows themselves run at the end of the file. The trace points are
in test_core_a_trace_points.py.
"""

import json
from pathlib import Path

import pytest

from support.coreflows import MODES, answer, branch, condition_flow, run_all, setvar
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)

ROOT = Path(__file__).resolve().parents[2]
V1_EXAMPLES = ROOT / "tests" / "data" / "flows" / "v1_examples"


# --- helpers -------------------------------------------------------------------------------------------------------
def new_variable_flow(name, strict=True, setup=None, probe=("x",), **pars):
    """trigger -> [setup] -> Action_New_variable -> probe of the variables `probe`."""
    fb = FlowBuilder(name, strict_types=strict)
    prev = fb.trigger()
    if setup:
        step = fb.action("Action_TestSetVar", Steps=json.dumps(setup))
        fb.connect(prev, step)
        prev = step
    new = fb.action("Action_New_variable", **pars)
    fb.connect(prev, new)
    if probe:
        fb.connect(new, fb.probe(*probe))
    return fb


# --- Action_Do_nothing and Condition_Do_nothing ------------------------------------------------------------------------
def test_condition_do_nothing_finishes_with_the_chosen_result(flows):
    values = ["Yes", "No", "Exception", None, "garbage"]       # None: no parameter in the flow, the default is Yes
    runs = run_all(flows, [condition_flow("cdn%d" % i, "Condition_Do_nothing", **({} if v is None else {"executionResult": v}))
                           for i, v in enumerate(values)])
    assert [answer(r) for r in runs] == ["YES", "NO", "EXCEPTION", "YES", "EXCEPTION"]
    assert runs[2].state_of("Condition_Do_nothing") == ["exception"]


def test_action_do_nothing_finishes_with_normal_or_exception(flows):
    builders = []
    for i, value in enumerate(["Normal", "Exception", None]):
        fb = FlowBuilder("adn%d" % i)
        a = fb.action("Action_Do_nothing", **({} if value is None else {"executionResult": value}))
        fb.chain(fb.trigger(), a, fb.action("Action_Do_nothing", name="AFTER"))
        builders.append(fb)
    normal, exception, default = run_all(flows, builders)
    assert normal.reason == "finished" and normal.names == ["Trigger_Manual", "Action_Do_nothing", "AFTER"]
    assert exception.names == ["Trigger_Manual", "Action_Do_nothing"] and exception.state_of("Action_Do_nothing") == ["exception"]
    assert default.names[-1] == "AFTER"


# --- Condition_Expression ----------------------------------------------------------------------------------------
# (expression, variables to set, answer in strict mode, answer in compatibility mode)
EXPRESSIONS = [
    ("1", None, "YES", "YES"),
    ("0", None, "NO", "NO"),
    ('""', None, "NO", "NO"),                       # the empty text is false
    ('"0"', None, "NO", "NO"),                      # a text that is the number 0 is false (AutoHotkey v2)
    ('"0.0"', None, "NO", "NO"),
    ('"abc"', None, "YES", "YES"),
    ("0.5", None, "YES", "YES"),
    ("x = 1", [setvar("x", 1)], "YES", "YES"),
    ("x = 1", [setvar("x", 2)], "NO", "NO"),
    ("x", None, "NO", "NO"),                        # a variable that does not exist is empty: "no", not an error (help)
    ("x", [setvar("x", [1, 2])], "YES", "YES"),     # a list is true
    ("x > 3 && y < 4", [setvar("x", 5), setvar("y", 1)], "YES", "YES"),
    ("1 +", None, "EXCEPTION", "EXCEPTION"),        # not readable
    ("", None, "EXCEPTION", "EXCEPTION"),           # an empty expression is an error (WarnIfEmpty)
    ("1 / 0", None, "EXCEPTION", "NO"),             # a division by zero: exception in strict mode, empty text in compat
    ('"abc" < 3', None, "EXCEPTION", "NO"),         # a text that is no number in a comparison (E0030)
    ('x + 1', None, "EXCEPTION", "NO"),             # the empty text in a calculation: a type error (E0025)
]


@pytest.mark.slow
@pytest.mark.parametrize("mode,strict", MODES)
def test_condition_expression_decides_yes_or_no(flows, mode, strict):
    builders = [condition_flow("expr%d" % i, "Condition_Expression", strict=strict, setup=setup, Expression=text)
                for i, (text, setup, *_) in enumerate(EXPRESSIONS)]
    runs = run_all(flows, builders)
    got = [(text, answer(r)) for (text, *_), r in zip(EXPRESSIONS, runs)]
    want = [(text, strict_answer if strict else compat_answer) for text, _, strict_answer, compat_answer in EXPRESSIONS]
    assert got == want
    # the exceptions name the expression, the type errors of compatibility mode go to the log (f1)
    error_run = runs[12]
    assert "An error occured while parsing expression '1 +'" in error_run.exceptions[0]
    if not strict:
        assert any(e["level"] == "f1" for e in runs[14].log), runs[14].log


def test_condition_expression_a_flow_without_parameter_is_an_error(flows):
    fb = FlowBuilder("expr-missing")
    cond = fb.condition("Condition_Expression")
    fb.connect(fb.trigger(), cond)
    branch(fb, cond)
    run, = run_all(flows, [fb])
    assert answer(run) == "EXCEPTION"


# --- Action_New_variable ----------------------------------------------------------------------------------------------
@pytest.mark.slow
def test_new_variable_sets_texts_numbers_and_lists(flows):
    cases = [
        # (builder arguments, variable to look at, text, type)
        (dict(Varname="x", VarValue="hello", expression="String"), "x", "hello", "String"),
        (dict(Varname="x", VarValue="hello %who%", expression="String", setup=[setvar("who", "world")]),
         "x", "hello world", "String"),
        (dict(Varname="x", VarValue="2 + 3", expression="Expression"), "x", "5", "Integer"),
        (dict(Varname="x", VarValue="1 / 2", expression="Expression"), "x", "0.5", "Float"),
        (dict(Varname="x", VarValue='"a" . "b"', expression="Expression"), "x", "ab", "String"),
        (dict(Varname="x", VarValue="1 + 1"), "x", "1 + 1", "String"),                  # no content selected: a text
        (dict(Varname="x", VarValue="y", expression="Expression", setup=[setvar("y", [1, 2])]), "x", "[1,2]", "Map"),
        (dict(Varname="X", VarValue="a", expression="String", setup=[setvar("x", "old")]), "x", "a", "String"),   # no case
        (dict(Varname="x", VarValue="", expression="String"), "x", "", "String"),
        (dict(Varname="x", VarValue="line 1\nline 2", expression="String"), "x", "line 1\nline 2", "String"),
    ]
    builders = []
    for i, (kw, *_rest) in enumerate(cases):
        kw = dict(kw)
        setup = kw.pop("setup", None)
        builders.append(new_variable_flow("newvar%d" % i, setup=setup, **kw))
    for (kw, name, text, kind), run in zip(cases, run_all(flows, builders)):
        assert run.reason == "finished" and not run.exceptions, (kw, run.exceptions)
        probe = run.seen[name]
        assert (probe.text, probe.type, probe.location) == (text, kind, "instance"), kw


@pytest.mark.slow
def test_new_variable_only_if_not_exist(flows):
    setup = [setvar("x", "old")]
    builders = [
        new_variable_flow("nv-exists", setup=setup, Varname="x", VarValue="new", expression="String", onlyIfNotExist="1"),
        new_variable_flow("nv-missing", Varname="x", VarValue="new", expression="String", onlyIfNotExist="1"),
        new_variable_flow("nv-off", setup=setup, Varname="x", VarValue="new", expression="String", onlyIfNotExist="0"),
        new_variable_flow("nv-int", setup=setup, Varname="x", VarValue="new", expression="String", onlyIfNotExist=1),
        # any scope counts: a built-in variable exists
        new_variable_flow("nv-builtin", Varname="a_flowName", VarValue="new", expression="String", onlyIfNotExist="1",
                          probe=("a_flowName",)),
    ]
    exists, missing, off, as_int, builtin = run_all(flows, builders)
    assert exists.seen["x"].text == "old" and missing.seen["x"].text == "new"
    assert off.seen["x"].text == "new" and as_int.seen["x"].text == "old"
    assert builtin.reason == "finished" and builtin.seen["a_flowName"].text == "nv-builtin"


@pytest.mark.slow
def test_new_variable_scopes_and_invalid_names(flows):
    builders = [
        new_variable_flow("nv-global", Varname="global_g", VarValue="gv", expression="String", probe=("global_g",)),
        new_variable_flow("nv-static", Varname="static_s", VarValue="sv", expression="String", probe=("static_s",)),
        new_variable_flow("nv-aname", Varname="A_Index", VarValue="1", expression="String", probe=None),
        new_variable_flow("nv-digit", Varname="1abc", VarValue="1", expression="String", probe=None),
        new_variable_flow("nv-space", Varname="a b", VarValue="1", expression="String", probe=None),
        new_variable_flow("nv-empty", Varname="", VarValue="1", expression="String", probe=None),
        new_variable_flow("nv-badexpr", Varname="x", VarValue="1 +", expression="Expression", probe=None),
        new_variable_flow("nv-nameexpr", setup=[setvar("n", "viaVar")], Varname="%n%", VarValue="1", expression="String",
                          probe=("viaVar",)),
    ]
    g, s, a_name, digit, space, empty, bad_expr, via = run_all(flows, builders)
    assert g.seen["global_g"].location == "global" and s.seen["static_s"].location == "static"
    assert flows.wait_var("global_g", lambda p: p[1] == "gv") == ("normal", "gv")
    for run in (a_name, digit, space, empty, bad_expr):
        assert run.reason == "exception" and len(run.exceptions) == 1
    assert "could not be set" in a_name.exceptions[0] or "not valid" in a_name.exceptions[0]
    assert "not valid" in digit.exceptions[0] and "not valid" in space.exceptions[0]
    assert "is not valid" in empty.exceptions[0] or "empty" in empty.exceptions[0]
    assert "An error occured while parsing expression" in bad_expr.exceptions[0]
    assert via.seen["viaVar"].text == "1"


@pytest.mark.slow
def test_new_variable_type_errors_in_strict_and_compatibility_mode(flows):
    strict, compat = run_all(flows, [
        new_variable_flow("nv-strict", strict=True, Varname="x", VarValue='"a" + 1', expression="Expression"),
        new_variable_flow("nv-compat", strict=None, Varname="x", VarValue='"a" + 1', expression="Expression"),
    ])
    assert strict.reason == "exception" and "Expected a Number but got a String" in strict.exceptions[0]
    assert compat.reason == "finished" and compat.seen["x"].text == ""


# --- Condition_Variable_content_is ---------------------------------------------------------------------------------------
TYPES = ["object", "time", "number", "integer", "float", "digit", "xdigit", "alnum", "alpha", "upper", "lower", "space"]
# value -> the types that are true. The cases are those of the v1 flow "variable test" (the connections of the flow
# encode the answers; a type that the flow does not ask for is left to the help text: the empty text is upper and lower).
CONTENT_TABLE = [
    ("myValue", {"alnum", "alpha"}),
    ("myvalue", {"alnum", "alpha", "lower"}),
    ("MYVALUE", {"alnum", "alpha", "upper"}),
    ("myValue123", {"alnum"}),
    ("123", {"alnum", "number", "integer", "digit", "xdigit"}),
    ("123.45", {"number", "float"}),
    ("0x12abc", {"number", "xdigit", "alnum", "integer"}),
    ("2015", {"number", "xdigit", "alnum", "integer", "time", "digit"}),
    ("", {"xdigit", "alnum", "digit", "space", "alpha", "upper", "lower"}),
    (" \t", {"space"}),
]


def content_flow(name, value=None, steps=None, strict=True, **pars):
    """trigger -> set the variable myVariable -> the condition for each of the 12 types in a row, each followed by a
    marker 'Y:<type>' or 'N:<type>' that leads on to the next condition."""
    fb = FlowBuilder(name, strict_types=strict)
    prev = fb.trigger()
    setup = steps if steps is not None else [setvar("myVariable", value)]
    step = fb.action("Action_TestSetVar", Steps=json.dumps(setup))
    fb.connect(prev, step)
    prev = step
    for kind in TYPES:
        cond = fb.condition("Condition_Variable_content_is", varname="myVariable", varnameContent="VariableName",
                            variableContentType=kind, **pars)
        yes, no = fb.action("Action_Do_nothing", name="Y:" + kind), fb.action("Action_Do_nothing", name="N:" + kind)
        fb.connect(prev, cond)
        fb.connect(cond, yes, "yes")
        fb.connect(cond, no, "no")
        join = fb.action("Action_Do_nothing", name="J:" + kind)
        fb.connect(yes, join)
        fb.connect(no, join)
        prev = join
    return fb


def true_types(run):
    return {n[2:] for n in run.names if n.startswith("Y:")}


@pytest.mark.slow
def test_variable_content_is_every_type_for_every_value(flows):
    builders = [content_flow("content%d" % i, value) for i, (value, _) in enumerate(CONTENT_TABLE)]
    builders.append(content_flow("content-list", steps=[setvar("myVariable", [1, 2])]))
    builders.append(content_flow("content-emptylist", steps=[setvar("myVariable", {})]))
    builders.append(content_flow("content-int", steps=[setvar("myVariable", 5)]))
    builders.append(content_flow("content-float", steps=[setvar("myVariable", 5.5)]))
    builders.append(content_flow("content-missing", steps=[setvar("other", 1)]))
    runs = run_all(flows, builders)
    for (value, expected), run in zip(CONTENT_TABLE, runs):
        assert run.reason == "finished" and not run.exceptions, (value, run.exceptions)
        assert true_types(run) == expected, repr(value)
        assert len([n for n in run.names if n[:2] in ("Y:", "N:")]) == 12
    lst, empty_list, integer, number, missing = runs[len(CONTENT_TABLE):]
    assert true_types(lst) == {"object"} and true_types(empty_list) == {"object"}
    assert true_types(integer) == {"number", "integer", "digit", "xdigit", "alnum"}
    assert true_types(number) == {"number", "float"}
    assert true_types(missing) == {"xdigit", "alnum", "digit", "space", "alpha", "upper", "lower"}   # the empty text


@pytest.mark.slow
def test_variable_content_is_expression_mode_and_errors(flows):
    def one(name, text, kind, content="Expression", setup=None, strict=True):
        extra = {} if content is None else {"varnameContent": content}      # None: a flow without the parameter
        return condition_flow(name, "Condition_Variable_content_is", strict=strict, setup=setup, varname=text,
                              variableContentType=kind, **extra)
    builders = [
        one("ce-number", "1 + 1", "integer"),
        one("ce-float", "1 / 4", "float"),
        one("ce-text", '"abc"', "alpha"),
        one("ce-list", "x", "object", setup=[setvar("x", [1])]),
        one("ce-notlist", '"abc"', "object"),
        one("ce-name", "myName", "alpha", content="VariableName", setup=[setvar("myName", "abc")]),
        one("ce-substituted", "%n%", "digit", content="VariableName", setup=[setvar("n", "v"), setvar("v", "123")]),
        one("ce-unknown-type", "x", "banana", content="VariableName"),
        one("ce-bad-name", "1x", "alpha", content="VariableName"),
        one("ce-bad-expr", "1 +", "alpha"),
        one("ce-default-content", "x", "digit", content=None, setup=[setvar("x", "12")]),
    ]
    runs = run_all(flows, builders)
    assert [answer(r) for r in runs] == ["YES", "YES", "YES", "YES", "NO", "YES", "YES", "EXCEPTION", "EXCEPTION",
                                         "EXCEPTION", "YES"]


# --- Condition_NumberIs ---------------------------------------------------------------------------------------------------
# (input, expected, absolute, relative, answer): the checks of the v1 flow "numbers" (the answers are its connections)
NUMBER_TABLE = [
    ("5", "5", "0", "0", "YES"),
    ("5.000000001", "5", "0", "0", "NO"),
    ("5.000000001", "5", "0", "0.0001", "YES"),
    ("5.000500001", "5", "0", "0.0001", "NO"),           # relative to the EXPECTED number (the help says the input; M-0054)
    ("4.9995", "5", "0", "0.0001", "YES"),
    ("4.99949999", "5", "0", "0.0001", "NO"),
    ("4.9995", "5", "0.0005", "0", "YES"),
    ("4.9994999", "5", "0.0005", "0", "NO"),
    ("4.9990", "5", "0.0005", "0.0001", "YES"),
    ("5.001", "5", "0.0005", "0.0001", "YES"),
    ("5.0010001", "5", "0.0005", "0.0001", "NO"),
    ("-5.001", "-5", "0.0005", "0.0001", "YES"),
    ("-5.0010001", "-5", "0.0005", "0.0001", "NO"),
    ("5", "5", "", "", "YES"),                           # empty differences are 0
    ("1/3", "0.3333333", "0", "0.001", "YES"),           # expressions
    ("x * 2", "10", "0", "0", "YES"),
]


@pytest.mark.slow
@pytest.mark.parametrize("mode,strict", MODES)
def test_number_is_with_absolute_and_relative_difference(flows, mode, strict):
    builders = [condition_flow("num%d" % i, "Condition_NumberIs", strict=strict, setup=[setvar("x", 5)], expression=a,
                               expectedNumber=b, absoluteDeviation=c, relativeDeviation=d)
                for i, (a, b, c, d, _) in enumerate(NUMBER_TABLE)]
    runs = run_all(flows, builders)
    assert [(row[:4], answer(r)) for row, r in zip(NUMBER_TABLE, runs)] == [(row[:4], row[4]) for row in NUMBER_TABLE]


@pytest.mark.slow
def test_number_is_defaults_and_errors(flows):
    builders = [
        condition_flow("num-defaults", "Condition_NumberIs"),                      # 5.0001 against 5, relative 0.01
        condition_flow("num-text", "Condition_NumberIs", expression='"abc"', expectedNumber="5",
                       absoluteDeviation="0", relativeDeviation="0"),
        condition_flow("num-empty", "Condition_NumberIs", expression="", expectedNumber="5",
                       absoluteDeviation="0", relativeDeviation="0"),
        condition_flow("num-negative-dev", "Condition_NumberIs", expression="5", expectedNumber="5",
                       absoluteDeviation="-1", relativeDeviation="0"),
        condition_flow("num-numeric-text", "Condition_NumberIs", expression='"5.0"', expectedNumber="5",
                       absoluteDeviation="0", relativeDeviation="0"),
    ]
    defaults, text, empty, negative, numeric_text = run_all(flows, builders)
    assert answer(defaults) == "YES"
    assert answer(text) == "EXCEPTION" and "is not a number" in text.exceptions[0]
    assert answer(empty) == "EXCEPTION" and "is empty" in empty.exceptions[0]
    assert answer(negative) == "EXCEPTION" and "positive number or zero" in negative.exceptions[0]
    assert answer(numeric_text) == "YES"


# --- Condition_Variable_Is_Empty ---------------------------------------------------------------------------------------------
@pytest.mark.slow
def test_variable_is_empty(flows):
    cases = [
        ("unset", None, "YES"),
        ("empty", [setvar("v", "")], "YES"),
        ("zero", [setvar("v", 0)], "NO"),
        ("text", [setvar("v", "x")], "NO"),
        ("space", [setvar("v", " ")], "NO"),
        ("list", [setvar("v", [1])], "NO"),
        ("emptylist", [setvar("v", {})], "NO"),
        ("number", [setvar("v", 12.5)], "NO"),
    ]
    builders = [condition_flow("empty-" + name, "Condition_Variable_Is_Empty", setup=setup, VarName="v")
                for name, setup, _ in cases]
    builders += [
        condition_flow("empty-global", "Condition_Variable_Is_Empty", VarName="global_nothing"),
        condition_flow("empty-badname", "Condition_Variable_Is_Empty", VarName="a b"),
        condition_flow("empty-noname", "Condition_Variable_Is_Empty", VarName=""),
        condition_flow("empty-substituted", "Condition_Variable_Is_Empty", setup=[setvar("n", "v"), setvar("v", "x")],
                       VarName="%n%"),
        condition_flow("empty-builtin", "Condition_Variable_Is_Empty", VarName="a_flowName"),
    ]
    runs = run_all(flows, builders)
    assert [answer(r) for r in runs[:len(cases)]] == [c[2] for c in cases]
    assert [answer(r) for r in runs[len(cases):]] == ["YES", "EXCEPTION", "EXCEPTION", "NO", "NO"]


# --- the v1 example flows ---------------------------------------------------------------------------------------------------
def test_the_v1_flow_variable_test_runs_up_to_the_first_result_list(flows):
    """"variable test" (Flow 1010290492), as v1 saved it (the expressions are converted on load). The trigger "variable
    content test" runs New_variable, 100 Variable_content_is checks, Action_New_List and more up to the first
    Action_Add_To_List that collects the result in `static_results`; the trigger "basic variables test" runs
    New_variable, Variable_is_empty and Condition_Expression up to that element. Every check before it must have
    answered as the connections of the flow expect, otherwise the instance would end earlier without a matching
    connection. The element writes `%a_manualTriggerID%`: the engine sets it at every start of the trigger through its
    TriggerVariables (WI-0062, M-0069), so both runs go on without an exception. The list elements themselves ran before
    (WI-0053)."""
    flow_id = flows.add_file(V1_EXAMPLES / "Flow 1010290492.json")
    flows.start()
    content = flows.run(flow_id, trigger="element0000000039")
    basic = flows.run(flow_id, trigger="element0000000002")
    assert content.path[-1] == "element0000000098" and len(content.path) == 113
    assert "element0000000434" in content.path                  # the first Action_New_List
    assert content.exceptions == [] and basic.exceptions == []
    assert basic.path[-1] == "element0000000035" and len(basic.path) == 10
    assert content.reason == basic.reason == "finished"


def test_the_v1_flow_numbers_runs_its_number_is_checks(flows):
    """"numbers" (Flow 1087828277): the trigger at element 234 runs the 14 Number is checks of the flow (the answers are
    its connections: a wrong one ends the instance before the last element) and counts the run in a static variable."""
    flow_id = flows.add_file(V1_EXAMPLES / "Flow 1087828277.json")
    flows.start()
    run = flows.run(flow_id, trigger="element0000000234")
    assert run.reason == "finished" and not run.exceptions, (run.reason, run.exceptions)
    assert run.path[0] == "element0000000234" and run.path[-1] == "element0000000261"
    assert len(run.path) == 1 + 14 + 1, run.path          # the trigger, the 14 checks, the counter
