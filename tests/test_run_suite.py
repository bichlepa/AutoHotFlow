"""tools/run_suite.py: runs the suite in a worktree of a commit (see the docstring of the tool)."""

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]
TOOL = REPO / "tools" / "run_suite.py"
sys.path.insert(0, str(REPO / "tools"))

import run_suite  # noqa: E402


@pytest.mark.parametrize("args, expected", [
    (["tests", "-q"], False),
    (["tests", "-m", "stress"], True),
    (["tests", "-m", "soak"], True),
    (["tests", "-mstress"], True),
    (["tests", "-m", "slow and not stress"], True),      # conservative: the word is there
    (["tests", "-m", "slow"], False),
    (["tests/stress", "-q"], False),                     # a path is not a request; the conftest drops full-size tests
    (["tests", "-k", "stress"], False),
])
def test_exclusive_runs_are_recognized(args, expected):
    assert run_suite.is_exclusive(args) is expected


@pytest.mark.slow
def test_run_in_a_worktree_leaves_no_worktree_and_a_result(tmp_path):
    """End to end on HEAD with a tiny test file; the runs folder is private to this test."""
    env = dict(os.environ, AHF_RUNS_DIR=str(tmp_path))
    proc = subprocess.run([sys.executable, str(TOOL), "--workers", "0", "--", "tests/test_no_v1_dependency.py", "-q"],
                          cwd=str(REPO), env=env, capture_output=True, timeout=180)
    out = proc.stdout.decode("utf-8", "replace")
    assert proc.returncode == 0, out + proc.stderr.decode("utf-8", "replace")
    runs = [p for p in tmp_path.iterdir() if (p / "status.json").exists()]
    assert len(runs) == 1
    status = json.loads((runs[0] / "status.json").read_text(encoding="utf-8"))
    assert status["state"] == "finished" and status["exitCode"] == 0 and status["worktreeKept"] is False
    assert not (runs[0] / "tree").exists(), "the worktree must be removed"
    assert (runs[0] / "output.txt").read_text(encoding="utf-8", errors="replace").strip(), "no output kept"
    listed = subprocess.run(["git", "worktree", "list", "--porcelain"], cwd=str(REPO), capture_output=True).stdout
    assert str(runs[0]).replace("\\", "/").encode() not in listed.replace(b"\\", b"/"), "worktree still registered"


@pytest.mark.slow
def test_a_failing_run_returns_the_exit_code_of_pytest(tmp_path):
    env = dict(os.environ, AHF_RUNS_DIR=str(tmp_path))
    proc = subprocess.run([sys.executable, str(TOOL), "--workers", "0", "--", "tests/does_not_exist.py", "-q"],
                          cwd=str(REPO), env=env, capture_output=True, timeout=120)
    assert proc.returncode not in (0, run_suite.EXIT_TOOL_FAILED), proc.stdout.decode("utf-8", "replace")
