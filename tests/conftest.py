"""Shared fixtures for the AutoHotFlow v2 test suite (see doc/TESTSTRATEGIE.md).

Environment variables:
  AHF_AHK2_EXE   path to the AutoHotkey v2 interpreter (default: C:\\Program Files\\AutoHotkey\\v2\\AutoHotkey64.exe)
  AHF_TEST_KEEP  set to 1 to keep the temporary data directories after a test
"""

import itertools
import json
import os
import shutil
import subprocess
import tempfile
import uuid
from dataclasses import dataclass, field
from pathlib import Path

import pytest

from support import ahk as ahk_locator
from support import wirebool
from support.procs import ProcessTracker

TESTS_DIR = Path(__file__).resolve().parent
RUN_COUNTER = itertools.count(1)


@pytest.hookimpl(tryfirst=True)
def pytest_cmdline_main(config):
    """Measurements must never run in parallel with other load (idle CPU, latency, memory): a run that asks
    for stress or soak tests (-m stress / -m soak) is switched to a single process, whatever pytest.ini says."""
    asked = config.getoption("markexpr") or ""
    if ("stress" in asked or "soak" in asked) and getattr(config.option, "numprocesses", 0):
        config.option.numprocesses = 0
        config.option.dist = "no"


def pytest_configure(config):
    config.addinivalue_line("markers", "stress: long-running stress test, run with -m stress")
    config.addinivalue_line("markers", "soak: endurance test (minutes), run with -m soak")
    config.addinivalue_line("markers", "fault: fault injection test (kill, freeze, timeout)")


def pytest_collection_modifyitems(config, items):
    # Stress and soak tests (full size) only run when asked for with -m (the default run keeps their smoke variants).
    asked = config.getoption("markexpr") or ""
    for marker in ("stress", "soak"):
        if marker not in asked:
            kept = [i for i in items if i.get_closest_marker(marker) is None]
            if len(kept) != len(items):
                config.hook.pytest_deselected(items=[i for i in items if i not in kept])
                items[:] = kept
    # Hard limit per test, so nothing hangs unnoticed (pytest-timeout).
    for item in items:
        if item.get_closest_marker("timeout") is None:
            item.add_marker(pytest.mark.timeout(120))


@pytest.fixture(autouse=True)
def strict_wire_booleans():
    """A frame that a Python test peer decoded and that carries 1/0 in a boolean protocol field fails the test (WI-26)."""
    wirebool.take_violations()
    yield
    bad = wirebool.take_violations()
    assert not bad, "boolean protocol fields not sent as JSON true/false: " + "; ".join(bad[:10])


@pytest.fixture(scope="session")
def ahk_exe():
    """Path to the AutoHotkey v2 interpreter. Skips the test if it is not installed."""
    path, reason = ahk_locator.find_ahk_exe()
    if path is None:
        pytest.skip(reason)
    return path


@pytest.fixture
def datadir(request):
    """A fresh temporary data directory for one test. Kept if AHF_TEST_KEEP=1."""
    path = tempfile.mkdtemp(prefix="ahf-test-")
    yield Path(path)
    if os.environ.get("AHF_TEST_KEEP") == "1":
        print("\nAHF_TEST_KEEP: data directory kept at " + path)
    else:
        shutil.rmtree(path, ignore_errors=True)


@pytest.fixture
def session_id():
    """A unique session id, used in pipe names so parallel tests do not collide."""
    return "t" + uuid.uuid4().hex[:12]


@pytest.fixture
def procs():
    """Process tracker. Everything started through it is killed with its children at teardown."""
    tracker = ProcessTracker()
    yield tracker
    survivors = tracker.close()
    assert not survivors, "processes left behind by the test: %s" % survivors


@dataclass
class RunResult:
    returncode: "int | None"
    timed_out: bool
    stdout: str
    stderr: str
    out_path: Path
    records: list = field(default_factory=list)

    @property
    def ok(self):
        return not self.timed_out and self.returncode == 0


@pytest.fixture
def run_ahk(ahk_exe, datadir, procs):
    """Runs an AHK script as a process and waits for it.

    Convention: the script receives the result file path as its FIRST argument
    (see tests/ahk/lib/Assert.ahk). The file is returned as `out_path`, and its JSON
    lines are parsed into `records`. A run longer than `timeout` seconds is killed
    together with its children and reported as timed_out.
    """

    def run(script, *args, timeout=60):
        n = next(RUN_COUNTER)
        out_path = datadir / ("out-%d.jsonl" % n)
        stdout_path = datadir / ("run-%d.stdout" % n)
        stderr_path = datadir / ("run-%d.stderr" % n)
        script_path = Path(script).resolve()
        with open(stdout_path, "wb") as out, open(stderr_path, "wb") as err:
            proc = procs.start([ahk_exe, "/ErrorStdOut=UTF-8", str(script_path), str(out_path), *map(str, args)],
                               stdout=out, stderr=err, cwd=str(script_path.parent))
            try:
                returncode = proc.wait(timeout=timeout)
                timed_out = False
            except subprocess.TimeoutExpired:
                procs.kill(proc)
                returncode = None
                timed_out = True
        stdout = stdout_path.read_bytes().decode("utf-8", "replace")
        stderr = stderr_path.read_bytes().decode("utf-8", "replace")
        # load-time errors arrive on stdout/stderr thanks to /ErrorStdOut; dialogs are caught by the watcher
        from ahf_dialogwatch import shared_watcher
        for ev in shared_watcher().events(proc.pid):
            stderr += ev.summary() + "\n"
        return RunResult(returncode, timed_out, stdout, stderr, out_path, read_records(out_path))

    return run


def read_records(path):
    """Parses a JSON-lines result file. A missing file gives an empty list."""
    if not Path(path).exists():
        return []
    records = []
    text = Path(path).read_text(encoding="utf-8-sig")
    for line in text.splitlines():
        if line.strip():
            records.append(json.loads(line))
    return records
