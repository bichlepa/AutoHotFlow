"""WI-0133: the trigger Shortcut in a real session (storage, engine, triggerhost), REQ-TRG-240, REQ-DST-040, REQ-TRG-200.

The shortcut is written by storage into a folder of the test's data folder (never the desktop or the start menu). Its
command line is read back from the file (WScript.Shell of this machine) and run as a second instance, exactly as the
shortcut runs it. The first start with the command runs the flow once the engine is ready.
"""

import re
import subprocess
import sys
import time
from pathlib import Path

import pytest

from support.flowbuilder import FlowBuilder
from support.flowrun import AHKRUN, ENTRY, FlowRunner
from support.timing import scaled

ROOT = Path(__file__).resolve().parents[2]
HOST_ROLES = "storage,engine,triggerhost"
WAIT_S = 20.0


def shortcut_flow(name, path, remove="1"):
    fb = FlowBuilder(name)
    trigger = fb.trigger("Trigger_Shortcut", ShortCutPath=str(path), RemoveShortcutOnDisabling=remove)
    done = fb.action("Action_Do_nothing")
    fb.chain(trigger, done)
    return fb, trigger


def wait_for(predicate, timeout=WAIT_S):
    deadline = time.monotonic() + scaled(timeout)
    while True:
        if predicate():
            return True
        if time.monotonic() > deadline:
            return False
        time.sleep(0.1)


def read_shortcut(path):
    """(target, arguments) of a shortcut file, as WScript.Shell reads them on this machine."""
    script = ("$s = (New-Object -ComObject WScript.Shell).CreateShortcut('%s'); "
              "Write-Output $s.TargetPath; Write-Output $s.Arguments" % str(path))
    out = subprocess.run(["powershell", "-NoProfile", "-Command", script], capture_output=True, text=True,
                         timeout=scaled(60)).stdout.splitlines()
    return out[0], (out[1] if len(out) > 1 else "")


def words_of(arguments):
    """The command line words as the program gets them: quoted words without the quotes."""
    return [quoted or bare for quoted, bare in re.findall(r'"([^"]*)"|(\S+)', arguments)]


def second_instance(words):
    """Runs the command of a shortcut as a second instance (ahkrun, the same words as the shortcut). Exit code."""
    cmd = [sys.executable, str(AHKRUN), "--timeout", "60", *words]
    return subprocess.run(cmd, cwd=str(ROOT), capture_output=True, timeout=scaled(120)).returncode


@pytest.fixture
def host_flows(procs, datadir, session_id):
    """A FlowRunner whose session starts the trigger host as well."""
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    yield runner
    runner.close()


@pytest.fixture
def folder(datadir):
    """A folder of this test for the shortcut files (inside the data folder of the test)."""
    path = Path(datadir) / "shortcuts"
    path.mkdir(exist_ok=True)
    return path


def enabled_shortcut(runner, folder, name, remove="1"):
    """A flow with a Shortcut trigger, started and enabled; waits until the shortcut file exists. Returns (flow, trigger, path)."""
    path = folder / (name + ".lnk")
    fb, trigger = shortcut_flow(name, path, remove)
    fid = runner.add(fb)
    runner.start()
    runner.enable(fid)
    assert wait_for(path.exists), runner.stderr_text()
    return fid, trigger, path


def test_enabling_the_trigger_writes_the_shortcut_with_its_command(host_flows, folder):
    fid, trigger, path = enabled_shortcut(host_flows, folder, "Shortcut written")
    target, arguments = read_shortcut(path)
    words = words_of(arguments)
    assert words[0] == str(ENTRY), arguments                 # the program script of this instance (--app-script)
    assert "--session=" + host_flows.sessions[-1] in words, arguments
    assert "--data=" + str(host_flows.datadir) in words, arguments
    assert "--command=Trigger|%s|%s" % (fid, trigger.id) in words, arguments
    assert target.lower().endswith(".exe"), target


def test_running_the_shortcut_starts_the_flow_at_its_trigger(host_flows, folder):
    fid, _, path = enabled_shortcut(host_flows, folder, "Shortcut runs")
    _, arguments = read_shortcut(path)
    assert second_instance(words_of(arguments)) == 0, host_flows.stderr_text()
    runs = host_flows.ended(fid, count=1, timeout=scaled(30))
    assert len(runs) >= 1, host_flows.stderr_text()


def test_a_shortcut_of_a_switched_off_trigger_starts_nothing(host_flows, folder):
    fid, _, path = enabled_shortcut(host_flows, folder, "Shortcut off", remove="0")
    _, arguments = read_shortcut(path)
    host_flows.request_ok("engine", "cmd.flow.disable", {"flowId": fid})
    since = host_flows.mark()
    assert second_instance(words_of(arguments)) == 1, host_flows.stderr_text()
    assert host_flows.ended(fid, since=since, count=0, timeout=0) == [], "a switched off trigger started the flow"
    assert path.exists(), "the option is off: the shortcut stays"


def test_switching_the_trigger_off_removes_the_shortcut_with_the_option(host_flows, folder):
    fid, _, path = enabled_shortcut(host_flows, folder, "Shortcut removed", remove="1")
    host_flows.request_ok("engine", "cmd.flow.disable", {"flowId": fid})
    assert wait_for(lambda: not path.exists()), host_flows.stderr_text()


def test_switching_the_trigger_off_keeps_the_shortcut_without_the_option(host_flows, folder):
    fid, _, path = enabled_shortcut(host_flows, folder, "Shortcut kept", remove="0")
    host_flows.request_ok("engine", "cmd.flow.disable", {"flowId": fid})
    time.sleep(scaled(1.0))
    assert path.exists(), host_flows.stderr_text()


def test_a_shutdown_keeps_the_shortcut_even_with_the_option(host_flows, folder):
    _, _, path = enabled_shortcut(host_flows, folder, "Shortcut at shutdown", remove="1")
    host_flows.stop()
    assert path.exists(), "the shortcut was removed at the shutdown"


def test_the_first_start_by_a_shortcut_runs_the_flow_when_the_engine_is_ready(procs, datadir, session_id, folder):
    runner = FlowRunner(procs, datadir, session_id, roles=HOST_ROLES)
    try:
        fid, trigger, path = enabled_shortcut(runner, folder, "Shortcut first start")
        runner.stop()
        runner.start(extra=["--command=Trigger|%s|%s" % (fid, trigger.id)])
        assert len(runner.ended(fid, count=1, timeout=scaled(40))) >= 1, runner.stderr_text()
    finally:
        runner.close()


def test_a_command_for_a_missing_flow_is_refused_and_the_session_runs(host_flows, folder):
    enabled_shortcut(host_flows, folder, "Shortcut other flow")
    words = [str(ENTRY), "--session=" + host_flows.sessions[-1], "--data=" + str(host_flows.datadir),
             "--command=Trigger|Flow 999|element0000000002"]
    assert second_instance(words) == 1, host_flows.stderr_text()
    # the session still answers
    assert host_flows.request_ok("supervisor", "cmd.process.list", {})["processes"] is not None
