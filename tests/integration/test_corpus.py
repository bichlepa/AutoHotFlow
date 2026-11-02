"""WI-0057: the test corpus, the acceptance of S0002 (REQ-TST-040, REQ-TST-030).

Three flows of the "Automatic tests" category of v1 run headless and green, all three as saved: "variable test", "List
test" and "Loop test". The v1 "Trigger test" (S0003, E0061) runs headless on an adapted copy (FIX_LIST, M-0077). "variable test" needs the trigger variable A_ManualTriggerID, which the engine sets for every start
of a trigger (TriggerVariables, WI-0062, M-0069 is done), so the old copy with its fixes is gone.

Then 16 synthetic flows (flow builder, WI-0049) that use the core set wider than the v1 flows do: each flow is a chain
of checks or steps that ends in the marker DONE; a flow that does not behave as expected goes to FAIL or ends with an
exception. The PENDING table lists the other 11 "Automatic tests" flows with the elements that are still missing and
the step that brings them (S0003 and S0008); a test keeps the table equal to the element registry in src/.
"""

import glob
import json
import os
import shutil
import uuid
from pathlib import Path

import pytest

from support.coreflows import run_all, setvar
from support.dialogs import DialogScript, answer
from support.flowbuilder import FlowBuilder
from support.ahk import find_ahk_exe
from support.flowrun import FlowRunner, flows, var_value  # noqa: F401  (flows: fixture)
from support.localhttp import local_server  # noqa: F401  (fixture: the HTTP request of the corpus, WI-0122)
from support.system import SystemScript, value
from support.timing import scaled

pytestmark = pytest.mark.slow          # each test starts a session (acceptance tier, `-m slow`)

ROOT = Path(__file__).resolve().parents[2]
V1 = ROOT / "tests" / "data" / "flows" / "v1_examples"
V2 = ROOT / "tests" / "data" / "flows" / "v2_adapted"
HOST_ROLES = "storage,engine,triggerhost"       # the trigger host (S0003); the flows fixture starts without it

# --- the fix list (every change of a loaded v1 flow in the copies of v2_adapted/) ---------------------------------------
# Empty since WI-0124: the speech output is back in the "Trigger test" copy (M-0077 resolved). The test provider of the
# system seam answers SpeechVoices from the script of the test, and speaks nothing.
FIX_LIST = [
    # M-0152: "HTTP Request" (Flow 100439537) calls https://httpbin.org; the test rewrites its URLs to the local server, and
    # the User-Agent of its second request is "myuseagent" while its check expects "myuseragent" (the test copy is corrected)
    ("Flow 100439537", "URLs of httpbin.org replaced by the local test server (127.0.0.1); User-Agent myuseagent corrected"),
    # WI-0130 (M-0158): the scripts of the two "sleep, msgbox" elements are v2 code (Sleep 10000); the MsgBox is removed,
    # because a MsgBox in a script process is a real dialog that no test answers (the flow stops before it anyway)
    ("Flow 1849072261", "v1 scripts of elements 15 and 17 ported to v2 (Sleep 10000, MsgBox removed)"),
    # M-0178: "Process Test" (Flow 561135904) starts and ends cttune.exe and notepad.exe of the user; the test copy uses
    # a copy of cmd.exe named ahf_wi0132_process_test.exe (found through PATH by Run) and ends only that copy
    ("Flow 561135904", "static_ProcessName is ahf_wi0132_process_test.exe (a copy of cmd.exe on PATH); the kill of notepad.exe ends the variable"),
    # M-0179: "File link test" (Flow 74366368) writes its two shortcuts to %A_Desktop%; the test replaces %A_Desktop% by a folder of
    # the test, so no shortcut is made on the desktop of the user (the shortcuts themselves are the real ones)
    ("Flow 74366368", "%A_Desktop% replaced by a folder of the test in every parameter (shortcuts and files); a 2 s sleep after "
     "each enable and disable of a Shortcut trigger: the engine answers before the shortcut file is written (F-0208)"),
]

# --- the flows that are not in the corpus yet ---------------------------------------------------------------------
# The v1 flow "Automatic tests" flows that are not in this corpus yet: the elements they lack and the step that brings them
# (WI-0057 task 3). The test below keeps this table equal to the element registry.
PENDING = {
    # all elements are registered since WI-0128; the trigger "Input Normal" runs headless (test_dialog_elements), the other
    # parts read the controls of the real windows and send keys to them: the gui part, the owner's run (WI-0135, F-0197)
    "Flow 130786371": dict(name="Dialog test", missing={}, reason="reads the controls of real windows and presses their buttons"),
    # all elements are registered since WI-0126; the flow presses real keys (Ctrl+F7 and others) that other programs may use;
    # a copy with unassigned keys is an open decision (WI-0126, WI-0135)
    "Flow 2133155705": dict(name="Hotkey test", missing={}, reason="sends real key combinations to the desktop"),
    # all elements are registered since WI-0124. The flow enables and starts the 15 other flows at once, among them the two
    # above (real keys and windows), and waits for 15 results; it is not run as a whole headless (WI-0135, F-0214): the
    # 13 other flows run each in this file, with the setup they need (local server, own process, folder for the shortcuts)
    "Flow 65341778": dict(name="_AutomaticTest starter", missing={}, reason="starts all flows, among them the Dialog test and the Hotkey test"),
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


def test_v1_string_test_runs_green(flows):
    """"string test" (Flow 369404488), unchanged (WI-0119): the start trigger enables the flow and runs the string tests
    one after the other (contains text, split and trim, substring, search in a string); the flow runs to its end
    without an exception."""
    flow_id = flows.add_file(V1 / "Flow 369404488.json")
    flows.start()
    flows.enable(flow_id)
    run = flows.run(flow_id, trigger="element0000000025", timeout=scaled(120))
    assert run.reason == "finished", run.reason
    # three searches of the flow were not found and ended on their exception connection (the path decides, not the
    # flow); the success path ends with Add to list, never with the error box
    assert set(run.exceptions) <= {"Searched text was not found"}, run.exceptions
    assert run.names[-1] == "element0000000045" and "element0000000046" not in run.names, run.names[-5:]


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


BOM_UTF16 = bytes([0xFF, 0xFE])        # the byte order mark of a UTF-16 (little endian) file, as IniWrite writes it


def test_v1_ini_file_test_runs_green_in_a_test_folder(flows, tmp_path):
    """"ini file test" (Flow 1587447767), as saved except its working folder (WI-0121). The flow writes testIni.ini next to
    itself, and as saved that is the folder of the user's documents: the test runs the flow with the working folder of the
    test (flowSettings, DefaultWorkingDir 0), and nothing else changes. The flow writes two keys (a new file, UTF-16 with a
    byte order mark), reads one back, reads a missing key (the exception connection goes on), reads it again with the
    default text and adds its name to the global list."""
    data = json.loads((V1 / "Flow 1587447767.json").read_text(encoding="utf-8-sig"))
    data.setdefault("flowSettings", {}).update({"DefaultWorkingDir": 0, "WorkingDir": str(tmp_path)})
    source = tmp_path / "src" / "Flow 1587447767.json"
    source.parent.mkdir()
    source.write_text(json.dumps(data), encoding="utf-8")
    flow_id = flows.add_file(source)
    flows.start()
    run = flows.run(flow_id, trigger="element0000000002", timeout=scaled(60))
    assert run.reason == "finished", (run.reason, run.exceptions)
    assert run.exceptions == ["Section 'mySection' and key 'wrongKey' not found."], run.exceptions
    assert {"element0000000005", "element0000000007", "element0000000008", "element0000000010",
            "element0000000019"} <= set(run.path), run.path
    assert (tmp_path / "testIni.ini").read_bytes()[:2] == BOM_UTF16
    pair = flows.wait_var("global_testResults")
    assert pair is not None and json.loads(pair[1]) == ["ini file test"], pair


WINDOW_HELPER = ROOT / "tests" / "integration" / "helpers" / "own_window.ahk"


def test_v1_file_test_runs_green_with_an_own_window(flows, tmp_path):
    """"file test" (Flow 1384439262), as saved except its window (WI-0125, M-0140). The flow creates a shortcut to Notepad
    and runs it, and checks the shortcut and the window with the window elements. The test runs the flow in a temporary
    folder (as the ini test). The shortcut starts an own test window instead (helpers/own_window.ahk, a copy in the
    folder, run by the AutoHotkey interpreter), with a title of its own, so the window elements never see a Notepad window
    of the user. The arguments of a shortcut are cut at 259 characters, so the script and its files are named relatively
    (found in the working folder of the shortcut). The flow closes the window (method close) and its program ends with it.
    """
    interpreter, reason = find_ahk_exe()
    if interpreter is None:
        pytest.skip(reason)
    data = json.loads((V1 / "Flow 1384439262.json").read_text(encoding="utf-8-sig"))
    data.setdefault("flowSettings", {}).update({"DefaultWorkingDir": 0, "WorkingDir": str(tmp_path)})
    title = "AhfFileTest-" + uuid.uuid4().hex
    (tmp_path / "own_window.ahk").write_bytes(WINDOW_HELPER.read_bytes())
    arguments = "own_window.ahk %s ready.txt stop.txt" % title
    for element in data["allElements"].values():
        pars = element.get("pars", {})
        if element["class"] == "Action_Create_Shortcut":
            # the shortcut starts the test program instead of Notepad (its target and its arguments)
            pars["file"] = interpreter
            pars["runArguments"] = arguments
        if element["class"] == "Condition_Expression" and pars["Expression"].startswith("shortcutTarget = "):
            pars["Expression"] = 'shortcutTarget = "%s"' % interpreter
        if element["class"] == "Condition_Expression" and pars["Expression"].startswith("shortcutArgs = "):
            pars["Expression"] = 'shortcutArgs = "%s"' % arguments
        if element["class"] == "Action_Delete_File" and pars.get("deleteFileMethod") == "Recycle":
            # the recycle bin of the user is not touched by a test: the copy deletes the file (WI-0117, the seam)
            pars["deleteFileMethod"] = "Delete"
        if element["class"] in ("Action_Close_Window", "Condition_Window_Exists"):
            # the window of the test: its title, the class and the process of the helper (AutoHotkey GUI)
            assert pars["Wintitle"] == "anyTestText.txt" and pars["ahk_class"] == "Notepad", pars
            pars.update({"Wintitle": title, "ahk_class": "AutoHotkeyGUI", "ahk_exe": "AutoHotkey64.exe"})
    source = tmp_path / "src" / "Flow 1384439262.json"
    source.parent.mkdir()
    source.write_text(json.dumps(data), encoding="utf-8")
    flow_id = flows.add_file(source)
    flows.start()
    flows.enable(flow_id)       # the flow calls its own triggers with Action_Execute_Flow (F-0099, as the other flows)
    run = flows.run(flow_id, trigger="element0000000487", timeout=scaled(120))
    assert run.reason == "finished", (run.reason, run.exceptions)
    # the one exception of the flow is taken by its exception connection (the copy over an existing file, as saved)
    assert len(run.exceptions) == 1 and "already exists" in run.exceptions[0], run.exceptions
    assert {"element0000000884", "element0000000889", "element0000000890"} <= set(run.path), run.path


def test_v1_maths_test_runs_green(flows):
    """"maths test" (Flow 1087828277), as saved (WI-0118). The trigger "start" sets the counter and starts the seven checks
    of the maths elements, each a trigger of this flow with one element (Absolute number, Random number, Square root,
    Trigonometry, Rounding a number, Exponentiation, Number is). The Absolute number check of the text "aegasdf" ends in
    its exception connection on purpose; the flow adds its name to the global list only when all seven checks succeeded.
    A negative square root gives the empty text (MIGRATION M-0104), which the flow checks."""
    flow_id = flows.add_file(V1 / "Flow 1087828277.json")
    flows.start()
    run = flows.run(flow_id, trigger="element0000000021", timeout=scaled(120))
    assert run.reason == "finished", (run.reason, run.exceptions)
    assert run.exceptions == ["Value is not a number: aegasdf"], run.exceptions
    assert run.path[-1] == "element0000000026"
    pair = flows.wait_var("global_testResults")
    assert pair is not None and json.loads(pair[1]) == ["maths test"], pair


# --- the v1 "Trigger test" (S0003, E0061) -------------------------------------------------------------------------------
@pytest.fixture
def host_flows(procs, datadir, session_id):
    """A FlowRunner whose session starts the trigger host as well (S0003)."""
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


def test_v1_trigger_test_runs_green_on_the_adapted_copy(host_flows):
    """"Trigger test" (Flow 884290977), the copy in v2_adapted/ (FIX_LIST, M-0077). The flow is enabled at the start of the
    session (FlowStates, E0063) through its Trigger_Start_up, which fires once at the start. Then the manual trigger
    "black branch" runs the test: periodic timers, flow status elements, flow enabled conditions and the debug dialogs,
    which the dialog seam answers. The end state is static_testSuccess = 1."""
    flow_id = host_flows.add_file(V2 / "Flow 884290977.json")
    state_dir = host_flows.datadir / "FlowStates"
    state_dir.mkdir(exist_ok=True)
    (state_dir / (flow_id + ".json")).write_text(
        json.dumps({"formatVersion": 1, "enabled": ["element0000000172"]}), encoding="utf-8")
    dialogs = DialogScript(host_flows.datadir)
    dialogs.script(*[{"answer": "yes", "actions": []}] * 8)
    # the speech output of the flow (WI-0124): its voice is installed in the test, and nothing is spoken (system seam)
    SystemScript(host_flows.datadir).script({"SpeechVoices": [value(["Microsoft Hedda Desktop"])]})
    host_flows.start()
    startup = host_flows.wait_message(
        lambda m: m.get("type") == "evt.instance.started" and m["payload"].get("flowId") == flow_id,
        timeout=scaled(30))
    assert startup is not None, host_flows.stderr_text()
    run = host_flows.run(flow_id, trigger="element0000000001", timeout=scaled(120))
    # The flow calls its own trigger 13 while it is disabled: that is the test of the exception connection (v1 design).
    # The exception is caught, the flow goes on at "Set flow status: enable" and the call is repeated.
    assert run.reason == "finished", (run.reason, run.names[-5:])
    assert run.exceptions == ["Trigger 'element0000000013' in 'Flow 884290977' is disabled"], run.exceptions
    assert "element0000000111" in run.path and "element0000000110" in run.path, run.names[-5:]
    assert run.path[-1] == "element0000000130", run.names[-5:]
    pair = host_flows.wait_var("static_testSuccess", lambda p: var_value(p) == "1", flow_id=flow_id)
    assert pair is not None, (run.names[-5:], dialogs.requests())


# --- "User idle test" (WI-0131) ---------------------------------------------------------------------------------------
def test_v1_user_idle_test_runs_green_with_the_idle_time_of_the_test_provider(host_flows):
    """"User idle test" (Flow 1333431302) as saved: the manual trigger enables four idle triggers of the flow (5 s, 10 s,
    10 min, 10 h of idle time, all TimeIdlePhysical). The idle time is answered by the test provider (WI-0117): it counts
    from the start of the trigger host, so every trigger fires once during the run (no real user is waited for)."""
    flow_id = host_flows.add_file(V1 / "Flow 1333431302.json")
    SystemScript(host_flows.datadir).script({}, idle_base_ms=0)
    host_flows.start()
    run = host_flows.run(flow_id, trigger="element0000000001", timeout=scaled(240))
    assert run.reason == "finished", (run.reason, run.names[-5:], host_flows.stderr_text()[-800:])
    assert not run.exceptions, (run.exceptions, run.names[-5:])


# --- "Process Test" (WI-0132) ---------------------------------------------------------------------------------------------
def test_v1_process_test_runs_green_with_an_own_process(host_flows, tmp_path, monkeypatch):
    """"Process Test" (Flow 561135904), the copy in v2_adapted/ (FIX_LIST, M-0178). The flow starts the process named in its
    variable static_ProcessName, watches it with Process starts and Process closes, and kills it again. The test process is
    a copy of cmd.exe under that name, in a folder first on PATH (Run finds it there, the flow's own Run starts it hidden);
    no process of the user is started or ended. Nothing is answered: the confirmation dialog of the flow is shown only
    when the process already runs, and it does not run at the start."""
    folder = tmp_path / "bin"
    folder.mkdir()
    shutil.copyfile(os.path.join(os.environ["SystemRoot"], "System32", "cmd.exe"), folder / "ahf_wi0132_process_test.exe")
    monkeypatch.setenv("PATH", str(folder) + os.pathsep + os.environ.get("PATH", ""))
    source = V2 / "Flow 561135904.json"
    name = json.loads(source.read_text(encoding="utf-8"))["name"]
    flow_id = host_flows.add_file(source)
    host_flows.start()
    run = host_flows.run(flow_id, trigger="element0000000022", timeout=scaled(240))
    assert run.reason == "finished" and not run.exceptions, (run.reason, run.exceptions, run.names[-5:],
                                                            host_flows.stderr_text()[-800:])
    pair = host_flows.wait_var("global_testResults")
    assert pair is not None and json.loads(pair[1]) == [name], pair


# --- "HTTP Request" (WI-0122) ---------------------------------------------------------------------------------------
def test_v1_http_request_runs_green_against_the_local_server(flows, local_server, tmp_path):
    """"HTTP Request" (Flow 100439537), as saved except its URLs (FIX_LIST, M-0152): httpbin.org is replaced by the local
    test server, which answers like httpbin (JSON with args, headers, data, form and url). The flow makes a GET and two
    POST requests (plain text with a UTF-8 codepage, and a form with a custom content type and an automatic Content-MD5
    header) and checks the answers with expressions and debug dialogs, which the dialog seam answers with yes."""
    data = json.loads((V1 / "Flow 100439537.json").read_text(encoding="utf-8-sig"))
    for element in data["allElements"].values():
        pars = element.get("pars", {})
        url = pars.get("URL", "")
        if isinstance(url, str) and url.startswith("https://httpbin.org"):
            pars["URL"] = local_server.url(url[len("https://httpbin.org"):])
        if pars.get("UserAgent") == "myuseagent":
            pars["UserAgent"] = "myuseragent"          # the check of the flow expects this text (FIX_LIST)
    source = tmp_path / "src" / "Flow 100439537.json"
    source.parent.mkdir()
    source.write_text(json.dumps(data), encoding="utf-8")
    dialogs = DialogScript(flows.datadir)
    dialogs.script(*[answer("yes")] * 4)           # the four debug dialogs of the flow
    flow_id = flows.add_file(source)
    flows.start()
    run = flows.run(flow_id, trigger="element0000000001", timeout=scaled(60))
    assert run.reason == "finished" and not run.exceptions, (run.reason, run.exceptions, run.names[-5:])
    assert {"element0000000002", "element0000000014", "element0000000024"} <= set(run.path), run.path
    pair = flows.wait_var("global_testResults")
    assert pair is not None and json.loads(pair[1]) == [data["name"]], pair
    assert [r["method"] for r in local_server.requests()] == ["GET", "POST", "POST"], local_server.requests()


def _insert_sleep_after(data, source_id, target_id, sleep_id):
    """Puts an Action_Sleep of 2 s between two elements of a v1 flow (the connection source -> target goes through it)."""
    elements = data["allElements"]
    sleep = json.loads(json.dumps(elements["element0000000030"]))      # a copy of the flow's own Sleep element
    sleep.update({"ID": sleep_id, "name": "Sleep: 2 s (test copy)", "x": "0", "y": "0"})
    sleep["pars"] = {"Duration": 2, "Unit": "Seconds"}
    elements[sleep_id] = sleep
    for key, conn in data["allConnections"].items():
        if conn["from"] == source_id and conn["to"] == target_id:
            conn["to"] = sleep_id
            data["allConnections"][key + "_sleep"] = {"ConnectionType": "normal", "from": sleep_id, "ID": key + "_sleep",
                                                      "to": target_id, "type": "Connection"}
            return
    raise AssertionError("no connection %s -> %s" % (source_id, target_id))


# --- "File link test" (WI-0133) ---------------------------------------------------------------------------------------
def test_v1_file_link_test_runs_green_with_shortcuts_in_a_test_folder(host_flows, tmp_path):
    """"File link test" (Flow 74366368), as saved except the folder of its shortcuts (FIX_LIST, M-0179): %A_Desktop% is
    replaced by a folder of the test. The flow enables its two Shortcut triggers (the files are written), runs both
    shortcuts (each one starts this flow at its trigger through the second start), switches one trigger off (its file goes,
    the option is on), deletes the other file, and adds its name to the global list when all checks hold. No file is left."""
    desktop = tmp_path / "desktop"
    desktop.mkdir()
    data = json.loads((V1 / "Flow 74366368.json").read_text(encoding="utf-8-sig"))
    for element in data["allElements"].values():
        pars = element.get("pars", {})
        for key, value in list(pars.items()):
            if isinstance(value, str) and "%A_Desktop%" in value:
                pars[key] = value.replace("%A_Desktop%", str(desktop))
    source = tmp_path / "src" / "Flow 74366368.json"
    source.parent.mkdir()
    source.write_text(json.dumps(data), encoding="utf-8")
    # F-0208: the shortcut file is written after the answer of the enable; the copy waits 2 s after each switch
    _insert_sleep_after(data, "element0000000034", "element0000000039", "element0000000050")
    _insert_sleep_after(data, "element0000000004", "element0000000005", "element0000000051")
    # The flow's own Sleep (element 30) waits 2 s for the two shortcut runs; a shortcut run needs a process start plus
    # the 2 s above, so the flow's sleep ended first and the check (element 32) saw unset flags. Wait longer (F-0208).
    data["allElements"]["element0000000030"]["pars"]["Duration"] = 12
    source.write_text(json.dumps(data), encoding="utf-8")
    flow_id = host_flows.add_file(source)
    host_flows.start()
    run = host_flows.run(flow_id, trigger="element0000000001", timeout=scaled(120))
    assert run.reason == "finished" and not run.exceptions, (run.reason, run.exceptions, run.names[-5:],
                                                            host_flows.stderr_text()[-800:])
    assert "element0000000024" in run.path, run.names[-8:]
    assert list(desktop.iterdir()) == [], list(desktop.iterdir())
    pair = host_flows.wait_var("global_testResults")
    assert pair is not None and json.loads(pair[1]) == [data["name"]], pair


# --- "external script test" (WI-0130) ---------------------------------------------------------------------------------
def test_v1_external_script_test_runs_green_on_the_v2_copy(flows):
    """"external script test" (Flow 1849072261), the copy in v2_adapted/ (FIX_LIST, M-0158): the script action counts with
    the imported counter and exports it; the flow stops itself (element 14) before the scripts that sleep."""
    flow_id = flows.add_file(V2 / "Flow 1849072261.json")
    flows.start()
    run = flows.run(flow_id, trigger="element0000000001", timeout=scaled(60))
    assert not run.exceptions, (run.reason, run.exceptions, run.names[-5:])
    assert "element0000000014" in run.path, run.path


# --- "Dialog test" (WI-0128): the headless part ---------------------------------------------------------------------------
def test_v1_dialog_test_input_normal_runs_headless_with_a_scripted_input_box(flows):
    """"Dialog test" (Flow 130786371), trigger "Input Normal" as saved: the input box answers from the script, once with OK
    (the variable and the static result are set) and once with the cancel button (the exception goes to element 212). The
    other triggers of the flow read the controls of the real windows and send keys to them: the gui part, not run here."""
    dialogs = DialogScript(flows.datadir)
    dialogs.script(answer({"result": "OK", "value": "Dialog Test Value"}, kind="InputWindow"),
                   answer({"result": "Cancel", "value": ""}, kind="InputWindow"))
    flow_id = flows.add_file(V1 / "Flow 130786371.json")
    flows.start()
    ok = flows.run(flow_id, trigger="element0000000206", timeout=scaled(60))
    assert ok.reason == "finished" and not ok.exceptions, (ok.reason, ok.exceptions, ok.names[-5:])
    assert "element0000000211" in ok.path and "element0000000212" not in ok.path, ok.path
    cancel = flows.run(flow_id, trigger="element0000000206", timeout=scaled(60))
    assert cancel.reason == "finished" and "element0000000212" in cancel.path, (cancel.reason, cancel.path)
    assert cancel.exceptions == ["User cancelled the dialog"], cancel.exceptions
    first, second = dialogs.requests()
    assert (first["args"]["title"], first["args"]["text"]) == ("Dialog Test Title", "Dialog Test Text")
    assert second["args"]["title"] == "Dialog Test Title"


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
    # WI-0089: the recorded steps of a fast element are batched (one step can stand for several runs); the dialogs
    # themselves are counted exactly below
    assert 1 <= run.names.count("Condition_Confirmation_Dialog") <= 3 and len(dialogs.requests()) == 3
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
    # WI-0089: the recorded steps of a fast element are batched (one step can stand for several runs), so at most 3
    assert 1 <= run.names.count("Condition_Expression") <= 3, run.names
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
    """The table PENDING equals the element classes of the 12 remaining "Automatic tests" flows that have no registered
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


def test_the_automatic_tests_category_has_16_flows_and_3_of_them_wait_for_the_owner():
    """WI-0135: the 16 "Automatic tests" flows of v1: 13 run headless in this file, 3 are in PENDING with a reason (the
    starter, the Dialog test and the Hotkey test). The table says why; an entry without a reason is a failure."""
    names = {}
    for path in glob.glob(str(V1 / "Flow *.json")):
        data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
        if data.get("category") == "Automatic tests":
            names[Path(path).stem] = data["name"]
    assert len(names) == 16, sorted(names.values())
    assert set(PENDING) <= set(names)
    assert all(entry.get("reason") and entry["missing"] == {} for entry in PENDING.values())
    assert len(set(names) - set(PENDING)) == 13
