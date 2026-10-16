"""tools/test_history.py and tools/recheck.py (WI-0059 part C) on prepared history files in a tmp folder."""

import io
import subprocess
import sys
from pathlib import Path

import pytest

from support import history, innerpytest

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools"))

import recheck  # noqa: E402
import test_history  # noqa: E402

SHA_A = "a" * 40
SHA_B = "b" * 40


@pytest.fixture
def prepared(tmp_path):
    innerpytest.fake_record(tmp_path, "r1", 1, SHA_A, [("t::flaky", "passed", 1.0, 5.0), ("t::steady", "passed", 0.2, 5.0),
                                        ("t::slower", "passed", 1.0, 5.0)])
    innerpytest.fake_record(tmp_path, "r2", 2, SHA_A, [("t::flaky", "failed", 1.5, 80.0), ("t::steady", "passed", 0.2, 80.0)])
    innerpytest.fake_record(tmp_path, "r3", 3, SHA_A, [("t::dirty", "failed", 1.0, 5.0)], dirty=True)
    innerpytest.fake_record(tmp_path, "r4", 4, SHA_A, [("t::dirty", "passed", 1.0, 5.0)])
    innerpytest.fake_record(tmp_path, "r5", 5, SHA_B, [("t::slower", "passed", 3.0, 5.0), ("t::other", "failed", 0.1, 30.0)])
    return tmp_path


def _run(*argv):
    out = io.StringIO()
    code = test_history.main(list(argv), out=out)
    return code, out.getvalue()


def test_flaky_finds_red_and_green_at_the_same_commit(prepared):
    """Acceptance criterion of WI-0059: --flaky finds a test that is red and green at the same commit; a red result of
    a run with uncommitted changes does not count."""
    found = test_history.flaky(history.load_records(prepared))
    assert list(found) == [(SHA_A, "t::flaky")]
    code, out = _run("--flaky", "--dir", str(prepared))
    assert code == 0
    assert "t::flaky  at aaaaaaaa" in out and "red   1 x  80/90" in out and "green 1 x  5/15" in out
    assert "t::dirty" not in out


def test_last_lists_the_runs_with_commit_counts_load_and_log(prepared):
    code, out = _run("--last", "2", "--dir", str(prepared))
    assert code == 0 and "(5 runs)" in out
    lines = [line for line in out.splitlines() if line.startswith("2026")]
    assert len(lines) == 2
    assert "aaaaaaaa " in lines[0] and "1 passed" in lines[0] and "log-r4" in lines[0]
    assert "bbbbbbbb " in lines[1] and "1 passed, 1 failed" in lines[1] and "20%" in lines[1]


def test_one_test_over_the_runs(prepared):
    code, out = _run("--test", "t::flaky", "--dir", str(prepared))
    assert code == 0
    assert [line.split()[3] for line in out.splitlines()[2:]] == ["passed", "failed"]
    assert _run("--test", "nothing", "--dir", str(prepared))[0] == 1


def test_load_buckets_show_the_red_rate(prepared):
    rows = {r["bucket"]: r for r in test_history.load_buckets(history.load_records(prepared))}
    assert rows["0-10 %"]["results"] == 6 and rows["0-10 %"]["red"] == 1
    assert rows["75-100 %"]["results"] == 2 and rows["75-100 %"]["redRate"] == 50.0
    assert _run("--load", "--dir", str(prepared))[0] == 0


def test_durations_find_a_test_that_got_slower(prepared):
    found = test_history.duration_growth(history.load_records(prepared))
    assert [f[0] for f in found] == ["t::slower"]
    code, out = _run("--durations", "--dir", str(prepared))
    assert "t::slower" in out and "x3.0" in out


def test_since_filters_the_runs(prepared):
    assert "(0 runs)" in _run("--since", "2099-01-01", "--dir", str(prepared))[1]


def test_recheck_picks_the_red_tests_and_the_tier_of_the_run(prepared):
    records = history.load_records(prepared)
    assert recheck.find_run(records, "latest")["run"]["id"] == "r5"
    assert recheck.find_run(records, "r2")["run"]["id"] == "r2"
    assert recheck.red_tests(recheck.find_run(records, "r2")) == ["t::flaky"]
    rec = {"run": {"args": ["tests", "-q", "--all"], "markexpr": "not gui"}}
    assert recheck.tier_args(rec) == ["--all", "-m", "not gui"]


def test_recheck_stops_for_a_run_with_uncommitted_changes(prepared, monkeypatch, capsys):
    """A dirty run cannot be reproduced from its commit: recheck says so and runs nothing (exit 3), unless --here."""
    monkeypatch.setenv("AHF_HISTORY_DIR", str(prepared))
    assert recheck.main(["r3"]) == recheck.EXIT_NOT_REPRODUCIBLE
    assert "had uncommitted changes" in capsys.readouterr().out
    assert recheck.main(["r3", "--here", "--dry-run"]) == 0
    out = capsys.readouterr().out
    assert "recheck at working tree" in out and "t::dirty" in out


def test_recheck_runs_a_clean_run_at_its_commit(prepared, monkeypatch, capsys):
    monkeypatch.setenv("AHF_HISTORY_DIR", str(prepared))
    assert recheck.main(["r2", "--dry-run"]) == 0
    assert "recheck at commit aaaaaaaa (own worktree)" in capsys.readouterr().out
