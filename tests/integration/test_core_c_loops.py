"""WI-0054: end-to-end tests of the loops of the core set C with the flow builder: Loop_SimpleLoop, Loop_Condition,
Loop_Work_through_a_list and Loop_Parse_A_String.

A flow is: trigger, optional setvar steps (Action_TestSetVar), the loop, a body that writes a trace point log line per
pass, and the marker AFTER behind the tail of the loop. The passes are read from the log: a body line is
`P <variables>` (for example `P 3` for the third pass); the loop variables are read inside the body with %name%.
The probe element shows what is visible after the loop. Several flows go into one session (`support/coreflows.py`).
"""

import json
import time
from pathlib import Path

import pytest

from support.coreflows import run_all, setvar
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.timing import scaled

ROOT = Path(__file__).resolve().parents[2]
V1_EXAMPLES = ROOT / "tests" / "data" / "flows" / "v1_examples"


# --- builders --------------------------------------------------------------------------------------------------------
def tp(fb, tag, text, **pars):
    """A trace point that logs `text` (with %var%) at level f0. Its log line is `<text>`; the step is named `TP <tag>`."""
    return fb.action("Action_Trace_Point", ID=tag, LogMessage=text, StopCondition="", name="TP " + tag, **pars)


def note(fb, tag, text):
    """Appends `text` (with %var%) to the list `seq` of the instance: unlike the log, a list keeps the order of the lines
    of different elements (the log of an element is written in a batch of its own)."""
    return fb.action("Action_Add_To_List", Varname="seq", NumberOfElements="One", VarValue=text, WhichPosition="Last",
                     name="TP " + tag)


def seq_of(run):
    """The list `seq` as the probe at the end of the flow saw it (the flow must have finished)."""
    probe = run.seen["seq"]
    return [] if probe.type == "<missing>" else json.loads(probe.text)


def after(fb):
    return fb.action("Action_Do_nothing", name="AFTER")


def start(fb, setup):
    prev = fb.trigger()
    if setup:
        step = fb.action("Action_TestSetVar", Steps=json.dumps(setup))
        fb.connect(prev, step)
        prev = step
    return prev


def finish(fb, loop, probe):
    """loop tail -> probe (the variables `probe` and the list seq) -> AFTER"""
    end = after(fb)
    p = fb.probe("seq", *probe)
    fb.connect(loop, p, "tail")
    fb.connect(p, end)


def loop_flow(name, cls, setup=None, body="P %a_index%", break_at=None, probe=(), **pars):
    """trigger -> [setup] -> loop; head -> [break condition `a_index = N`: yes -> break part of the loop] -> trace point
    `body` -> tail of the loop; tail -> [probe] -> AFTER."""
    fb = FlowBuilder(name)
    loop = fb.loop(cls, **pars)
    fb.connect(start(fb, setup), loop)
    point = tp(fb, "p", body)
    if break_at is None:
        fb.connect(loop, point, "head")
    else:
        cond = fb.condition("Condition_Expression", Expression="a_index = %d" % break_at)
        fb.connect(loop, cond, "head")
        fb.connect(cond, loop, "yes", into="break")
        fb.connect(cond, point, "no")
    fb.connect(point, loop, into="tail")
    finish(fb, loop, probe)
    return fb


def passes(run, tag="P"):
    """The log lines of the body in order, without the tag: '3' for `P 3`."""
    return [e["text"][len(tag) + 1:] for e in run.log if e["level"] == "f0" and e["text"].startswith(tag + " ")]


def finished(run):
    assert run.reason == "finished", (run.reason, run.exceptions)
    assert not run.exceptions, run.exceptions
    assert run.names[-1] == "AFTER", run.names[-5:]


def gone(run, *names):
    """The loop variables are not visible after the loop (the probe saw nothing)."""
    for n in names:
        assert run.seen[n].type == "<missing>", (n, run.seen[n])


LOOP_VARS = ("a_index", "a_loopkey", "a_loopfield")

# One loop of every class that makes the passes P 1..3, and what the body logs.
LOOPS = {
    "simple": dict(cls="Loop_SimpleLoop", pars=dict(Infinite=0, repeatCount=3), body="P %a_index%",
                   want=["1", "2", "3"]),
    "condition": dict(cls="Loop_Condition", pars=dict(Expression="a_index <= 3", EvaluateOnFirstIteration=1),
                      body="P %a_index%", want=["1", "2", "3"]),
    "list": dict(cls="Loop_Work_through_a_list", setup=[setvar("l", ["a", "b", "c"])], pars=dict(VarValue="l"),
                 body="P %a_index% %a_loopkey% %a_loopfield%", want=["1 1 a", "2 2 b", "3 3 c"]),
    "parse": dict(cls="Loop_Parse_A_String", pars=dict(VarValue="a,b,c", Delimiters=",", OmitChars=""),
                  body="P %a_index% %a_loopfield%", want=["1 a", "2 b", "3 c"]),
}


def make(name, kind, **extra):
    spec = LOOPS[kind]
    args = dict(setup=spec.get("setup"), body=spec["body"], **spec["pars"])
    args.update(extra)
    return loop_flow("%s-%s" % (name, kind), spec["cls"], **args)


# --- passes, break, loop variables -------------------------------------------------------------------------------------
def test_every_loop_makes_its_passes_and_removes_its_variables(flows):
    builders = [make("all", k, probe=LOOP_VARS) for k in LOOPS]
    for k, run in zip(LOOPS, run_all(flows, builders)):
        finished(run)
        assert passes(run) == LOOPS[k]["want"], k
        gone(run, *LOOP_VARS)


@pytest.mark.slow
def test_break_in_the_first_a_middle_and_the_last_pass(flows):
    keys = [(k, n) for k in LOOPS for n in (1, 2, 3)]
    builders = [make("brk%d" % n, k, break_at=n, probe=LOOP_VARS) for k, n in keys]
    for (k, n), run in zip(keys, run_all(flows, builders)):
        finished(run)
        assert passes(run) == LOOPS[k]["want"][:n - 1], (k, n)       # the pass n only checks the break condition
        gone(run, *LOOP_VARS)


# --- Loop_SimpleLoop ----------------------------------------------------------------------------------------------------
SIMPLE = [
    # name, setup, parameters, expected passes ("EXC": the loop ends with an exception)
    ("zero", None, dict(Infinite=0, repeatCount=0), []),
    ("one", None, dict(Infinite=0, repeatCount=1), ["1"]),
    ("negative", None, dict(Infinite=0, repeatCount=-4), []),
    ("expression", [setvar("n", 2)], dict(Infinite=0, repeatCount="n + 1"), ["1", "2", "3"]),
    ("float", None, dict(Infinite=0, repeatCount="2.5"), ["1", "2"]),                  # 3 > 2.5
    ("text-number", None, dict(Infinite=0, repeatCount="3"), ["1", "2", "3"]),
    ("not-a-number", None, dict(Infinite=0, repeatCount='"abc"'), "EXC"),
    ("empty", None, dict(Infinite=0, repeatCount=""), "EXC"),
    ("missing-variable", None, dict(Infinite=0, repeatCount="nothere"), "EXC"),      # the empty text is no number
    ("flag-as-text", None, dict(Infinite="0", repeatCount=2), ["1", "2"]),            # v1 files hold '0' and '1' as texts
    ("v1-defaults", None, {}, ["1", "2", "3", "4", "5"]),                              # a flow file without parameters
]


@pytest.mark.slow
def test_simple_loop_counts(flows):
    builders = [loop_flow("simple-" + name, "Loop_SimpleLoop", setup=setup, **pars) for name, setup, pars, _ in SIMPLE]
    for (name, _, _, want), run in zip(SIMPLE, run_all(flows, builders)):
        if want == "EXC":
            assert run.reason == "exception" and run.exceptions, (name, run.reason, run.names)
            assert "AFTER" not in run.names, name
        else:
            finished(run)
            assert passes(run) == want, name


@pytest.mark.slow
def test_simple_loop_infinite_ignores_the_count_and_ends_by_break(flows):
    builders = [loop_flow("inf-%s" % c, "Loop_SimpleLoop", break_at=4, Infinite=i, repeatCount=c)
                for c, i in (("", 1), (2, "1"), ("nonsense +", 1))]
    for run in run_all(flows, builders):
        finished(run)
        assert passes(run) == ["1", "2", "3"]


# --- Loop_Condition ------------------------------------------------------------------------------------------------------
CONDITION = [
    ("first-checked", None, dict(Expression="a_index < 1", EvaluateOnFirstIteration=1), []),
    ("first-not-checked", None, dict(Expression="a_index < 1", EvaluateOnFirstIteration=0), ["1"]),
    ("a_index-is-1-at-the-first-check", None, dict(Expression="a_index = 1 and a_index < 2", EvaluateOnFirstIteration=1),
     ["1"]),
    ("ten", None, dict(Expression="a_index <= 10", EvaluateOnFirstIteration=1), [str(i) for i in range(1, 11)]),
    ("variable-false", [setvar("go", 0)], dict(Expression="go", EvaluateOnFirstIteration=1), []),
    ("text-zero-false", [setvar("go", "0")], dict(Expression="go", EvaluateOnFirstIteration=1), []),
    ("empty-result-is-false", None, dict(Expression="nothere", EvaluateOnFirstIteration=1), []),
    ("empty-result-in-a-later-pass", [setvar("go", 1)], dict(Expression="a_index < 2 and go", EvaluateOnFirstIteration=1),
     ["1"]),
    ("default-checkbox", None, dict(Expression="a_index <= 2"), ["1", "2"]),           # missing: checked (the default)
    ("empty-text", None, dict(Expression="", EvaluateOnFirstIteration=1), "EXC"),
    ("empty-text-not-checked", None, dict(Expression="", EvaluateOnFirstIteration=0), "EXC"),   # the second check fails
    ("unreadable", None, dict(Expression="1 +", EvaluateOnFirstIteration=1), "EXC"),
    ("type-error", None, dict(Expression='"a" + 1', EvaluateOnFirstIteration=1), "EXC"),        # strict mode
]


@pytest.mark.slow
def test_condition_loop(flows):
    builders = [loop_flow("cond-" + name, "Loop_Condition", setup=setup, **pars) for name, setup, pars, _ in CONDITION]
    for (name, _, _, want), run in zip(CONDITION, run_all(flows, builders)):
        if want == "EXC":
            assert run.reason == "exception" and run.exceptions, (name, run.reason, run.names)
        else:
            finished(run)
            assert passes(run) == want, name


def test_condition_loop_converts_the_v1_text_on_load(flows):
    """A flow in the format of v1 (no formatVersion): the concatenation dot of v1 (`"a"."b"`) is converted when the flow
    is loaded, because Parameters() names the content type Expression. The same text in a flow of the new format is
    not converted and does not parse."""
    def build(name, v2):
        fb = FlowBuilder(name, v2=v2)
        loop = fb.loop("Loop_Condition", Expression='a_index <= 2 and "a"."b" = "ab"', EvaluateOnFirstIteration="1")
        point = tp(fb, "p", "P %a_index%")
        fb.connect(start(fb, None), loop)
        fb.connect(loop, point, "head")
        fb.connect(point, loop, into="tail")
        fb.connect(loop, after(fb), "tail")
        return fb
    converted, plain = run_all(flows, [build("cond-v1", False), build("cond-v2", True)])
    finished(converted)
    assert passes(converted) == ["1", "2"]
    assert plain.reason == "exception" and "An error occured while parsing expression" in plain.exceptions[0]


# --- Loop_Work_through_a_list --------------------------------------------------------------------------------------------
LIST = [
    ("plain", [setvar("l", ["a", "b"])], "l", ["1 1 a", "2 2 b"]),
    ("empty", [setvar("l", {})], "l", []),
    ("keys-in-list-order", [setvar("l", {"b": "B", "a": "A", "2": "two", "1": "one"})], "l",
     ["1 1 one", "2 2 two", "3 a A", "4 b B"]),                       # Integer keys ascending, then the texts
    ("gaps", [setvar("l", {"3": "c", "7": "g"})], "l", ["1 3 c", "2 7 g"]),
    ("name-ignores-case", [setvar("MyList", ["x"])], "mylist", ["1 1 x"]),
    ("numbers", [setvar("l", [10, 2.5])], "l", ["1 1 10", "2 2 2.5"]),
    ("not-a-list", [setvar("l", "text")], "l", "EXC"),
    ("empty-variable", [setvar("l", "")], "l", "EXC"),
    ("missing", None, "nothere", "EXC"),
    ("empty-name", None, "", "EXC"),
]


@pytest.mark.slow
def test_list_loop(flows):
    builders = [loop_flow("list-" + name, "Loop_Work_through_a_list", setup=setup,
                          body="P %a_index% %a_loopkey% %a_loopfield%", VarValue=var) for name, setup, var, _ in LIST]
    for (name, _, _, want), run in zip(LIST, run_all(flows, builders)):
        if want == "EXC":
            assert run.reason == "exception" and run.exceptions, (name, run.reason, run.names)
            if name != "empty-name":
                assert run.exceptions == ["Variable '%s' does not contain a list." % ("nothere" if name == "missing" else "l")]
        else:
            finished(run)
            assert passes(run) == want, name


@pytest.mark.slow
def test_list_loop_members_that_are_lists(flows):
    fb = loop_flow("list-nested", "Loop_Work_through_a_list", setup=[setvar("l", [["p", "q"], ["r"]])],
                   body="P %a_loopfield.1%", VarValue="l")
    run, = run_all(flows, [fb])
    finished(run)
    assert passes(run) == ["p", "r"]


def test_list_loop_works_through_the_copy_it_made_at_the_start(flows):
    """The body replaces the list and deletes it: the loop still makes the passes of the list it saw at the head."""
    fb = FlowBuilder("list-changed")
    loop = fb.loop("Loop_Work_through_a_list", VarValue="l")
    change = fb.action("Action_TestSetVar", Steps=json.dumps([setvar("l", ["z"]), setvar("other", 1)]))
    point = tp(fb, "p", "P %a_index% %a_loopfield%")
    fb.connect(start(fb, [setvar("l", ["a", "b", "c"])]), loop)
    fb.connect(loop, change, "head")
    fb.chain(change, point)
    fb.connect(point, loop, into="tail")
    finish(fb, loop, ("l",))
    run, = run_all(flows, [fb])
    finished(run)
    assert passes(run) == ["1 a", "2 b", "3 c"]
    assert json.loads(run.seen["l"].text) == ["z"]                    # the change itself took effect


@pytest.mark.slow
def test_list_loop_keeps_values_with_text_that_looks_like_a_path_or_number(flows):
    fb = loop_flow("list-odd", "Loop_Work_through_a_list", setup=[setvar("l", ["a.b", "", "0", "x y"])],
                   body="P %a_index% [%a_loopfield%]", VarValue="l")
    run, = run_all(flows, [fb])
    finished(run)
    assert passes(run) == ["1 [a.b]", "2 []", "3 [0]", "4 [x y]"]


# --- Loop_Parse_A_String --------------------------------------------------------------------------------------------------
PARSE = [
    # name, setup, parameters, expected fields
    ("comma", None, dict(VarValue="a,b,c", Delimiters=",", OmitChars=""), ["a", "b", "c"]),
    ("empty-fields", None, dict(VarValue="a,,b,", Delimiters=",", OmitChars=""), ["a", "", "b", ""]),
    ("several-delimiters", None, dict(VarValue="a;b,c d", Delimiters=";, ", OmitChars=""), ["a", "b", "c", "d"]),
    ("no-delimiter-in-the-text", None, dict(VarValue="abc", Delimiters=",", OmitChars=""), ["abc"]),
    ("empty-delimiters-split-every-character", None, dict(VarValue="abc", Delimiters="", OmitChars=""),
     ["a", "b", "c"]),
    ("delimiters-are-characters-not-a-text", None, dict(VarValue="a1b2c12d", Delimiters="12", OmitChars=""),
     ["a", "b", "c", "", "d"]),
    ("case-sensitive", None, dict(VarValue="AxaXb", Delimiters="a", OmitChars=""), ["Ax", "Xb"]),
    ("omit-chars", None, dict(VarValue=" a , b ,c ", Delimiters=",", OmitChars=" "), ["a", "b", "c"]),
    ("omit-chars-case-sensitive", None, dict(VarValue="xAx,Axa", Delimiters=",", OmitChars="a"), ["xAx", "Ax"]),
    ("omit-only-ends", None, dict(VarValue="a b, c d", Delimiters=",", OmitChars=" "), ["a b", "c d"]),
    ("omit-everything", None, dict(VarValue="a,   ,b", Delimiters=",", OmitChars=" "), ["a", "", "b"]),
    ("default-omit-chars", None, dict(VarValue=" a ,\tb\t", Delimiters=","), ["a", "b"]),     # %a_space%%a_tab%%a_lf%%a_cr%
    ("default-delimiter", None, dict(VarValue="a,b"), ["a", "b"]),
    ("lines", None, dict(VarValue="a\nb\r\nc", Delimiters="\n", OmitChars="\r"), ["a", "b", "c"]),
    ("lines-with-a-variable-for-the-delimiter", [setvar("sep", ";")], dict(VarValue="a;b", Delimiters="%sep%",
                                                                           OmitChars=""), ["a", "b"]),
    # as in v1 and AutoHotkey: the delimiter text "CSV" in any case is the CSV mode, not the characters C, S and V
    ("delimiter-text-upper-CSV-is-the-csv-mode", None, dict(VarValue='a,"b,c",d', Delimiters="CSV", OmitChars=""),
     ["a", "b,c", "d"]),
    ("delimiter-text-lower-csv-is-the-csv-mode", None, dict(VarValue='a,"b,c",d', Delimiters="csv", OmitChars=""),
     ["a", "b,c", "d"]),
    ("delimiter-text-with-the-letters-is-characters", None, dict(VarValue="acbsvd", Delimiters="cs", OmitChars=""),
     ["a", "b", "vd"]),
    ("variable-in-the-text", [setvar("a", 1), setvar("b", 2)], dict(VarValue="%a%,%b%", Delimiters=",", OmitChars=""),
     ["1", "2"]),
    ("expression-text", [setvar("s", "x,y")], dict(VarValue="s", Expression="Expression", Delimiters=",", OmitChars=""),
     ["x", "y"]),
    ("expression-number", None, dict(VarValue="12345", Expression="Expression", Delimiters="3", OmitChars=""),
     ["12", "45"]),
    ("expression-concatenation", [setvar("s", "k")], dict(VarValue='s . "-" . s', Expression="Expression",
                                                           Delimiters="-", OmitChars=""), ["k", "k"]),
    ("expression-object", [setvar("s", ["a"])], dict(VarValue="s", Expression="Expression"), "EXC"),
    ("expression-empty-result", None, dict(VarValue="nothere", Expression="Expression"), "EXC"),
    ("empty-input", None, dict(VarValue="", Delimiters=","), "EXC"),
    ("only-delimiters", None, dict(VarValue=",,", Delimiters=",", OmitChars=""), ["", "", ""]),
    ("unicode", None, dict(VarValue="ä|ö|ü", Delimiters="|", OmitChars=""), ["ä", "ö", "ü"]),
]


@pytest.mark.slow
def test_parse_loop(flows):
    builders = [loop_flow("parse-" + name, "Loop_Parse_A_String", setup=setup, body="P %a_index% [%a_loopfield%]",
                          **pars) for name, setup, pars, _ in PARSE]
    for (name, _, _, want), run in zip(PARSE, run_all(flows, builders)):
        if want == "EXC":
            assert run.reason == "exception" and run.exceptions, (name, run.reason, run.names)
        else:
            finished(run)
            assert passes(run) == ["%d [%s]" % (i, f) for i, f in enumerate(want, 1)], name


# --- nesting --------------------------------------------------------------------------------------------------------------
def nested_flow(name, outer, inner, setup=None, inner_text="I %a_index% %a_loopfield%", outer_text="O %a_index% %a_loopkey%",
                exception_text=None, probe=()):
    """outer loop { inner loop { trace point I } trace point O }; `exception_text`: the inner loop has an exception
    connection to a trace point E that goes on with the next pass of the outer loop."""
    fb = FlowBuilder(name)
    o = fb.loop(outer[0], **outer[1])
    i = fb.loop(inner[0], **inner[1])
    ip, op = note(fb, "i", inner_text), note(fb, "o", outer_text)
    fb.connect(start(fb, setup), o)
    fb.connect(o, i, "head")
    fb.connect(i, ip, "head")
    fb.connect(ip, i, into="tail")
    fb.connect(i, op, "tail")
    fb.connect(op, o, into="tail")
    if exception_text:
        ep = note(fb, "e", exception_text)
        fb.connect(i, ep, "exception")
        fb.connect(ep, o, into="tail")
    finish(fb, o, probe)
    return fb


SIMPLE_2 = ("Loop_SimpleLoop", dict(Infinite=0, repeatCount=2))
SIMPLE_3 = ("Loop_SimpleLoop", dict(Infinite=0, repeatCount=3))
LIST_XY = ("Loop_Work_through_a_list", dict(VarValue="l"))
PARSE_12 = ("Loop_Parse_A_String", dict(VarValue="1,2", Delimiters=",", OmitChars=""))


def test_nested_loops_with_the_same_variable_names(flows):
    builders = [
        nested_flow("nest-simple", SIMPLE_2, SIMPLE_3, probe=LOOP_VARS),
        nested_flow("nest-list-parse", LIST_XY, PARSE_12, setup=[setvar("l", ["x", "y"])], probe=LOOP_VARS,
                    outer_text="O %a_index% %a_loopkey% %a_loopfield%"),
        nested_flow("nest-list-list", LIST_XY, LIST_XY, setup=[setvar("l", ["x", "y"])], probe=LOOP_VARS,
                    inner_text="I %a_index% %a_loopfield%", outer_text="O %a_index% %a_loopfield%"),
    ]
    simple, list_parse, list_list = run_all(flows, builders)
    finished(simple)
    gone(simple, *LOOP_VARS)
    assert seq_of(simple) == ["I 1 ", "I 2 ", "I 3 ", "O 1 ", "I 1 ", "I 2 ", "I 3 ", "O 2 "]   # A_Index of the outer loop is back
    finished(list_parse)
    gone(list_parse, *LOOP_VARS)
    assert seq_of(list_parse) == [
        "I 1 1", "I 2 2", "O 1 1 x", "I 1 1", "I 2 2", "O 2 2 y"]
    finished(list_list)
    gone(list_list, *LOOP_VARS)
    assert seq_of(list_list) == [
        "I 1 x", "I 2 y", "O 1 x", "I 1 x", "I 2 y", "O 2 y"]


@pytest.mark.slow
def test_the_inner_loop_can_be_left_by_break_without_touching_the_outer_one(flows):
    fb = FlowBuilder("nest-break")
    outer = fb.loop("Loop_SimpleLoop", Infinite=0, repeatCount=2)
    inner = fb.loop("Loop_Work_through_a_list", VarValue="l")
    stop = fb.condition("Condition_Expression", Expression="a_index = 2")
    ip, op = note(fb, "i", "I %a_index% %a_loopfield%"), note(fb, "o", "O %a_index% [%a_loopfield%]")
    fb.connect(start(fb, [setvar("l", ["x", "y", "z"])]), outer)
    fb.connect(outer, inner, "head")
    fb.connect(inner, stop, "head")
    fb.connect(stop, inner, "yes", into="break")
    fb.connect(stop, ip, "no")
    fb.connect(ip, inner, into="tail")
    fb.connect(inner, op, "tail")
    fb.connect(op, outer, into="tail")
    finish(fb, outer, LOOP_VARS)
    run, = run_all(flows, [fb])
    finished(run)
    assert seq_of(run) == ["I 1 x", "O 1 []", "I 1 x", "O 2 []"]
    gone(run, *LOOP_VARS)


# The inner loop of the exception tests: the first pass is made, the check for the second pass is a type error
# (strict mode, E0034)
THROWS = ("Loop_Condition", dict(Expression='a_index = 1 or "a" + 1', EvaluateOnFirstIteration=1))


def test_a_loop_left_through_exception_restores_the_variables_of_the_outer_loop(flows):
    builders = [
        # the inner loop fails in its second check; the exception connection goes on with the outer loop
        nested_flow("exc-handled", LIST_XY, THROWS, setup=[setvar("l", ["x", "y"])], probe=LOOP_VARS,
                    inner_text="I %a_index%", exception_text="E %a_index% %a_loopkey% %a_loopfield%"),
        # the inner loop fails at its head (the variable is no list): it was entered, so it is popped as well
        nested_flow("exc-head", SIMPLE_2, ("Loop_Work_through_a_list", dict(VarValue="text")),
                    setup=[setvar("text", "no list")], probe=LOOP_VARS, exception_text="E %a_index%"),
        # without a connection for the exception the instance ends with it
        nested_flow("exc-unhandled", LIST_XY, THROWS, setup=[setvar("l", ["x", "y"])], inner_text="I %a_index%"),
    ]
    handled, at_head, unhandled = run_all(flows, builders)
    assert handled.reason == "finished" and handled.names[-1] == "AFTER", handled.names
    assert seq_of(handled) == [
        "I 1", "E 1 1 x", "I 1", "E 2 2 y"]
    # WI-0089: two exceptions of one element in one batch interval arrive as one (the latest state), so 1 or 2 here
    assert len(handled.exceptions) in (1, 2) and all("An error occured while parsing expression" in m
                                                     for m in handled.exceptions)
    gone(handled, *LOOP_VARS)

    assert at_head.reason == "finished" and at_head.names[-1] == "AFTER"
    assert seq_of(at_head) == ["E 1", "E 2"]
    gone(at_head, *LOOP_VARS)

    assert unhandled.reason == "exception" and "AFTER" not in unhandled.names
    assert unhandled.names.count("TP i") == 1
    assert len(unhandled.exceptions) == 1


@pytest.mark.slow
def test_a_loop_left_through_exception_at_the_first_check_pops_once(flows):
    """The head of the inner loop evaluates the condition, which fails: the loop was pushed and is popped once."""
    inner = ("Loop_Condition", dict(Expression='"a" + 1', EvaluateOnFirstIteration=1))
    fb = nested_flow("exc-first", SIMPLE_2, inner, probe=LOOP_VARS, exception_text="E %a_index%")
    run, = run_all(flows, [fb])
    assert run.reason == "finished" and run.names[-1] == "AFTER", (run.reason, run.names)
    assert seq_of(run) == ["E 1", "E 2"]
    gone(run, *LOOP_VARS)


def test_an_exception_of_the_body_that_leaves_the_loop_keeps_the_loop_variables(flows):
    """Documents a limit that v1 has too (ELEMENT-API-V2 7.1): the loop variables are popped when the loop element itself
    leaves with tail or exception. A body element whose exception connection leads out of the loop is not "in" the loop
    for the engine (a flow is a graph), so the variables of the loop stay in the thread."""
    fb = FlowBuilder("body-exception")
    loop = fb.loop("Loop_SimpleLoop", Infinite=0, repeatCount=3)
    fail = fb.action("Action_TestThrow", name="THROWS")
    probe = fb.probe("a_index")
    fb.connect(start(fb, None), loop)
    fb.connect(loop, fail, "head")
    fb.connect(fail, loop, into="tail")
    fb.connect(fail, probe, "exception")
    fb.connect(probe, after(fb))
    run, = run_all(flows, [fb])
    assert run.reason == "finished" and run.names[-1] == "AFTER", (run.reason, run.names)
    assert (run.seen["a_index"].text, run.seen["a_index"].location) == ("1", "loop")


# --- stop, responsiveness, size -------------------------------------------------------------------------------------------
@pytest.mark.slow
def test_a_stop_ends_a_loop_whose_body_waits(flows):
    fb = FlowBuilder("stop-body")
    loop = fb.loop("Loop_SimpleLoop", Infinite=1)
    wait = fb.action("Action_Sleep", Duration=30, Unit="Seconds")
    fb.connect(start(fb, None), loop)
    fb.connect(loop, wait, "head")
    fb.connect(wait, loop, into="tail")
    fb.connect(loop, after(fb), "tail")
    run = flows.begin(fb)
    time.sleep(0.5)
    flows.request_ok("engine", "cmd.flow.stop", {"flowId": run.flow_id})
    flows.wait(run, timeout=10)
    assert run.reason == "flow.stop" and "AFTER" not in run.names
    assert run.names.count("Loop_SimpleLoop") == 1                    # the body never came back


@pytest.mark.slow
def test_a_stop_ends_an_endless_loop_that_runs_at_full_speed(flows):
    fb = FlowBuilder("stop-spin")
    loop = fb.loop("Loop_SimpleLoop", Infinite=1)
    fb.connect(start(fb, None), loop)
    fb.connect(loop, loop, "head", into="tail")                         # an empty body: head straight to tail
    run = flows.begin(fb)
    time.sleep(0.7)
    started = time.monotonic()
    flows.request_ok("engine", "cmd.flow.stop", {"flowId": run.flow_id})
    flows.wait(run, timeout=10)
    assert run.reason == "flow.stop"
    assert time.monotonic() - started < scaled(5.0)
    assert run.names.count("Loop_SimpleLoop") > 50                      # it did run, and fast enough to count


@pytest.mark.slow
def test_long_loops_do_not_scale_with_the_size_of_the_list_or_the_text(flows):
    n = 3000
    big_list = {"op": "set", "name": "l", "value": list(range(n))}
    builders = [
        loop_flow("big-list", "Loop_Work_through_a_list", setup=[big_list], body="", VarValue="l"),
        loop_flow("big-parse", "Loop_Parse_A_String", body="", VarValue=",".join(str(i) for i in range(n)),
                  Delimiters=",", OmitChars=""),
    ]
    runs = run_all(flows, builders, timeout=60)
    for run in runs:
        assert run.reason == "finished" and not run.exceptions
        assert run.names.count("TP p") == n, run.names.count("TP p")


@pytest.mark.slow
def test_a_long_loop_does_not_block_the_engine_and_costs_little_per_pass(flows):
    passes_ = 100_000
    # 100,000 passes are 200,000 element executions: the runaway guard (WI-0066) is switched off for this flow
    fb = FlowBuilder("long", flow_settings={"maxExecutionsPerMinute": 0})
    loop = fb.loop("Loop_SimpleLoop", Infinite=0, repeatCount=passes_)
    fb.connect(start(fb, None), loop)
    fb.connect(loop, loop, "head", into="tail")                         # an empty body
    fb.connect(loop, after(fb), "tail")
    quick = FlowBuilder("quick")
    quick.chain(quick.trigger(), quick.action("Action_Do_nothing", name="QUICK"))
    long_id, quick_id = flows.add(fb), flows.add(quick)
    flows.start()
    t0 = time.monotonic()
    run = flows.begin(long_id)
    time.sleep(0.5)
    # while the loop spins: another flow runs, and the engine answers a request
    latencies = []
    for _ in range(5):
        t = time.monotonic()
        flows.request_ok("engine", "cmd.engine.snapshot", {})
        latencies.append(time.monotonic() - t)
    t = time.monotonic()
    other = flows.run(quick_id, timeout=30)
    other_s = time.monotonic() - t
    flows.wait(run, timeout=300)
    total = time.monotonic() - t0
    assert run.reason == "finished" and run.names[-1] == "AFTER"
    assert run.names.count("Loop_SimpleLoop") == passes_ + 1
    assert other.reason == "finished" and other.names[-1] == "QUICK"
    print("\nMEASURE long loop: %d passes in %.2f s = %.1f us per pass (includes the events to the test observer); "
          "snapshot while the loop ran: max %.0f ms; another flow: %.0f ms"
          % (passes_, total, total / passes_ * 1e6, max(latencies) * 1000, other_s * 1000))
    assert max(latencies) < scaled(1.0)
    assert other_s < scaled(5.0)


# --- the v1 flow "Loop test" ----------------------------------------------------------------------------------------------
@pytest.mark.slow
def test_the_v1_flow_loop_test_runs(flows):
    """"Loop test" (Flow 634320780) as v1 saved it: nested and sequential loops of every kind with trace points and a
    check at the end. WI-0057 adapts it where it needs a fix; this test records how far the original runs."""
    flow_id = flows.add_file(V1_EXAMPLES / "Flow 634320780.json")
    flows.start()
    run = flows.run(flow_id, timeout=60)
    print("\nLOOP TEST: reason=%s exceptions=%s last=%s steps=%d" % (run.reason, run.exceptions, run.names[-3:], len(run.steps)))
    assert run.reason == "finished" and not run.exceptions, (run.reason, run.exceptions)
    # the end of the flow: the check of the trace points passed (element 12), then the flow wrote its name to the global list
    assert run.state_of("element0000000012") == ["finished"] and run.names[-1] == "element0000000030", run.names[-3:]
    pair = flows.wait_var("global_testResults")
    assert pair is not None and json.loads(pair[1]) == ["Loop test"], pair
