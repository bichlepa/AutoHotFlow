"""Starts a pytest of its own for the tests of the test tooling (WI-0059), with a private registry, history and run
log folder, so it never touches the real ones (%TEMP%\\ahf_runs, temp/history of the main checkout, ahf_testruns)."""

import json
import os
import subprocess
import sys
from pathlib import Path

import psutil

from support import admission, history

REPO = Path(__file__).resolve().parents[2]
PROBES = "tests/support/runtool_probes.py"

# set by the surrounding run; an inner run with them would count as part of that run (no admission, no history)
INHERITED = ("AHF_TESTRUN_DIR", "AHF_ADMITTED", "AHF_NO_ADMISSION", "AHF_LOAD_SAMPLER", "AHF_MAX_WORKERS",
             "AHF_ADMISSION_TIMEOUT", "PYTEST_ADDOPTS", "PYTEST_CURRENT_TEST")


def env_for(tmp_path, **extra):
    env = {k: v for k, v in os.environ.items() if k not in INHERITED and not k.startswith("PYTEST_XDIST")}
    env.update(AHF_RUNS_DIR=str(tmp_path / "runs"), AHF_HISTORY_DIR=str(tmp_path / "history"),
               AHF_TEST_LOGS=str(tmp_path / "testruns"), PYTHONUNBUFFERED="1")
    env.update({k: str(v) for k, v in extra.items()})
    return env


def command(*args):
    return [sys.executable, "-m", "pytest", "-p", "no:cacheprovider", *args]


def start(tmp_path, *args, **extra):
    return subprocess.Popen(command(*args), cwd=str(REPO), env=env_for(tmp_path, **extra), stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def run(tmp_path, *args, timeout=120, **extra):
    proc = subprocess.run(command(*args), cwd=str(REPO), env=env_for(tmp_path, **extra), stdin=subprocess.DEVNULL,
                          capture_output=True, timeout=timeout)
    return proc.returncode, proc.stdout.decode("utf-8", "replace"), proc.stderr.decode("utf-8", "replace")


def records(tmp_path):
    folder = tmp_path / "history"
    if not folder.is_dir():
        return []
    found = [json.loads(p.read_text(encoding="utf-8")) for p in sorted(folder.glob("*.json"))]
    return sorted(found, key=lambda r: r["run"]["startEpoch"])


def register_run(base, name, workers, pid=None, exclusive=False, state="running"):
    """A registry entry of a (fake) run, alive as long as `pid` (default: this process) lives."""
    run_dir = Path(base) / name
    run_dir.mkdir(parents=True)
    pid = pid or os.getpid()
    admission.write_status(run_dir, id=name, state=state, pid=pid, pidCreated=psutil.Process(pid).create_time(),
                           workers=workers, exclusive=exclusive)
    return run_dir


def fake_record(folder, run_id, start, sha, tests, dirty=False, complete=True, recheck_of=None, args=("tests", "-q")):
    """A history record as the conftest writes it, with only the fields the readers use. tests: (id, outcome,
    duration, extMean) tuples."""
    rec = {"schema": 1, "complete": complete,
           "run": {"id": run_id, "start": "2026-10-15T10:00:%02d" % (start % 60), "startEpoch": 1_790_000_000 + start,
                   "durationS": 12.0, "args": list(args), "markexpr": "", "recheckOf": recheck_of,
                   "startedBy": "direct"},
           "code": {"sha": sha, "branch": "x", "dirty": dirty, "worktree": "w"},
           "logs": {"runLog": "log-" + run_id},
           "load": {"extMean": 20.0},
           "counts": {},
           "tests": []}
    for test_id, outcome, duration, ext in tests:
        rec["tests"].append({"id": test_id, "outcome": outcome, "duration": duration, "extMean": ext,
                             "sysMean": ext + 10, "extPeak": ext, "sysPeak": ext + 10, "runsMax": 1})
        rec["counts"][outcome] = rec["counts"].get(outcome, 0) + 1
    return history.write_record(folder, rec)
