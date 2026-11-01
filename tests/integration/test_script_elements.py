"""WI-0130: end-to-end tests of the AutoHotkey script action and trigger (E0039, E0104). The user's code runs in an
AutoHotkey v2 process of its own (src/elements/Default/lib/ScriptHost.ahk). The tests use the real interpreter, through
the flow runner of the test session; nothing leaves the machine.
"""

import pytest

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner, flows  # noqa: F401  (fixtures)


def script_flow(name, script, probes=(), **pars):
    """trigger -> the script action -> probes of the variables it exports."""
    fb = FlowBuilder(name)
    el = fb.action("Action_AutoHotkey_script", Script=script, **pars)
    parts = [fb.trigger(), el]
    if probes:
        parts.append(fb.probe(*probes))
    fb.chain(*parts)
    return fb


def message_of(run):
    assert run.exceptions, run.steps
    return run.exceptions[0]


def test_the_script_runs_and_its_export_variables_are_set(flows):
    script = 'Out1 := "ok"\nOut2 := 6 * 7\n'
    runs = run_all(flows, [script_flow("script_export", script, probes=["Out1", "Out2"],
                                       ExportVariables="Out1|Out2")])
    assert not runs[0].exceptions, runs[0].steps
    assert runs[0].seen["Out1"].text == "ok"
    assert runs[0].seen["Out2"].text == "42"
    assert runs[0].seen["Out2"].type == "Integer"


def test_an_import_variable_is_a_global_of_the_script_with_its_text(flows):
    script = 'Txt2 := Txt "!"\nNum2 := Num + 1\n'
    fb = FlowBuilder("script_import")
    setter = fb.action("Action_Script", Script='Txt := "Grüße"\nNum := 41')
    el = fb.action("Action_AutoHotkey_script", Script=script,
                   ImportVariables="Txt|Num", ExportVariables="Txt2|Num2")
    fb.chain(fb.trigger(), setter, el, fb.probe("Txt2", "Num2"))
    runs = run_all(flows, [fb])
    assert not runs[0].exceptions, runs[0].steps
    assert runs[0].seen["Txt2"].text == "Grüße!"
    assert runs[0].seen["Num2"].text == "42"


def test_a_syntax_error_in_the_code_is_an_exception(flows):
    runs = run_all(flows, [script_flow("script_syntax", "x := (1 +\n")])
    assert runs[0].exceptions, runs[0].steps
    assert message_of(runs[0])


def test_a_runtime_error_gives_the_line_of_the_users_code(flows):
    runs = run_all(flows, [script_flow("script_runtime", 'Out := 1\nthrow Error("boom")\n')])
    text = message_of(runs[0])
    assert "boom" in text
    assert "Line 2" in text


def test_result_exception_ends_the_element_with_the_result_message(flows):
    script = 'result := "exception"\nresultmessage := "custom reason"\n'
    runs = run_all(flows, [script_flow("script_result", script)])
    assert message_of(runs[0]) == "custom reason"


def test_a_script_without_a_result_is_a_normal_end(flows):
    runs = run_all(flows, [script_flow("script_normal", 'Done := 1\n', probes=["Done"], ExportVariables="Done")])
    assert not runs[0].exceptions, runs[0].steps
    assert runs[0].seen["Done"].text == "1"


HOST_ROLES = "storage,engine,triggerhost"


@pytest.fixture
def host_flows(procs, datadir, session_id):
    """A FlowRunner whose session starts the trigger host as well (the trigger is armed by it)."""
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


def test_the_trigger_fires_with_its_export_variables(host_flows):
    fb = FlowBuilder("script_trigger")
    trig = fb.trigger("Trigger_AutoHotkey_Script",
                      Script='Export1 := "first"\nx_trigger()\nSleep 60000\n', ExportVariables="Export1")
    fb.chain(trig, fb.probe("Export1"))
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    pair = host_flows.wait_var("global_probe_Export1", timeout=30)   # the probe writes its value under this name
    assert pair is not None and pair[1] == "first", host_flows.stderr_text()
