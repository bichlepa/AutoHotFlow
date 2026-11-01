"""WI-0130: end-to-end tests of the AutoHotkey script action and trigger (E0039, E0104). The user's code runs in an
AutoHotkey v2 process of its own (src/elements/Default/lib/ScriptHost.ahk). The tests use the real interpreter, through
the flow runner of the test session; nothing leaves the machine.
"""

import time

import psutil
import pytest

from support.coreflows import run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import FlowRunner, flows  # noqa: F401  (fixtures)
from support.timing import scaled


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


# --- stop, disarm, process ends, several fires, imports of the trigger (WI-0130 review) -------------------------------

RUNNING_LOOP = "Loop\n{\n    Sleep 100\n}\n"


def pid_line(pidfile):
    """First line of a script: the own process ID goes to pidfile (the process checks read it)."""
    return 'FileAppend(ProcessExist(), "%s")\n' % pidfile


def wait_gone(pid, timeout):
    deadline = time.monotonic() + scaled(timeout)
    while time.monotonic() < deadline:
        if not psutil.pid_exists(pid):
            return True
        time.sleep(0.1)
    return not psutil.pid_exists(pid)


def read_pid(pidfile, timeout=20):
    deadline = time.monotonic() + scaled(timeout)
    while time.monotonic() < deadline:
        if pidfile.is_file() and pidfile.read_text(encoding="utf-8").strip():
            return int(pidfile.read_text(encoding="utf-8").strip())
        time.sleep(0.1)
    raise AssertionError("the script did not write its process ID to %s" % pidfile)


def test_stop_of_the_flow_ends_the_running_script_process(flows, tmp_path):
    pidfile = tmp_path / "pid.txt"
    fid = "script_stop_flow"
    fb = FlowBuilder(fid)
    trig = fb.trigger()
    script = fb.action("Action_AutoHotkey_script", Script=pid_line(pidfile) + RUNNING_LOOP)
    pause = fb.action("Action_Sleep", Duration=2, Unit="Seconds")
    stop = fb.action("Action_Stop_Flow", flowID=fid)
    fb.connect(trig, script)
    fb.connect(trig, pause)
    fb.chain(pause, stop)
    flows.add(fb, flow_id=fid)
    flows.start()
    flows.run(fid, timeout=scaled(40))
    pid = read_pid(pidfile)
    assert wait_gone(pid, 10), "the script process %d is still running after the stop" % pid


def test_disarming_the_trigger_ends_the_script_process(host_flows, tmp_path):
    pidfile = tmp_path / "pid.txt"
    fb = FlowBuilder("script_disarm")
    trig = fb.trigger("Trigger_AutoHotkey_Script", Script=pid_line(pidfile) + "Sleep 60000\n")
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    pid = read_pid(pidfile)
    assert psutil.pid_exists(pid)
    host_flows.request_ok("engine", "cmd.flow.disable", {"flowId": fid})
    assert wait_gone(pid, 10), "the script process %d is still running after the disarm" % pid


def test_a_trigger_fires_once_per_x_trigger_call_with_its_imports(host_flows, tmp_path):
    """ImportNames gives global_Base to the arming (cmd.trigger.arm imports, ctx.imports); each x_trigger() fires with Export1."""
    pidfile = tmp_path / "pid.txt"
    script = (pid_line(pidfile) + 'Loop 3\n{\n    Export1 := global_Base + A_Index\n    x_trigger()\n    Sleep 300\n}\n'
              + "Sleep 60000\n")
    fb = FlowBuilder("script_three")
    trig = fb.trigger("Trigger_AutoHotkey_Script", Script=script, ImportVariables="global_Base", ExportVariables="Export1")
    fb.chain(trig, fb.probe("Export1"))
    host_flows.preset_var("global_Base", "40")
    fid = host_flows.add(fb)
    host_flows.start()
    host_flows.enable(fid)
    ended = host_flows.ended(fid, count=3, timeout=scaled(40))
    assert len(ended) >= 3, host_flows.stderr_text()
    pair = host_flows.wait_var("global_probe_Export1", timeout=30)
    assert pair is not None and pair[1] in ("41", "42", "43"), pair
    loc = host_flows.wait_var("global_probeloc_Export1", timeout=30)
    assert loc is not None and loc[1] == "instance", loc
    pid = read_pid(pidfile)
    host_flows.request_ok("engine", "cmd.flow.disable", {"flowId": fid})
    assert wait_gone(pid, 10)


def test_a_script_that_ends_keeps_the_process_it_started(flows, tmp_path):
    """v1 kept what a script started (its job does not kill it on a normal end, WI-0130, M-0158)."""
    pidfile = tmp_path / "child.txt"
    script = ('Run(A_ComSpec " /c ping -n 120 127.0.0.1", , "Hide", &childPid)\n'
              + 'FileAppend(childPid, "%s")\n' % pidfile)
    runs = run_all(flows, [script_flow("script_child", script)])
    assert not runs[0].exceptions, runs[0].steps
    child = read_pid(pidfile)
    try:
        assert psutil.pid_exists(child), "the process the script started ended with the script"
    finally:
        try:
            proc = psutil.Process(child)
            for sub in proc.children(recursive=True):
                sub.kill()
            proc.kill()
        except psutil.Error:
            pass
