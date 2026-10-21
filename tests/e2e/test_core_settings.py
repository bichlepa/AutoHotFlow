"""WI-0114 task 2 (acceptance S0007): every element of the core set is opened in its settings form, changed, saved, and
its run with the saved parameters is checked. 29 cases, one per core class (S0002, support/coreflows.py).

Two parts per case, each in its own session:

A. The editor (supervisor, storage, engine, manager, one editor) with the flow of the case: the element is built with
   its initial parameters (the defaults where none is given). The test opens the settings through cmd.test.form (the same
   calls as the window makes), asserts that CheckSettings gives no warning for the defaults, sets the changed fields, presses
   OK and waits until the file (Flows/skeleton.json) and the engine have the new values.
B. The runner (test entry, support/flowrun.py, dialogs answered by the test provider): the saved file is run as it is
   (`saved`), and the same flow is rebuilt from the parameters of the saved file with probes after the element
   (`rebuilt`). The result of `rebuilt` is checked against the case (probe value, branch, count of loop rounds, exception),
   and `saved` must take the same path (its names without the probes).

The editor flow has no test element (the editor runs the product entry, which has no Test package), so the probes exist in
part B only.

Deterministic: every wait is a condition with a timeout (wait_until), no fixed sleep. A changed field that the form does not
show is a failure of the case (the case names the fields it changes).
"""

import json
from dataclasses import dataclass, field
from pathlib import Path

import pytest

from support.dialogs import DialogScript, answer
from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner
from support.timing import scaled
from test_editor import editor_state, open_editor
from test_editor_draft import engine_definition, settled
from test_manager import FLOW, wait_until
from test_manager_editor import finish, op, start_manager


@dataclass
class Case:
    cls: str                          # the class (Default package)
    kind: str                         # "action", "condition", "loop" or "trigger"
    change: dict                      # parameter id -> new value (the form's fields)
    initial: dict = field(default_factory=dict)   # parameters of the flow before the change ({} = the defaults)
    pre: tuple = ()                   # setup elements before the case: (class, pars) pairs, Action_* or Loop_* as the case needs
    probes: tuple = ()                # variables the rebuilt flow probes after the element (part B)
    observe: object = None            # callable(run) -> what the case checks; default: the run's problems
    want: object = None               # the value observe must give
    raises: bool = False              # the element is expected to throw (its result is an exception)
    dialog: object = None             # the answer of the dialog provider (part B), or None
    callee: bool = False              # the flow has a called flow "callee" (part B)
    name: str = ""                    # a new name the form sets (for an element without parameters)


def probe_text(name):
    return lambda run: run.seen[name].text


def probe_list(name):
    return lambda run: sorted(json.loads(run.seen[name].text))


def passes(run):
    """The rounds of a loop: one log line `P <index>` per pass of the body (a trace point, as in tests/integration)."""
    return [e["text"] for e in run.log if e["text"].startswith("P ")]


def last(run):
    return run.names[-1]


CASES = [
    # --- trigger --------------------------------------------------------------------------------------------------
    Case("Trigger_Manual", "trigger", change={"ID": "Started by hand"}),
    # --- actions: variables and trace points ------------------------------------------------------------------------
    Case("Action_New_variable", "action", change={"Varname": "Changed", "VarValue": "42"}, probes=("Changed",),
         observe=probe_text("Changed"), want="42"),
    Case("Action_Do_nothing", "action", change={"executionResult": "Exception"}, raises=True),
    Case("Action_Trace_Point", "action", initial={"ID": "first point"},
         change={"ID": "changed-point", "LogMessage": "changed trace"},
         observe=lambda run: [e["text"] for e in run.log if "changed trace" in e["text"]] != [], want=True),
    Case("Action_Trace_Point_Check", "action", pre=(("Action_Trace_Point", {"ID": "A"}),),
         change={"MustPassTracepointsAll": 1}),
    # --- actions: lists -----------------------------------------------------------------------------------------
    Case("Action_New_List", "action", change={"Varname": "Changed", "NumberOfElements": "Multiple",
                                              "VarValues": "x\ny"},
         probes=("Changed",), observe=lambda run: json.loads(run.seen["Changed"].text), want=["x", "y"]),
    Case("Action_Add_To_List", "action", initial={"Varname": "src", "VarValue": "b"},
         pre=(("Action_New_List", {"Varname": "src", "NumberOfElements": "Multiple", "VarValues": "a\nb"}),),
         change={"VarValue": "c"}, probes=("src",),
         observe=lambda run: json.loads(run.seen["src"].text), want=["a", "b", "c"]),
    Case("Action_Get_List_Info", "action", initial={"Varname": "info", "List": "src", "WhichInfo": "maxIndex"},
         pre=(("Action_New_List", {"Varname": "src", "NumberOfElements": "Multiple", "VarValues": "a\nb\nc"}),),
         change={"Varname": "Changed", "WhichInfo": "count"}, probes=("Changed",),
         observe=probe_text("Changed"), want="3"),
    Case("Action_Delete_from_list", "action", initial={"ListName": "src", "WhichPosition": "Last"},
         pre=(("Action_New_List", {"Varname": "src", "NumberOfElements": "Multiple", "VarValues": "a\nb\nc"}),),
         change={"ListName": "src", "WhichPosition": "First", "WriteToVariable": 1, "Varname": "Removed"},
         probes=("Removed", "src"),
         observe=lambda run: (run.seen["Removed"].text, json.loads(run.seen["src"].text)),
         want=("a", ["b", "c"])),
    Case("Action_Get_index_of_element_in_list", "action", initial={"ListName": "src", "SearchContent": "a"},
         pre=(("Action_New_List", {"Varname": "src", "NumberOfElements": "Multiple", "VarValues": "a\nb\nc"}),),
         change={"Varname": "Idx", "SearchContent": "b"}, probes=("Idx",), observe=probe_text("Idx"), want="2"),
    Case("Action_Shuffle_list", "action", initial={"Varname": "shuffled", "VarValue": "src"},
         pre=(("Action_New_List", {"Varname": "src", "NumberOfElements": "Multiple", "VarValues": "a\nb\nc"}),),
         change={"Varname": "Changed"}, probes=("Changed",), observe=probe_list("Changed"), want=["a", "b", "c"]),
    # --- actions: flow control and dialogs ------------------------------------------------------------------------
    Case("Action_Execute_Flow", "action", initial={"ThisFlow": 1},
         change={"ThisFlow": 0, "flowID": "callee", "SkipDisabled": 1}, callee=True),
    Case("Action_Stop_Flow", "action", initial={"flowID": ""}, change={"flowID": "callee"}, callee=True),
    Case("Action_Message_Box", "action", change={"title": "Changed title", "message": "Changed text",
                                                  "ButtonLabel": "Got it"},
         probes=("A_UserAction",), dialog=answer("ok"),
         observe=probe_text("A_UserAction"), want="ok"),
    Case("Action_Tooltip", "action", change={"text": "Changed tip", "duration": "300", "Unit": "Milliseconds",
                                             "follow_mouse": 0}),
    Case("Action_Sleep", "action", change={"Duration": "1", "Unit": "Milliseconds"}),
    # --- conditions -----------------------------------------------------------------------------------------------
    Case("Condition_Expression", "condition", initial={"Expression": "1 = 0"}, change={"Expression": "1 = 1"},
         observe=last, want="YES"),
    Case("Condition_Variable_content_is", "condition", initial={"varname": "v"},
         pre=(("Action_New_variable", {"Varname": "v", "VarValue": "3"}),),
         change={"variableContentType": "integer"}, observe=last, want="YES"),
    Case("Condition_NumberIs", "condition", change={"expression": "7"}, observe=last, want="NO"),
    Case("Condition_Variable_Is_Empty", "condition", initial={"VarName": "e"},
         pre=(("Action_New_variable", {"Varname": "e", "VarValue": "x"}),),
         change={"VarName": "missing"}, observe=last, want="YES"),
    Case("Condition_Do_nothing", "condition", change={"executionResult": "No"}, observe=last, want="NO"),
    Case("Condition_List_Contains_Element", "condition",
         initial={"InputList": "src", "SearchWhat": "Content", "SearchContent": "a"},
         pre=(("Action_New_List", {"Varname": "src", "NumberOfElements": "Multiple", "VarValues": "a\nb"}),),
         change={"SearchContent": "zz"}, observe=last, want="NO"),
    Case("Condition_Flow_Running", "condition", initial={"flowID": ""}, change={"flowID": "callee"}, callee=True,
         observe=last, want="NO"),
    Case("Condition_Confirmation_Dialog", "condition",
         change={"title": "Changed title", "message": "Changed question"}, dialog=answer("yes"),
         observe=last, want="YES"),
    Case("Condition_Debug_Dialog", "condition", change={}, name="Changed debug",
         dialog={"answer": "yes", "actions": []}, observe=last, want="YES"),
    # --- loops ------------------------------------------------------------------------------------------------------
    Case("Loop_SimpleLoop", "loop", change={"repeatCount": "3"}, observe=passes, want=["P 1", "P 2", "P 3"]),
    Case("Loop_Condition", "loop", change={"Expression": "a_index <= 2"}, observe=passes, want=["P 1", "P 2"]),
    Case("Loop_Work_through_a_list", "loop", initial={"VarValue": "List"},
         pre=(("Action_New_List", {"Varname": "src", "NumberOfElements": "Multiple", "VarValues": "a\nb\nc"}),),
         change={"VarValue": "src"}, observe=passes, want=["P 1", "P 2", "P 3"]),
    Case("Loop_Parse_A_String", "loop", change={"VarValue": "a,b,c"}, observe=passes,
         want=["P 1", "P 2", "P 3"]),
]

FLOW_FILE = Path("Flows") / (FLOW + ".json")


def build(case, pars, probes, name):
    """The flow of a case: trigger -> pre elements -> the element -> probes -> DONE (action), the branch YES / NO
    (condition), or the body BODY in a loop that runs AFTER its last round (loop)."""
    fb = FlowBuilder(name)
    if case.kind == "trigger":
        el = fb.trigger(case.cls, name="CASE", **pars)
        fb.chain(el, fb.action("Action_Do_nothing", name="DONE"))
        return fb
    prev = fb.trigger()
    for cls, cpars in case.pre:
        prev = fb.chain(prev, fb.action(cls, name="PRE", **cpars))
    if case.kind == "action":
        el = fb.action(case.cls, name="CASE", **pars)
        tail = [el]
        if probes:
            tail.append(fb.probe(*probes, location="thread" if any(p.startswith("A_") for p in probes) else ""))
        tail.append(fb.action("Action_Do_nothing", name="DONE"))
        fb.chain(prev, *tail)
    elif case.kind == "condition":
        cond = fb.condition(case.cls, name="CASE", **pars)
        fb.connect(prev, cond)
        fb.connect(cond, fb.action("Action_Do_nothing", name="YES"), "yes")
        fb.connect(cond, fb.action("Action_Do_nothing", name="NO"), "no")
    else:
        loop = fb.loop(case.cls, name="CASE", **pars)
        fb.connect(prev, loop)
        body = fb.action("Action_Trace_Point", name="BODY", ID="body", LogMessage="P %a_index%")   # a log line per pass
        fb.connect(loop, body, "head")
        fb.connect(body, loop, into="tail")
        fb.connect(loop, fb.action("Action_Do_nothing", name="AFTER"), "tail")
    return fb


def callee_flow():
    fb = FlowBuilder("callee")
    fb.chain(fb.trigger(), fb.action("Action_Do_nothing", name="CALLEE"))
    return fb


def flow_file(datadir):
    return Path(datadir) / FLOW_FILE


def saved_pars(datadir, element_id):
    data = json.loads(flow_file(datadir).read_text(encoding="utf-8"))
    return data["allElements"][element_id]["pars"], data["allElements"][element_id]


def part_a(procs, datadir, session_id, case, fb, element_id):
    """Part A: the settings window in the editor of the flow, changed, OK, saved."""
    sup, obs = start_manager(procs, datadir, session_id, prepare=lambda d: fb.write(d, FLOW))
    try:
        op(obs, "select", flowId=FLOW)
        open_editor(obs)
        ans = obs.request("editor:" + FLOW, "cmd.test.form", {"action": "open", "id": element_id}, timeout=scaled(5))
        assert ans["payload"]["ok"], ans
        form = editor_state(obs, "editor:" + FLOW)["form"]
        assert form["classId"] == "Default." + case.cls, form
        assert form["warnings"] == [], "CheckSettings of the defaults warns: %s" % form["warnings"]
        ids = {i for item in form["fields"] for i in item["ids"]}
        for par in case.change:
            assert par in ids, "the form has no field '%s' (fields: %s)" % (par, sorted(ids))
        for par, value in case.change.items():
            ans = obs.request("editor:" + FLOW, "cmd.test.form", {"action": "set", "id": par, "value": value},
                              timeout=scaled(5))
            assert ans["payload"]["ok"], ans
        if case.name:
            ans = obs.request("editor:" + FLOW, "cmd.test.form", {"action": "name", "text": case.name},
                              timeout=scaled(5))
            assert ans["payload"]["ok"], ans
        ans = obs.request("editor:" + FLOW, "cmd.test.form", {"action": "ok"}, timeout=scaled(5))
        assert ans["payload"]["ok"] and ans["payload"]["changed"] is True, ans
        def saved():
            if not flow_file(datadir).exists():
                return False
            pars, el = saved_pars(datadir, element_id)
            if case.name:
                return el.get("name") == case.name
            return all(str(pars.get(p)) == str(v) for p, v in case.change.items())

        assert wait_until(saved, scaled(15)), "the saved file does not have the change: %s" % saved_pars(datadir, element_id)
        assert wait_until(lambda: settled(obs, "editor:" + FLOW), scaled(10))
        definition = engine_definition(obs)["allElements"][element_id]
        if case.name:
            assert definition["name"] == case.name, definition
        else:
            for par, value in case.change.items():
                assert str(definition["pars"][par]) == str(value), (par, definition["pars"])
    finally:
        finish(sup, obs)


def problems(run):
    return [s.message for s in run.steps if s.state == "exception"]


@pytest.mark.parametrize("case", CASES, ids=[c.cls for c in CASES])
def test_every_core_element_is_changed_saved_and_runs_with_the_new_parameters(case, procs, datadir, session_id):
    fb = build(case, dict(case.initial), (), FLOW)
    element_id = next(h.id for h in fb.handles.values() if h.name == "CASE")
    part_a(procs, datadir, session_id, case, fb, element_id)

    # part B: the saved file, and the flow rebuilt from the saved parameters with the probes
    pars, _ = saved_pars(datadir, element_id)
    runner = FlowRunner(procs, datadir, session_id)
    try:
        runner.add_file(flow_file(datadir), flow_id="saved")
        # the names of the saved file's elements, so that its steps read as the names of the flow (the runner names
        # only the flows it built itself)
        data = json.loads(flow_file(datadir).read_text(encoding="utf-8"))
        runner._names["saved"] = {eid: el["name"] for eid, el in data["allElements"].items()}
        if case.callee:
            runner.add(callee_flow(), "callee")
        rebuilt = build(case, dict(pars), case.probes, "rebuilt")
        runner.add(rebuilt, "rebuilt")
        if case.dialog is not None:
            DialogScript(datadir).script(case.dialog, case.dialog)     # one answer for each part-B run
        runner.start()
        run = runner.run("rebuilt", timeout=scaled(20))
        saved_run = runner.run("saved", timeout=scaled(20))
    finally:
        runner.close()

    run.seen = {name: run.probe(name, timeout=3) for name in case.probes} if run.reason == "finished" else {}
    assert run.reason == ("exception" if case.raises else "finished"), run.steps
    if case.raises:
        assert problems(run), "the element should throw with the changed result: %s" % run.steps
    else:
        assert not problems(run), problems(run)
    if case.observe is not None:
        assert case.observe(run) == case.want, (run.names, run.steps)
    names = [n for n in run.names if not n.startswith("Probe ")]
    saved_names = ["CASE" if n == case.name else n for n in saved_run.names if not n.startswith("Probe ")]
    assert saved_names == names, (saved_names, names)
    assert bool(problems(saved_run)) == case.raises, problems(saved_run)
