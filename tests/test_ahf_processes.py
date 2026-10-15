"""Tests of the logic of tools/ahf_processes.py that needs no window (the GUI is checked by hand)."""

import os
import subprocess
import sys
import time

import psutil
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import ahf_processes as ap  # noqa: E402


def test_filter_lists_ahf_processes():
    assert ap.is_ahf_process("AutoHotkey64.exe", [r"C:\ahk\AutoHotkey64.exe", r"C:\git\AutoHotFlow\src\AutoHotFlow.ahk"])
    assert ap.is_ahf_process("AutoHotkey64.exe", ["x.exe", r"C:\git\AutoHotFlow-wt\proctool\src\entry\engine.ahk"])
    assert ap.is_ahf_process("AutoHotkey64.exe", ["x.exe", r"C:\Temp\ahf_runs\1\worktree\src\a.ahk"])
    assert ap.is_ahf_process("AutoHotkeyU32.exe", ["x.exe", r"D:\AUTOHOTFLOW\a.ahk"])
    assert ap.is_ahf_process("AutoHotFlow.exe", [r"C:\old\AutoHotFlow\AutoHotFlow.exe", "a.ahk"])


def test_filter_skips_other_scripts():
    assert not ap.is_ahf_process("AutoHotkey64.exe", ["x.exe", r"C:\Users\me\Allgemeine Hilfe.ahk"])
    assert not ap.is_ahf_process("python.exe", ["python", r"C:\git\AutoHotFlow\tools\ahkrun.py"])
    assert not ap.is_ahf_process("AutoHotkey64.exe", None)
    assert not ap.is_ahf_process(None, ["AutoHotFlow"])


def test_find_never_lists_own_process():
    assert os.getpid() not in [p["pid"] for p in ap.find_ahf_processes()]


def test_short_args():
    cmd = ["AutoHotkey64.exe", "/ErrorStdOut=UTF-8", r"C:\git\AutoHotFlow\src\AutoHotFlow.ahk", "--role=engine"]
    assert ap.short_args(cmd) == "AutoHotFlow.ahk --role=engine"


@pytest.mark.parametrize("seconds,text", [(0, "0 s"), (12.7, "12 s"), (185, "3 min 05 s"), (7620, "2 h 07 min"),
                                          (3 * 86400 + 4 * 3600, "3 d 4 h"), (-5, "0 s")])
def test_format_duration(seconds, text):
    assert ap.format_duration(seconds) == text


def test_format_start_shape():
    assert len(ap.format_start(time.time())) == 19


def test_kill_refuses_own_pid():
    with pytest.raises(ValueError):
        ap.kill_process(os.getpid())


def test_kill_vanished_process_reports_instead_of_raising():
    p = subprocess.Popen([sys.executable, "-c", "pass"])
    p.wait()
    ended, problems = ap.kill_process(p.pid)
    assert ended == [] and problems


def test_kill_ends_process_and_children():
    code = ("import subprocess,sys,time;"
            "c=subprocess.Popen([sys.executable,'-c','import time;time.sleep(60)']);"
            "print(c.pid,flush=True);time.sleep(60)")
    parent = subprocess.Popen([sys.executable, "-c", code], stdout=subprocess.PIPE, text=True)
    try:
        child_pid = int(parent.stdout.readline())
        ended, problems = ap.kill_process(parent.pid, with_children=True)
        assert parent.pid in ended and child_pid in ended and not problems
        parent.wait(timeout=10)
        deadline = time.time() + 10
        while psutil.pid_exists(child_pid) and time.time() < deadline:
            time.sleep(0.1)
        assert not psutil.pid_exists(child_pid)
    finally:
        parent.kill()
        parent.stdout.close()
