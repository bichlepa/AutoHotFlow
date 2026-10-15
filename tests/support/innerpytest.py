"""Starts a pytest of its own for the tests of the test tooling (WI-0059), with a private registry, history and run
log folder, so it never touches the real ones (%TEMP%\\ahf_runs, temp/history of the main checkout, ahf_testruns)."""

import json
import os
import subprocess
import sys
from pathlib import Path

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
