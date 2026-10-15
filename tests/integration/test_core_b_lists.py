"""WI-0053: end-to-end tests of the list elements of the core set B, with the flow builder.

Every test builds small flows, adds them all to the data folder of one session and runs them one after the other, so a
test group costs one start of the session (`support/coreflows.py`). A flow is: trigger, optional `setvar` steps
(Action_TestSetVar), the element under test, a probe of the variables. The probe shows a list as JSON: a list with the
keys 1..n as an array, any other as an object with text keys (so a list with gaps shows as {"1": .., "3": ..}). The
unit tests of the list logic itself are tests/ahk/element_list_ops.test.ahk.
"""

import json
from pathlib import Path

import pytest

from support.coreflows import run_all, setvar
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)

ROOT = Path(__file__).resolve().parents[2]
V1_EXAMPLES = ROOT / "tests" / "data" / "flows" / "v1_examples"
EXC = "EXCEPTION"                                   # expected: the element ends with an exception


def action_flow(name, cls, setup=None, probe=("l",), **pars):
    """trigger -> [Action_TestSetVar] -> element -> probe of the variables `probe`."""
    fb = FlowBuilder(name)
    prev = fb.trigger()
    if setup:
        step = fb.action("Action_TestSetVar", Steps=json.dumps(setup))
        fb.connect(prev, step)
        prev = step
    el = fb.action(cls, **pars)
    fb.connect(prev, el)
    fb.connect(el, fb.probe(*probe))
    return fb


def shown(run, name="l"):
    """What the probe saw: the parsed JSON of a list, the text of any other value, EXC if the element failed."""
    if run.reason != "finished" or run.exceptions:
        return EXC
    probe = run.seen[name]
    return json.loads(probe.text) if probe.type == "Map" else probe.text


def run_cases(flows, cls, cases, probe=("l",)):
    """cases: (setup, pars, expected) with the expected value of the probe `l` (a list or an object as JSON data, a text,
    or EXC). Returns the runs."""
    builders = [action_flow("%s%d" % (cls[7:14], i), cls, setup=setup, probe=probe, **pars)
                for i, (setup, pars, _) in enumerate(cases)]
    runs = run_all(flows, builders)
    got = [shown(r) for r in runs]
    want = [expected for *_, expected in cases]
    assert got == want, "\n".join("%d: %r want %r  %s" % (i, g, w, c[1]) for i, (g, w, c) in
                                  enumerate(zip(got, want, cases)) if g != w)
    return runs


def abc(name="l"):
    return setvar(name, ["a", "b", "c"])


# --- Action_New_List -----------------------------------------------------------------------------------------------------
NEW_LIST = [
    (None, dict(Varname="l", NumberOfElements="None"), {}),
    (None, dict(Varname="l"), {}),                                                      # the default is an empty list
    (None, dict(Varname="l", NumberOfElements="One", VarValue="x", WhichPosition="First"), ["x"]),
    (None, dict(Varname="l", NumberOfElements="One", VarValue="x", WhichPosition="Specified", Position="name"),
     {"name": "x"}),
    (None, dict(Varname="l", NumberOfElements="One", VarValue="x", WhichPosition="Specified", Position="5"), {"5": "x"}),
    (None, dict(Varname="l", NumberOfElements="One", VarValue="x", WhichPosition="Specified", Position="007"), {"7": "x"}),
    (None, dict(Varname="l", NumberOfElements="One", VarValue="x", WhichPosition="Specified", Position="1+2",
                expressionPos="Expression"), {"3": "x"}),
    (None, dict(Varname="l", NumberOfElements="One", VarValue="x", WhichPosition="Specified", Position=""), EXC),
    (None, dict(Varname="l", NumberOfElements="One", VarValue="1 + 2", expression="Expression", WhichPosition="First"), [3]),
    (None, dict(Varname="l", NumberOfElements="One", VarValue="a %who% b", expression="String", WhichPosition="First"),
     ["a  b"]),                                                                         # a missing variable is empty
    ([setvar("who", "me")], dict(Varname="l", NumberOfElements="One", VarValue="a %who% b", WhichPosition="First"),
     ["a me b"]),
    ([setvar("src", ["p", "q"])], dict(Varname="l", NumberOfElements="One", VarValue="src", expression="Expression",
                                       WhichPosition="First"), [["p", "q"]]),                 # a list inside a list
    (None, dict(Varname="l", NumberOfElements="One", VarValue="", WhichPosition="First"), EXC),   # WarnIfEmpty
    (None, dict(Varname="l", NumberOfElements="Multiple", VarValues="a\nb\nc"), ["a", "b", "c"]),
    (None, dict(Varname="l", NumberOfElements="Multiple", VarValues="a\n\nb"), ["a", "", "b"]),
    (None, dict(Varname="l", NumberOfElements="Multiple", VarValues="a,b;c d\ne", DelimiterLinefeed=0, DelimiterComma=1,
                DelimiterSemicolon=1, DelimiterSpace=1), ["a", "b", "c", "d\ne"]),
    (None, dict(Varname="l", NumberOfElements="Multiple", VarValues="a,b\nc", DelimiterLinefeed=1, DelimiterComma=1),
     ["a", "b", "c"]),
    (None, dict(Varname="l", NumberOfElements="Multiple", VarValues="a b\nc", DelimiterLinefeed=0), ["a b\nc"]),   # M-0057
    ([setvar("who", "me")], dict(Varname="l", NumberOfElements="Multiple", VarValues="x %who%\ny"), ["x me", "y"]),
    # the position is ignored with several values, as the form of v1 disables it (v1 flows hold "Specified" here)
    (None, dict(Varname="l", NumberOfElements="Multiple", VarValues="a\nb", WhichPosition="Specified", Position="5"),
     ["a", "b"]),
    ([setvar("l", "old")], dict(Varname="l", NumberOfElements="None"), {}),             # an existing variable is replaced
    ([setvar("l", [1, 2, 3])], dict(Varname="L", NumberOfElements="One", VarValue="x", WhichPosition="First"), ["x"]),
    (None, dict(Varname="bad name!", NumberOfElements="None"), EXC),
    (None, dict(Varname="A_Index", NumberOfElements="None"), EXC),
    (None, dict(Varname="l", NumberOfElements="Many"), EXC),
]


@pytest.mark.slow
def test_new_list_creates_empty_and_filled_lists(flows):
    run_cases(flows, "Action_New_List", NEW_LIST)


@pytest.mark.slow
def test_new_list_scopes(flows):
    """The prefix of the name decides the scope; the list is a variable like any other."""
    builders = [action_flow("scope%d" % i, "Action_New_List", probe=(name,), Varname=name, NumberOfElements="Multiple",
                            VarValues="a\nb") for i, name in enumerate(["global_lst", "static_lst", "plain"])]
    runs = run_all(flows, builders)
    for name, run in zip(["global_lst", "static_lst", "plain"], runs):
        assert run.reason == "finished" and not run.exceptions, run.exceptions
        probe = run.seen[name]
        assert (json.loads(probe.text), probe.type) == (["a", "b"], "Map")
    assert [r.seen[n].location for n, r in zip(["global_lst", "static_lst", "plain"], runs)] == ["global", "static", "instance"]


# --- Action_Add_To_List ----------------------------------------------------------------------------------------------------
GAPS = setvar("l", {"1": "a", "3": "c"})


def add(where, value="x", **more):
    return dict(Varname="l", NumberOfElements="One", VarValue=value, WhichPosition=where, **more)


ADD_TO_LIST = [
    ([abc()], add("Last"), ["a", "b", "c", "x"]),
    ([abc()], add("First"), ["x", "a", "b", "c"]),
    ([abc()], add("Specified", Position="2", InsertMethod="Insert"), ["a", "x", "b", "c"]),
    ([abc()], add("Specified", Position="2", InsertMethod="Overwrite"), ["a", "x", "c"]),
    ([abc()], add("Specified", Position="4", InsertMethod="Insert"), ["a", "b", "c", "x"]),
    ([abc()], add("Specified", Position="7", InsertMethod="Insert"), {"1": "a", "2": "b", "3": "c", "7": "x"}),
    ([abc()], add("Specified", Position="02", InsertMethod="Overwrite"), ["a", "x", "c"]),           # text that looks like 2
    ([abc()], add("Specified", Position="1+1", InsertMethod="Insert", expressionPos="Expression"), ["a", "x", "b", "c"]),
    ([abc()], add("Specified", Position="name"), {"1": "a", "2": "b", "3": "c", "name": "x"}),
    ([setvar("l", {"1": "a", "Name": "b"})], add("Specified", Position="NAME"), {"1": "a", "Name": "x"}),   # key ignores case
    ([abc()], add("Specified", Position=""), EXC),
    ([GAPS], add("Last"), {"1": "a", "3": "c", "4": "x"}),
    ([GAPS], add("First"), {"1": "x", "2": "a", "4": "c"}),                              # the gap moves up with the rest
    ([GAPS], add("Specified", Position="3", InsertMethod="Insert"), {"1": "a", "3": "x", "4": "c"}),
    ([GAPS], add("Specified", Position="2", InsertMethod="Insert"), {"1": "a", "2": "x", "4": "c"}),
    ([GAPS], add("Specified", Position="2", InsertMethod="Overwrite"), ["a", "x", "c"]),
    ([setvar("l", {"-1": "n", "1": "a"})], add("Last"), {"-1": "n", "1": "a", "2": "x"}),
    ([setvar("l", {"k": "v"})], add("Last"), {"1": "x", "k": "v"}),                      # only text keys: starts at 1
    ([setvar("l", [])], add("Last"), ["x"]),
    ([setvar("l", [])], add("First"), ["x"]),
    (None, add("Last"), ["x"]),                                                           # no variable: a new list
    ([setvar("l", "")], add("Last"), ["x"]),                                              # the empty text: a new list
    ([setvar("l", "abc")], add("Last"), EXC),                                             # another content: an error
    ([setvar("l", 0)], add("Last"), EXC),
    ([abc()], dict(Varname="L", NumberOfElements="One", VarValue="x", WhichPosition="Last"), ["a", "b", "c", "x"]),
    ([abc(), setvar("src", ["p", "q"])], add("Last", value="src", Expression="Expression"),
     ["a", "b", "c", ["p", "q"]]),
    ([abc()], add("Last", value="1 + 1", Expression="Expression"), ["a", "b", "c", 2]),
    ([abc()], add("Last", value=""), EXC),
    # several values
    ([abc()], dict(Varname="l", NumberOfElements="Multiple", VarValues="x\ny", WhichPosition="Last"), ["a", "b", "c", "x", "y"]),
    ([abc()], dict(Varname="l", NumberOfElements="Multiple", VarValues="x\ny", WhichPosition="First"), ["x", "y", "a", "b", "c"]),
    ([abc()], dict(Varname="l", NumberOfElements="Multiple", VarValues="x,y", WhichPosition="Specified", Position="2",
                   InsertMethod="Insert", DelimiterLinefeed=0, DelimiterComma=1), ["a", "x", "y", "b", "c"]),
    ([abc()], dict(Varname="l", NumberOfElements="Multiple", VarValues="x\ny", WhichPosition="Specified", Position="2",
                   InsertMethod="Overwrite"), ["a", "x", "y"]),
    ([abc()], dict(Varname="l", NumberOfElements="Multiple", VarValues="x\ny", WhichPosition="Specified", Position="3",
                   InsertMethod="Overwrite"), ["a", "b", "x", "y"]),
    ([abc()], dict(Varname="l", NumberOfElements="Multiple", VarValues="x\ny", WhichPosition="Specified", Position="name"), EXC),
    (None, dict(Varname="l", NumberOfElements="Multiple", VarValues="x\ny", WhichPosition="Last"), ["x", "y"]),
]


@pytest.mark.slow
def test_add_to_list_every_position_and_method(flows):
    run_cases(flows, "Action_Add_To_List", ADD_TO_LIST[:19])


@pytest.mark.slow
def test_add_to_list_other_variables_and_several_values(flows):
    run_cases(flows, "Action_Add_To_List", ADD_TO_LIST[19:])


@pytest.mark.slow
def test_add_to_list_warns_when_it_creates_the_list(flows):
    missing, empty, existing = run_all(flows, [
        action_flow("warn1", "Action_Add_To_List", **add("Last")),
        action_flow("warn2", "Action_Add_To_List", setup=[setvar("l", "")], **add("Last")),
        action_flow("warn3", "Action_Add_To_List", setup=[abc()], **add("Last"))])
    texts = lambda run: [e["text"] for e in run.log if "A new list will be created" in e["text"]]  # noqa: E731
    assert len(texts(missing)) == 1 and len(texts(empty)) == 1 and texts(existing) == []
    assert "Variable 'l' is empty" in texts(missing)[0]


@pytest.mark.slow
def test_add_to_list_exception_messages(flows):
    notlist, nopos = run_all(flows, [
        action_flow("msg1", "Action_Add_To_List", setup=[setvar("l", "abc")], **add("Last")),
        action_flow("msg2", "Action_Add_To_List", setup=[abc()], **add("Specified", Position=""))])
    assert notlist.exceptions == ["Variable 'l' is not empty and does not contain a list."]
    assert nopos.exceptions == ["String 'Position' is empty"]


@pytest.mark.slow
def test_add_to_list_does_not_change_other_variables(flows):
    """A list that was copied into another variable is not changed (REQ-VAR-060: assignment copies)."""
    run, = run_all(flows, [action_flow("copy", "Action_Add_To_List", probe=("l", "copy"),
                                       setup=[abc(), setvar("copy", ["a", "b", "c"])], **add("Last"))])
    assert shown(run, "l") == ["a", "b", "c", "x"] and shown(run, "copy") == ["a", "b", "c"]


# --- Action_Get_List_Info ------------------------------------------------------------------------------------------------------
INFO_LISTS = {
    "empty": [setvar("src", [])],
    "abc": [abc("src")],
    "gaps": [setvar("src", {"2": "a", "5": "b"})],
    "mixed": [setvar("src", {"-3": "n", "1": "a", "x": "t", "y": "u"})],
    "negative": [setvar("src", {"-3": "n"})],
    "text": [setvar("src", {"k": "v"})],
}
# list -> (minIndex, maxIndex, length, count); "" is the empty text
INFO_EXPECTED = {
    "empty": ("", "", "0", "0"),
    "abc": ("1", "3", "3", "3"),
    "gaps": ("2", "5", "5", "2"),
    "mixed": ("-3", "1", "1", "4"),
    "negative": ("-3", "-3", "0", "1"),
    "text": ("", "", "0", "1"),
}


@pytest.mark.slow
def test_get_list_info_all_four_infos(flows):
    keys = list(INFO_LISTS)
    infos = ["minIndex", "maxIndex", "length", "count"]
    builders = [action_flow("info%d_%d" % (i, j), "Action_Get_List_Info", setup=INFO_LISTS[key], probe=("n",), Varname="n",
                            List="src", WhichInfo=info)
                for i, key in enumerate(keys) for j, info in enumerate(infos)]
    runs = run_all(flows, builders)
    got = [shown(r, "n") for r in runs]
    want = [INFO_EXPECTED[key][j] for key in keys for j in range(4)]
    assert got == want
    # the numbers are numbers
    assert runs[4].seen["n"].type == "Integer" and runs[3].seen["n"].type == "Integer"


@pytest.mark.slow
def test_get_list_info_expression_and_errors(flows):
    cases = [
        # (setup, List expression, WhichInfo, expected)
        ([abc("src")], "src", "count", "3"),
        ([abc("src")], 'object("a", 1, "b", 2)', "count", "2"),                    # any expression that gives a list
        ([setvar("src", "text")], "src", "count", EXC),                           # a text is not a list
        ([setvar("src", 5)], "src", "count", EXC),
        (None, "src", "count", EXC),                                              # no variable: an empty result
        ([abc("src")], "src", "nothing", EXC),                                    # unknown information
        ([abc("src")], "", "count", EXC),
    ]
    builders = [action_flow("infoerr%d" % i, "Action_Get_List_Info", setup=setup, probe=("n",), Varname="n", List=expr,
                            WhichInfo=info) for i, (setup, expr, info, _) in enumerate(cases)]
    runs = run_all(flows, builders)
    assert [shown(r, "n") for r in runs] == [c[3] for c in cases]
    assert runs[2].exceptions == ["'src' does not contain a list"]


# --- Condition_List_Contains_Element -------------------------------------------------------------------------------------------
def contains_flow(name, setup, **pars):
    """trigger -> setup -> condition -> YES (probe of A_FoundKey) / NO."""
    fb = FlowBuilder(name)
    prev = fb.trigger()
    if setup:
        step = fb.action("Action_TestSetVar", Steps=json.dumps(setup))
        fb.connect(prev, step)
        prev = step
    cond = fb.condition("Condition_List_Contains_Element", **pars)
    fb.connect(prev, cond)
    yes = fb.action("Action_Do_nothing", name="YES")
    fb.connect(cond, yes, "yes")
    fb.connect(yes, fb.probe("A_FoundKey", location="thread"))
    fb.connect(cond, fb.action("Action_Do_nothing", name="NO"), "no")
    return fb


MIXED = setvar("l", {"1": "Apple", "2": "1.0", "3": "x", "Name": "Peter", "5": "7"})
CONTAINS = [
    # (setup, parameters, answer, A_FoundKey)
    ([MIXED], dict(SearchWhat="Key", Position="1"), "YES", None),
    ([MIXED], dict(SearchWhat="Key", Position="01"), "YES", None),                    # "01" is the key 1
    ([MIXED], dict(SearchWhat="Key", Position="4"), "NO", None),
    ([MIXED], dict(SearchWhat="Key", Position="name"), "YES", None),                  # key names ignore case
    ([MIXED], dict(SearchWhat="Key", Position="Peter"), "NO", None),
    ([MIXED], dict(SearchWhat="Key", Position="1+1", isExpressionPosition="Expression"), "YES", None),
    ([MIXED], dict(SearchWhat="Key", Position=""), "EXCEPTION", None),
    ([MIXED], dict(SearchWhat="Content", SearchContent="apple"), "YES", "1"),         # texts ignore case
    ([MIXED], dict(SearchWhat="Content", SearchContent="1"), "YES", "2"),             # "1" equals "1.0" (numbers)
    ([MIXED], dict(SearchWhat="Content", SearchContent="7"), "YES", "5"),
    ([MIXED], dict(SearchWhat="Content", SearchContent="peter"), "YES", "Name"),
    ([MIXED], dict(SearchWhat="Content", SearchContent="Pete"), "NO", None),          # no substring search
    ([MIXED], dict(SearchWhat="Content", SearchContent="3 + 4", isExpressionSearchContent="Expression"), "YES", "5"),
    ([MIXED], dict(SearchWhat="Content", SearchContent=""), "EXCEPTION", None),       # WarnIfEmpty
    ([setvar("l", ["a", "b", "a"])], dict(SearchWhat="Content", SearchContent="a"), "YES", "1"),     # the first one
    ([setvar("l", [])], dict(SearchWhat="Content", SearchContent="a"), "NO", None),
    ([setvar("l", [])], dict(SearchWhat="Key", Position="1"), "NO", None),
    ([setvar("l", [["n"]])], dict(SearchWhat="Content", SearchContent="n"), "NO", None),             # no look into members
    ([setvar("l", "text")], dict(SearchWhat="Key", Position="1"), "EXCEPTION", None),
    (None, dict(SearchWhat="Key", Position="1"), "EXCEPTION", None),
    ([MIXED], dict(Position="1", SearchContent="x"), "YES", "3"),                     # no SearchWhat: the default, Content
]


@pytest.mark.slow
def test_list_contains_element_key_and_content(flows):
    builders = [contains_flow("contains%d" % i, setup, InputList="l", **pars) for i, (setup, pars, *_) in enumerate(CONTAINS)]
    runs = run_all(flows, builders)
    got = [("EXCEPTION" if r.reason != "finished" or r.exceptions else "YES" if "YES" in r.names else "NO",
            r.seen["A_FoundKey"].text if "YES" in r.names and r.seen["A_FoundKey"].type != "<missing>" else None)
           for r in runs]
    want = [(a, k) for *_, a, k in CONTAINS]
    assert got == want, [(i, g, w) for i, (g, w) in enumerate(zip(got, want)) if g != w]


@pytest.mark.slow
def test_list_contains_element_found_key_is_a_thread_variable(flows):
    run, = run_all(flows, [contains_flow("foundkey", [MIXED], InputList="l", SearchWhat="Content", SearchContent="x")])
    assert (run.seen["A_FoundKey"].text, run.seen["A_FoundKey"].type, run.seen["A_FoundKey"].location) == ("3", "Integer", "thread")


# --- Action_Delete_from_list ---------------------------------------------------------------------------------------------------
def delete(where, **more):
    return dict(ListName="l", WhichPosition=where, **more)


DELETE = [
    ([abc()], delete("Last"), ["a", "b"]),
    ([abc()], delete("First"), ["b", "c"]),                                               # decrement is the default method
    ([abc()], delete("First", DeleteMethod="KeepGap"), {"2": "b", "3": "c"}),
    ([abc()], delete("Last", DeleteMethod="KeepGap"), ["a", "b"]),
    ([abc()], delete("Specified", Position="2"), ["a", "c"]),
    ([abc()], delete("Specified", Position="2", DeleteMethod="Decrement"), ["a", "c"]),
    ([abc()], delete("Specified", Position="2", DeleteMethod="KeepGap"), {"1": "a", "3": "c"}),
    ([abc()], delete("Specified", Position="02", DeleteMethod="KeepGap"), {"1": "a", "3": "c"}),
    ([abc()], delete("Specified", Position="3"), ["a", "b"]),
    ([abc()], delete("Specified", Position="4"), EXC),                                    # no such key
    ([abc()], delete("Specified", Position=""), EXC),
    ([abc()], delete("Specified", Position="x"), EXC),
    ([setvar("l", {"1": "a", "3": "c", "4": "d"})], delete("Specified", Position="3"), {"1": "a", "3": "d"}),
    ([setvar("l", {"1": "a", "3": "c", "4": "d"})], delete("First"), {"2": "c", "3": "d"}),
    ([setvar("l", {"2": "a", "7": "b", "k": "t"})], delete("Last"), {"2": "a", "k": "t"}),
    ([setvar("l", {"2": "a", "7": "b", "k": "t"})], delete("First", DeleteMethod="KeepGap"), {"7": "b", "k": "t"}),
    ([setvar("l", {"1": "a", "Key": "t", "x": "u"})], delete("Specified", Position="key"), {"1": "a", "x": "u"}),
    ([setvar("l", {"1": "a", "Key": "t", "x": "u"})], delete("Specified", Position="x", DeleteMethod="Decrement"),
     {"1": "a", "Key": "t"}),
    ([setvar("l", {"k": "t"})], delete("Last"), EXC),                                     # no Integer key
    ([setvar("l", {"k": "t"})], delete("First"), EXC),
    ([setvar("l", [])], delete("Last"), EXC),
    ([setvar("l", "text")], delete("Last"), EXC),
    (None, delete("Last"), EXC),
    ([setvar("l", [["n"], "b"])], delete("First"), ["b"]),
]


@pytest.mark.slow
def test_delete_from_list_every_position_and_method(flows):
    run_cases(flows, "Action_Delete_from_list", DELETE)


@pytest.mark.slow
def test_delete_from_list_writes_the_deleted_value(flows):
    cases = [
        # (setup, parameters, expected variable `gone` ("<missing>": not written), expected list `l`)
        ([abc()], delete("Last", WriteToVariable=1, Varname="gone"), "c", ["a", "b"]),
        ([abc()], delete("First", WriteToVariable=1, Varname="gone"), "a", ["b", "c"]),
        ([abc()], delete("Specified", Position="2", WriteToVariable=1, Varname="gone"), "b", ["a", "c"]),
        ([abc()], delete("Last", WriteToVariable=0, Varname="gone"), "<missing>", ["a", "b"]),       # not asked for
        ([setvar("l", [["n", "m"], "b"])], delete("First", WriteToVariable=1, Varname="gone"), ["n", "m"], ["b"]),
        ([abc()], delete("Last", WriteToVariable=1, Varname="bad name!"), EXC, EXC),
        ([abc()], delete("Last", WriteToVariable=1, Varname=""), EXC, EXC),
        ([abc()], delete("Last", WriteToVariable=0, Varname=""), "<missing>", ["a", "b"]),     # an unused name is not checked
    ]
    builders = [action_flow("del%d" % i, "Action_Delete_from_list", setup=setup, probe=("l", "gone"), **pars)
                for i, (setup, pars, *_) in enumerate(cases)]
    runs = run_all(flows, builders)
    assert [(shown(r, "gone"), shown(r, "l")) for r in runs] == [(c[2], c[3]) for c in cases]


@pytest.mark.slow
def test_delete_from_list_exception_messages(flows):
    nokey, nointeger = run_all(flows, [
        action_flow("msg1", "Action_Delete_from_list", setup=[abc()], **delete("Specified", Position="9")),
        action_flow("msg2", "Action_Delete_from_list", setup=[setvar("l", {"k": "v"})], **delete("First"))])
    assert nokey.exceptions == ["The list 'l' does not contain the key '9'."]
    assert nointeger.exceptions == ["The list 'l' does not contain an integer key."]


# --- Action_Get_index_of_element_in_list ------------------------------------------------------------------------------------------
def index_of(content, **more):
    return dict(Varname="idx", ListName="src", SearchContent=content, **more)


INDEX_SETUP = setvar("src", {"1": "Apple", "2": "1.0", "3": "x", "Name": "Peter", "7": "x"})
INDEX = [
    ([INDEX_SETUP], index_of("Apple"), "1"),
    ([INDEX_SETUP], index_of("apple"), "1"),
    ([INDEX_SETUP], index_of("x"), "3"),                                                  # the first one
    ([INDEX_SETUP], index_of("1"), "2"),                                                  # numbers compare as numbers
    ([INDEX_SETUP], index_of("1.00"), "2"),
    ([INDEX_SETUP], index_of("PETER"), "Name"),                                           # the result may be a key name
    ([INDEX_SETUP], index_of("0.5 + 0.5", expression="Expression"), "2"),
    ([INDEX_SETUP], index_of("nothing"), EXC),
    ([INDEX_SETUP], index_of(""), EXC),
    ([setvar("src", [])], index_of("a"), EXC),
    ([setvar("src", "text")], index_of("text"), EXC),
    (None, index_of("a"), EXC),
    ([setvar("src", ["", "b"])], index_of("%nothing%"), EXC),                              # an empty search text is refused
]


@pytest.mark.slow
def test_get_index_of_element_in_list(flows):
    builders = [action_flow("idx%d" % i, "Action_Get_index_of_element_in_list", setup=setup, probe=("idx",), **pars)
                for i, (setup, pars, _) in enumerate(INDEX)]
    runs = run_all(flows, builders)
    assert [shown(r, "idx") for r in runs] == [c[2] for c in INDEX]
    assert runs[0].seen["idx"].type == "Integer" and runs[5].seen["idx"].type == "String"
    assert runs[7].exceptions == ["The list 'src' does not contain the value 'nothing'."]
    assert runs[10].exceptions == ["Variable 'src' does not contain a list."]


# --- Action_Shuffle_list ------------------------------------------------------------------------------------------------------------
@pytest.mark.slow
def test_shuffle_list_keeps_content_and_count(flows):
    numbers = list(range(1, 13))
    cases = [
        # (setup, pars, probe names)
        ([setvar("src", numbers)], dict(Varname="out", VarValue="src")),
        ([setvar("src", numbers)], dict(Varname="src", VarValue="src")),                  # the input list may be the output
        ([setvar("src", {"1": "a", "2": "b", "5": "c", "k": "text", "j": "other"})], dict(Varname="out", VarValue="src")),
        ([setvar("src", [])], dict(Varname="out", VarValue="src")),
        ([setvar("src", ["only"])], dict(Varname="out", VarValue="src")),
        ([setvar("src", [["n", 1], ["m", 2]])], dict(Varname="out", VarValue="src")),    # lists as members
        ([setvar("src", "text")], dict(Varname="out", VarValue="src")),
        (None, dict(Varname="out", VarValue="src")),
    ]
    builders = [action_flow("shuffle%d" % i, "Action_Shuffle_list", setup=setup, probe=("out", "src"), **pars)
                for i, (setup, pars) in enumerate(cases)]
    runs = run_all(flows, builders)

    out = shown(runs[0], "out")
    assert sorted(out) == numbers and len(out) == 12
    assert shown(runs[0], "src") == numbers                                                # the input is not changed
    assert sorted(shown(runs[1], "src")) == numbers
    mixed = shown(runs[2], "out")
    assert mixed["k"] == "text" and mixed["j"] == "other" and len(mixed) == 5
    assert sorted(mixed[k] for k in ("1", "2", "3")) == ["a", "b", "c"] and set(mixed) == {"1", "2", "3", "k", "j"}
    assert shown(runs[3], "out") == {}
    assert shown(runs[4], "out") == ["only"]
    nested = shown(runs[5], "out")
    assert sorted(nested) == [["m", 2], ["n", 1]]
    assert runs[6].exceptions == ["Variable 'src' does not contain a list."]
    assert shown(runs[7], "out") == EXC


@pytest.mark.slow
def test_shuffle_list_is_random(flows):
    """Several shuffles of 12 numbers are not all the original order (the chance of that is 1 in 479001600 per run)."""
    builders = [action_flow("rand%d" % i, "Action_Shuffle_list", setup=[setvar("src", list(range(1, 13)))], probe=("out",),
                            Varname="out", VarValue="src") for i in range(3)]
    results = [shown(r, "out") for r in run_all(flows, builders)]
    assert any(r != list(range(1, 13)) for r in results) and all(sorted(r) == list(range(1, 13)) for r in results)


# --- the elements together -------------------------------------------------------------------------------------------------------------------
def test_a_list_built_edited_and_searched_with_the_elements(flows):
    """New list -> Add to list -> Delete from list -> Get list info -> Get index, in one flow."""
    fb = FlowBuilder("chain")
    new = fb.action("Action_New_List", Varname="l", NumberOfElements="Multiple", VarValues="red\ngreen\nblue")
    add_ = fb.action("Action_Add_To_List", Varname="l", NumberOfElements="One", VarValue="yellow", WhichPosition="Last")
    first = fb.action("Action_Add_To_List", Varname="l", NumberOfElements="One", VarValue="black", WhichPosition="First")
    drop = fb.action("Action_Delete_from_list", ListName="l", WhichPosition="Specified", Position="3", WriteToVariable=1,
                     Varname="dropped")
    info = fb.action("Action_Get_List_Info", Varname="n", List="l", WhichInfo="count")
    idx = fb.action("Action_Get_index_of_element_in_list", Varname="pos", ListName="l", SearchContent="yellow")
    fb.chain(fb.trigger(), new, add_, first, drop, info, idx, fb.probe("l", "dropped", "n", "pos"))
    run, = run_all(flows, [fb])
    assert run.reason == "finished" and not run.exceptions, run.exceptions
    assert shown(run, "l") == ["black", "red", "blue", "yellow"] and shown(run, "dropped") == "green"
    assert (shown(run, "n"), shown(run, "pos")) == ("4", "4")


# --- the v1 example flow "List test" -----------------------------------------------------------------------------------------------------------
@pytest.mark.slow
def test_the_v1_flow_list_test_runs(flows):
    """"List test" (Flow 1210127300), started at its trigger "list test". The flow tests the list elements and decides
    with its connections: the six List contains element conditions have one connection each (yes or no), every
    Condition_Expression after the Get list info elements has only its yes connection, so a wrong answer would end the
    instance there. The Get index of element 'asdf' is meant to fail (its exception connection leads on). The flow then
    shuffles the list until the order changed (a random number of tries) and ends with Add to list on the global
    results list, which does not exist yet (a warning)."""
    flow_id = flows.add_file(V1_EXAMPLES / "Flow 1210127300.json")
    flows.start()
    run = flows.run(flow_id, trigger="element0000000008")
    assert run.reason == "finished"
    assert run.exceptions == ["The list 'russianList' does not contain the value 'asdf'."]
    ids = ["element00000000%02d" % n for n in (8, 10, 9, 2, 3, 4, 5, 6, 7, 11, 12, 13, 15, 16, 17, 14, 18, 19, 20, 21, 22,
                                               24, 25, 26, 23, 27, 28, 30, 31, 32, 29, 33, 40, 34, 35, 36, 37, 38, 39, 56, 41)]
    assert run.path[:len(ids)] == ids
    assert run.path[-1] == "element0000000112"
    assert any("Variable 'global_testResults' is empty" in e["text"] for e in run.log)
