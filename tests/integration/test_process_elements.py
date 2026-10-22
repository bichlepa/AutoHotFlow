"""WI-0123: end-to-end tests of the process elements of the package Default: Run, Kill process, Set process priority and the
condition Process is running. Every process a test starts or ends is its own: a Python child process (sleep) or a copy of
cmd.exe under a unique name in the temporary folder. No process of the user is started, ended or changed. The flows run in
a real session (support/flowrun.py); the expected texts are those of v1 unless MIGRATION M-0120 says otherwise.
"""

import os
import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path

import psutil
import pytest

from support.coreflows import answer, condition_flow, run_all
from support.flowbuilder import FlowBuilder
from support.flowrun import flows  # noqa: F401  (fixture)
from support.timing import scaled

CREATE_NO_WINDOW = 0x08000000        # the test programs get no console window
SLEEP_PROGRAM = [sys.executable, "-c", "import time; time.sleep(600)"]


def element_flow(name, cls, probe=None, **pars):
    """trigger -> the element -> (a probe of `x`)."""
    fb = FlowBuilder(name)
    el = fb.action(cls, **pars)
    parts = [fb.trigger(), el]
    if probe:
        parts.append(fb.probe(probe))
    fb.chain(*parts)
    return fb


def message_of(run):
    assert run.exceptions, run.steps
    return run.exceptions[0]


def wait_for(predicate, limit=20):
    """Polls until the predicate is true (a bounded wait for a program that starts or ends on its own)."""
    deadline = time.monotonic() + scaled(limit)
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(0.05)
    return predicate()


@pytest.fixture
def child():
    """A Python child process of this test: the only process a test of Kill or Priority acts on. Ended at the end."""
    proc = subprocess.Popen(SLEEP_PROGRAM, creationflags=CREATE_NO_WINDOW,
                            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    yield proc
    if proc.poll() is None:
        proc.kill()
    proc.wait(timeout=scaled(20))


@pytest.fixture
def named_copy(tmp_path):
    """A copy of cmd.exe under a unique name, waiting for a key (no grandchild process). Killed at the end if still alive."""
    name = "ahf_wi0123_" + uuid.uuid4().hex[:12] + ".exe"
    copy = tmp_path / name
    shutil.copyfile(Path(os.environ["SystemRoot"]) / "System32" / "cmd.exe", copy)
    proc = subprocess.Popen([str(copy), "/c", "pause"], creationflags=CREATE_NO_WINDOW,
                            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    yield name, proc
    if proc.poll() is None:
        proc.kill()
    proc.wait(timeout=scaled(20))


def alive(proc):
    return proc.poll() is None


# --- Run ----------------------------------------------------------------------------------------------------------------
def test_run_starts_the_program_in_the_working_directory_of_the_flow(flows, tmp_path):
    """The working directory of the flow is the folder of the flow settings: cmd writes its current folder there."""
    fb = FlowBuilder("run_cwd", flow_settings={"DefaultWorkingDir": 0, "WorkingDir": str(tmp_path)})
    run_el = fb.action("Action_Run", ToRun='cmd.exe /c "cd > cwd.txt"', WhichWorkingDir="Default", RunMode="Hide")
    fb.chain(fb.trigger(), run_el)
    runs = run_all(flows, [fb])
    assert runs[0].reason == "finished" and not runs[0].exceptions, runs[0].steps
    out = tmp_path / "cwd.txt"
    assert wait_for(out.exists), "the started program did not write its file"
    assert os.path.samefile(out.read_text().strip(), tmp_path)


def test_run_hidden_starts_the_command(flows, tmp_path):
    marker = tmp_path / "marker.txt"
    runs = run_all(flows, [element_flow("run_hidden", "Action_Run", ToRun=f'cmd.exe /c "echo ok > {marker}"',
                                        RunMode="Hide")])
    assert not runs[0].exceptions, runs[0].steps
    assert wait_for(marker.exists)


def test_run_a_following_working_directory_must_exist(flows, tmp_path):
    runs = run_all(flows, [element_flow("run_no_dir", "Action_Run", ToRun="cmd.exe /c exit",
                                        WhichWorkingDir="Specified", WorkingDir=str(tmp_path / "none"))])
    assert "does not exist" in message_of(runs[0])


def test_run_a_missing_program_is_an_exception_with_the_v1_text(flows, tmp_path):
    missing = str(tmp_path / "no_such_program_wi0123.exe")
    runs = run_all(flows, [element_flow("run_missing", "Action_Run", ToRun=missing)])
    assert message_of(runs[0]).startswith("Can't run '")


# --- Kill process -------------------------------------------------------------------------------------------------------
def test_kill_by_pid_ends_only_that_process(flows, child):
    runs = run_all(flows, [element_flow("kill_pid", "Action_Kill_Process", ProcessName=str(child.pid))])
    assert not runs[0].exceptions, runs[0].steps
    # ProcessClose ends the process with exit code 0 (TerminateProcess), so only the end is checked, not the code
    assert child.wait(timeout=scaled(20)) is not None and not alive(child)


def test_kill_by_name_ends_only_the_copy_with_that_name(flows, named_copy):
    name, proc = named_copy
    runs = run_all(flows, [element_flow("kill_name", "Action_Kill_Process", ProcessName=name)])
    assert not runs[0].exceptions, runs[0].steps
    assert wait_for(lambda: not alive(proc))


def test_kill_a_process_that_does_not_exist_is_an_exception(flows):
    runs = run_all(flows, [element_flow("kill_none", "Action_Kill_Process",
                                        ProcessName="ahf_wi0123_none_" + uuid.uuid4().hex[:8] + ".exe")])
    assert "does not exist" in message_of(runs[0])


def test_an_empty_process_name_is_an_exception(flows):
    """MIGRATION M-0120: a blank name is refused in all three process elements and the condition."""
    runs = run_all(flows, [
        element_flow("kill_empty", "Action_Kill_Process", ProcessName="  "),
        element_flow("priority_empty", "Action_Set_Process_Priority", ProcessName="", Priority="High"),
        condition_flow("running_empty", "Condition_Process_Is_Running", ProcessName=""),
    ])
    assert all(r.exceptions for r in runs), [r.steps for r in runs]
    assert "Process name or ID is empty" in message_of(runs[0])


# --- Set process priority -----------------------------------------------------------------------------------------------
def test_set_priority_changes_the_priority_class_of_that_process(flows, child):
    expected = {"BelowNormal": psutil.BELOW_NORMAL_PRIORITY_CLASS, "High": psutil.HIGH_PRIORITY_CLASS}
    runs = run_all(flows, [element_flow("priority_" + level, "Action_Set_Process_Priority",
                                        ProcessName=str(child.pid), Priority=level) for level in expected])
    assert not any(r.exceptions for r in runs), [r.steps for r in runs]
    assert psutil.Process(child.pid).nice() == expected["High"]


def test_set_priority_of_a_missing_process_is_an_exception(flows):
    runs = run_all(flows, [element_flow("priority_none", "Action_Set_Process_Priority",
                                        ProcessName="ahf_wi0123_none_" + uuid.uuid4().hex[:8] + ".exe", Priority="Low")])
    assert "does not exist" in message_of(runs[0])


# --- Condition Process is running ---------------------------------------------------------------------------------------
def test_process_is_running_by_pid_and_by_name(flows, child, named_copy):
    name, proc = named_copy
    runs = run_all(flows, [
        condition_flow("running_pid", "Condition_Process_Is_Running", ProcessName=str(child.pid)),
        condition_flow("running_name", "Condition_Process_Is_Running", ProcessName=name),
        condition_flow("running_none", "Condition_Process_Is_Running",
                       ProcessName="ahf_wi0123_none_" + uuid.uuid4().hex[:8] + ".exe"),
    ])
    assert [answer(r) for r in runs] == ["YES", "YES", "NO"]
