"""Load figures and run history (WI-0059 parts B and C: tests/support/loadsampler.py, history.py, runrecord.py).
Pure unit tests, no job object and no pytest of their own; those are in tests/test_runtool_runs.py (foundation)."""

import subprocess
import time
from pathlib import Path

from support import history, loadsampler
from support.loadsampler import Sample


def _samples(values, t0=1000.0):
    """One sample per second: (sys, own) pairs."""
    return [Sample(t0 + i + 1, s, o, 1 + (i == 2), 3) for i, (s, o) in enumerate(values)]


def test_window_stats_take_the_samples_that_overlap_the_window():
    samples = _samples([(10, 5), (50, 10), (90, 10), (20, 0)])       # t = 1001 .. 1004
    stats = loadsampler.window_stats(samples, 1001.2, 1002.5)        # overlaps (1001,1002] and (1002,1003]
    assert stats == {"sysMean": 70.0, "sysPeak": 90.0, "extMean": 60.0, "extPeak": 80.0, "runsMax": 2}


def test_a_window_shorter_than_one_sample_gets_the_covering_sample():
    samples = _samples([(10, 5), (50, 10)])
    assert loadsampler.window_stats(samples, 1001.3, 1001.4)["sysMean"] == 50.0
    assert loadsampler.window_stats([], 0, 1) is None


def test_external_load_is_clamped_at_zero():
    assert Sample(0, 10.0, 30.0, 1, 1).ext == 0.0


def test_run_stats_cover_the_whole_run():
    stats = loadsampler.run_stats(_samples([(10, 5), (50, 10), (90, 10)]))
    assert stats["sysMean"] == 50.0 and stats["extPeak"] == 80.0 and stats["samples"] == 3 and stats["procsPeak"] == 3


def _git(cwd, *args):
    subprocess.run(["git", *args], cwd=str(cwd), check=True, capture_output=True)


def test_two_worktrees_write_into_the_same_history_folder(tmp_path, monkeypatch):
    """Acceptance criterion of WI-0059: the history folder is temp/history of the main checkout, found through
    git rev-parse --git-common-dir, from the main checkout and from every worktree."""
    monkeypatch.delenv("AHF_HISTORY_DIR", raising=False)
    main = tmp_path / "main"
    main.mkdir()
    _git(main, "init", "-q")
    (main / "a.txt").write_text("a", encoding="utf-8")
    _git(main, "add", "a.txt")
    _git(main, "-c", "user.name=t", "-c", "user.email=t@example.invalid", "commit", "-q", "-m", "a")
    _git(main, "worktree", "add", "-q", "--detach", str(tmp_path / "wt"))
    from_main = history.history_dir(cwd=main)
    from_wt = history.history_dir(cwd=tmp_path / "wt")
    assert from_main == from_wt == (main / "temp" / "history").resolve()
    record = {"run": {"id": "x", "startEpoch": time.time()}}
    history.write_record(from_main, record)
    record2 = {"run": {"id": "y", "startEpoch": time.time()}}
    history.write_record(from_wt, record2)
    assert sorted(r["run"]["id"] for r in history.load_records(from_main)) == ["x", "y"]


def test_history_falls_back_to_the_runs_folder_without_a_checkout(tmp_path, monkeypatch):
    monkeypatch.delenv("AHF_HISTORY_DIR", raising=False)
    monkeypatch.setenv("AHF_RUNS_DIR", str(tmp_path / "runs"))
    (tmp_path / "nogit").mkdir()
    monkeypatch.setenv("GIT_CEILING_DIRECTORIES", str(tmp_path))
    assert history.history_dir(cwd=tmp_path / "nogit") == tmp_path / "runs" / "history"


def test_the_override_wins(tmp_path, monkeypatch):
    monkeypatch.setenv("AHF_HISTORY_DIR", str(tmp_path / "h"))
    assert history.history_dir(cwd=Path.cwd()) == tmp_path / "h"


def test_broken_history_files_are_skipped(tmp_path):
    (tmp_path / "broken.json").write_text("{", encoding="utf-8")
    (tmp_path / "other.json").write_text("[]", encoding="utf-8")
    history.write_record(tmp_path, {"run": {"id": "ok", "startEpoch": 1.0}})
    assert [r["run"]["id"] for r in history.load_records(tmp_path)] == ["ok"]


def _wait_samples(sampler, n=3):
    deadline = time.time() + 10                       # a loaded machine delays the thread: wait for the state
    while len(sampler.samples) < n and time.time() < deadline:
        time.sleep(0.02)
    sampler.stop()


class _NoJob:
    def __init__(self):
        raise OSError(5, "AssignProcessToJobObject failed (simulated: already in a job that forbids nesting)")


class _JobThatBreaks:
    calls = 0

    def read(self):
        type(self).calls += 1
        if type(self).calls > 2:
            raise OSError(6, "QueryInformationJobObject failed (simulated)")
        return float(type(self).calls), 1


def test_without_a_job_the_sampler_falls_back_to_psutil(monkeypatch):
    """Owner's condition for the job object (WI-0059 follow-up): if the job cannot be created or assigned, the sampler
    measures the own tree with psutil and says so (history field load.ownTree); the run does not abort."""
    monkeypatch.setattr(loadsampler, "_JobCpu", _NoJob)
    sampler = loadsampler.LoadSampler(interval=0.05).start()
    _wait_samples(sampler)
    assert sampler.method == "psutil" and len(sampler.samples) >= 3


def test_a_job_that_fails_during_the_run_switches_to_psutil(monkeypatch):
    monkeypatch.setattr(loadsampler, "_JobCpu", _JobThatBreaks)
    sampler = loadsampler.LoadSampler(interval=0.05).start()
    _wait_samples(sampler)
    assert sampler.method == "psutil" and len(sampler.samples) >= 2
