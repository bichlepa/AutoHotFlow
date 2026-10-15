"""Probe tests for the tests of the test tooling (admission, load figures, history, recheck; WI-0059).

Not collected by a normal run (the file name does not match test_*.py); the tests of the tooling start a pytest of
their own with this file as an explicit argument. AHF_PROBE selects the behaviour, comma separated:
  sleep=<s>        test_probe_pass sleeps that long (keeps a run busy, for the concurrency test)
  fail             test_probe_fail fails
  interrupt        test_probe_interrupt raises KeyboardInterrupt (ends the run as Ctrl+C would)
  load=<dir>       the three load probes run (about 3 s each, see below), coordinated through files in <dir>
Without AHF_PROBE every probe passes at once.
"""

import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

BURN = "while True: pass"
LOAD_WINDOW_S = 3.0


def _modes():
    modes = {}
    for part in os.environ.get("AHF_PROBE", "").split(","):
        if part.strip():
            key, _, value = part.strip().partition("=")
            modes[key] = value
    return modes


def burners(count, idle_priority=True):
    """count busy-loop processes; idle priority, so they take only CPU that nobody else wants."""
    flags = 0x00000040 if idle_priority and sys.platform == "win32" else 0        # IDLE_PRIORITY_CLASS
    return [subprocess.Popen([sys.executable, "-c", BURN], creationflags=flags) for _ in range(count)]


def stop_burners(procs):
    for p in procs:
        p.kill()
    for p in procs:
        p.wait(timeout=10)


def test_probe_pass():
    time.sleep(float(_modes().get("sleep") or 0))


def test_probe_fail():
    if "fail" in _modes():
        assert 1 == 2, "probe failure on request"


def test_probe_interrupt():
    if "interrupt" in _modes():
        raise KeyboardInterrupt


def test_probe_load_quiet():
    """Nothing runs: the reference."""
    if "load" in _modes():
        time.sleep(LOAD_WINDOW_S)


def test_probe_load_external():
    """The calling test burns the cores from outside this run while this test waits."""
    folder = _modes().get("load")
    if not folder:
        return
    (Path(folder) / "external.request").write_text("go", encoding="utf-8")
    deadline = time.time() + 30
    while not (Path(folder) / "external.running").exists():
        if time.time() > deadline:
            pytest.fail("the external load did not start")
        time.sleep(0.05)
    time.sleep(LOAD_WINDOW_S)
    (Path(folder) / "external.done").write_text("done", encoding="utf-8")


def test_probe_load_own():
    """This run burns the cores itself: the CPU belongs to the own process tree, not to the external load."""
    if "load" not in _modes():
        return
    procs = burners(os.cpu_count() or 2)
    try:
        time.sleep(LOAD_WINDOW_S)
    finally:
        stop_burners(procs)
