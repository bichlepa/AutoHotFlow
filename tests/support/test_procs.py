"""Process helpers: tree kill, suspend/resume, cleanup at interpreter exit."""

import subprocess
import sys
import time
from pathlib import Path

import psutil

from support.procs import ProcessTracker

TESTS_DIR = Path(__file__).resolve().parent.parent

# A python process that starts a child and sleeps. Prints the child's pid.
PARENT_WITH_CHILD = (
    "import subprocess, sys, time\n"
    "c = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(120)'])\n"
    "print(c.pid, flush=True)\n"
    "time.sleep(120)\n"
)


def _sleeper(tracker, seconds=120):
    return tracker.start([sys.executable, "-c", "import time; time.sleep(%d)" % seconds])


def test_close_kills_process_and_its_children():
    tracker = ProcessTracker()
    proc = tracker.start([sys.executable, "-c", PARENT_WITH_CHILD], stdout=subprocess.PIPE)
    child_pid = int(proc.stdout.readline())
    assert psutil.pid_exists(child_pid)
    survivors = tracker.close()
    assert survivors == []
    assert not psutil.pid_exists(proc.pid) or psutil.Process(proc.pid).status() == psutil.STATUS_ZOMBIE
    assert not psutil.pid_exists(child_pid) or psutil.Process(child_pid).status() == psutil.STATUS_ZOMBIE


def test_suspend_and_resume():
    tracker = ProcessTracker()
    try:
        proc = _sleeper(tracker)
        assert tracker.alive(proc)
        tracker.suspend(proc)
        # The status follows the thread states with a lag of a few ms (measured: up to ~70 ms in 30 runs
        # through ProcessTracker), so poll for it instead of checking once.
        deadline = time.monotonic() + 2.0
        while psutil.Process(proc.pid).status() != psutil.STATUS_STOPPED and time.monotonic() < deadline:
            time.sleep(0.01)
        assert psutil.Process(proc.pid).status() == psutil.STATUS_STOPPED
        tracker.resume(proc)
        time.sleep(0.2)
        assert psutil.Process(proc.pid).status() != psutil.STATUS_STOPPED
    finally:
        assert tracker.close() == []


def test_exited_process_is_not_touched():
    tracker = ProcessTracker()
    proc = tracker.start([sys.executable, "-c", "pass"])
    proc.wait(timeout=10)
    assert tracker.close() == []


def test_tracked_process_is_killed_when_interpreter_exits(tmp_path):
    """Covers Ctrl+C-like exits: the atexit hook must remove the child tree."""
    pid_file = tmp_path / "pid.txt"
    driver = (
        "import sys, time\n"
        "sys.path.insert(0, %r)\n"
        "from support.procs import ProcessTracker\n"
        "t = ProcessTracker()\n"
        "p = t.start([sys.executable, '-c', 'import time; time.sleep(120)'])\n"
        "open(%r, 'w').write(str(p.pid))\n"
        "raise KeyboardInterrupt\n"
    ) % (str(TESTS_DIR), str(pid_file))
    result = subprocess.run([sys.executable, "-c", driver], cwd=str(TESTS_DIR), timeout=60,
                            capture_output=True)
    assert result.returncode != 0
    child_pid = int(pid_file.read_text())
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if not psutil.pid_exists(child_pid) or psutil.Process(child_pid).status() == psutil.STATUS_ZOMBIE:
            break
        time.sleep(0.05)
    assert not psutil.pid_exists(child_pid) or psutil.Process(child_pid).status() == psutil.STATUS_ZOMBIE
