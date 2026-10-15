"""Load figures and run history (WI-0059 parts B and C: tests/support/loadsampler.py, history.py, runrecord.py).
Every pytest started here uses its own registry, history and run log folder (tests/support/innerpytest.py)."""

import os
import subprocess
import time
from pathlib import Path

import pytest

from support import history, innerpytest, loadsampler, runtool_probes
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


def test_the_sampler_measures_and_stops():
    sampler = loadsampler.LoadSampler(interval=0.1).start()
    time.sleep(0.45)
    sampler.stop()
    assert len(sampler.samples) >= 3
    assert all(0.0 <= s.sys <= 100.0 and 0.0 <= s.ext <= 100.0 for s in sampler.samples)
    assert sampler.method in ("job", "tree")


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


def _check_record(rec):
    assert rec["schema"] == history.SCHEMA
    assert len(rec["code"]["sha"]) == 40 and isinstance(rec["code"]["dirty"], bool) and rec["code"]["worktree"]
    assert rec["logs"]["runLog"] and Path(rec["logs"]["runLog"]).is_dir()
    assert rec["load"] is not None and rec["load"]["samples"] >= 1 and "extMean" in rec["load"]
    assert rec["run"]["host"] and rec["run"]["logicalCores"] and rec["run"]["maxWorkers"] >= 1


@pytest.mark.parametrize("probe, test, exit_code, outcome", [
    ("", "test_probe_pass", 0, "passed"),
    ("fail", "test_probe_fail", 1, "failed"),
    ("interrupt", "test_probe_interrupt", 2, None),
])
def test_every_run_leaves_one_valid_record(tmp_path, probe, test, exit_code, outcome):
    """Acceptance criterion of WI-0059: green, red and interrupted runs each leave one valid JSON file with commit,
    dirty flag, log path and load figures."""
    code, out, err = innerpytest.run(tmp_path, innerpytest.PROBES + "::" + test, "-q", "-n", "0",
                                     AHF_PROBE=probe)
    assert code == exit_code, out + err
    (rec,) = innerpytest.records(tmp_path)
    _check_record(rec)
    assert rec["complete"] is (exit_code != 2)
    assert rec["run"]["exitStatus"] == exit_code
    assert "History: " in out
    if outcome:
        (item,) = rec["tests"]
        assert item["outcome"] == outcome and "extMean" in item and item["duration"] >= 0
        if outcome == "failed":
            assert "probe failure on request" in item["failure"]
            assert rec["counts"] == {"failed": 1}
            assert "load of the red tests" in out and "test_probe_fail  sys " in out
    else:
        assert rec["counts"].get("passed", 0) == 0


@pytest.mark.slow
def test_external_load_shows_in_the_figures_of_the_test(tmp_path):
    """Acceptance criterion of WI-0059: with synthetic load from outside the run (a helper burns every core during
    one test) the external CPU of that test is clearly higher than for the same kind of test without load, and a test
    that burns the cores itself (own process tree) does not count as external load. The burners run at idle priority,
    so they take only CPU nobody else wants; the test checks the relation, not absolute numbers."""
    signals = tmp_path / "signals"
    signals.mkdir()
    proc = innerpytest.start(tmp_path, innerpytest.PROBES + "::test_probe_load_quiet",
                             innerpytest.PROBES + "::test_probe_load_external",
                             innerpytest.PROBES + "::test_probe_load_own", "-q", "-n", "0",
                             AHF_PROBE="load=%s" % signals)
    burners = []
    try:
        deadline = time.time() + 60
        while not (signals / "external.request").exists():
            assert proc.poll() is None and time.time() < deadline, "the probe run ended early"
            time.sleep(0.05)
        burners = runtool_probes.burners(os.cpu_count() or 2)
        time.sleep(0.5)                                   # let them reach full speed before the window starts
        (signals / "external.running").write_text("1", encoding="utf-8")
        while not (signals / "external.done").exists():
            assert proc.poll() is None and time.time() < deadline, "the probe run ended early"
            time.sleep(0.05)
    finally:
        runtool_probes.stop_burners(burners)
    out, err = proc.communicate(timeout=60)
    assert proc.returncode == 0, out.decode("utf-8", "replace") + err.decode("utf-8", "replace")
    (rec,) = innerpytest.records(tmp_path)
    by_name = {t["id"].split("::")[-1]: t for t in rec["tests"]}
    quiet, external, own = (by_name["test_probe_load_" + n] for n in ("quiet", "external", "own"))
    figures = {n: (t["sysMean"], t["extMean"]) for n, t in (("quiet", quiet), ("external", external), ("own", own))}
    print("load figures (sysMean, extMean):", figures)
    assert external["extMean"] > quiet["extMean"] + 10, figures
    assert external["extMean"] > own["extMean"] + 10, figures
    assert own["sysMean"] > own["extMean"] + 10, figures         # the burners of the own tree count as own
