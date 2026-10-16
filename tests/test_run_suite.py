"""tools/run_suite.py: runs the suite in a worktree of a commit (see the docstring of the tool). The end-to-end runs
are in tests/test_runtool_runs.py (foundation)."""

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
    (["tests", "-m", "slow and not stress"], False),     # cannot select a stress test (WI-0059 follow-up)
    (["tests", "-m", "not stress"], False),
    (["tests", "-m", "idle"], True),
    (["tests", "-m", "slow"], False),
    (["tests/stress", "-q"], False),                     # a path is not a request; the conftest drops full-size tests
    (["tests", "-k", "stress"], False),
])
def test_exclusive_runs_are_recognized(args, expected):
    assert run_suite.is_exclusive(args) is expected


def test_two_runs_of_the_same_commit_in_the_same_second_get_their_own_folder(tmp_path):
    """Two runs started in the same second shared one folder and one worktree: the second removed the worktree of the
    first (seen in WI-0042: the first ran no tests, the second failed with 'already exists')."""
    first = run_suite.new_run_dir(tmp_path, "20261014-172526-782586e3")
    second = run_suite.new_run_dir(tmp_path, "20261014-172526-782586e3")
    third = run_suite.new_run_dir(tmp_path, "20261014-172526-782586e3")
    assert [first[0], second[0], third[0]] == ["20261014-172526-782586e3", "20261014-172526-782586e3-2",
                                               "20261014-172526-782586e3-3"]
    assert all(d.is_dir() for _, d in (first, second, third))
