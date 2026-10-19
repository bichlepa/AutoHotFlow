"""Tests of the test tooling that start real pytest runs, a job object or CPU burners (WI-0059): admission across
processes, run_suite, history records of real runs, recheck, the job object, the synthetic load. Foundation tier
(tests/conftest.py FOUNDATION_FILES); the pure unit tests of the same modules are in tests/test_admission.py,
tests/test_load_history.py, tests/test_history_tools.py and tests/test_run_suite.py (fast tier).

Every pytest started here uses its own registry, history and run log folder (tests/support/innerpytest.py)."""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

from support import admission, history, innerpytest, runtool_probes

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools"))

import recheck  # noqa: E402
import run_suite  # noqa: E402


def _git_head():
    return subprocess.run(["git", "rev-parse", "HEAD"], cwd=str(REPO), capture_output=True, check=True,
                          ).stdout.decode().strip()


# --- admission across processes ----------------------------------------------------------------------------------

@pytest.mark.slow
def test_two_direct_runs_never_use_more_workers_than_the_limit(tmp_path):
    """Acceptance criterion of WI-0059: two `python -m pytest` started at the same time (without run_suite) never
    use more workers than AHF_MAX_WORKERS together; the second logs 'waiting' and starts afterwards."""
    args = (innerpytest.PROBES + "::test_probe_pass", "-q", "-n", "2")
    procs = [innerpytest.start(tmp_path, *args, AHF_MAX_WORKERS=2, AHF_PROBE="sleep=3") for _ in range(2)]
    outs = []
    for p in procs:
        out, err = p.communicate(timeout=120)
        outs.append((p.returncode, out.decode("utf-8", "replace"), err.decode("utf-8", "replace")))
    assert all(code == 0 for code, _, _ in outs), outs
    waiting = [err for _, _, err in outs if "[admission] waiting: 1 run(s) active, 2/2 workers" in err]
    assert len(waiting) == 1, outs
    recs = innerpytest.records(tmp_path)
    assert len(recs) == 2
    first, second = recs if recs[0]["run"]["waitedS"] < recs[1]["run"]["waitedS"] else recs[::-1]
    assert first["run"]["workersGranted"] == 2 and second["run"]["workersGranted"] == 2
    assert second["run"]["waitedS"] >= 2.0
    # the second was admitted only after the first had ended
    assert second["run"]["startEpoch"] + second["run"]["waitedS"] >= first["run"]["endEpoch"] - 0.5


@pytest.mark.slow
def test_a_run_gets_the_free_slots_only(tmp_path):
    """-n auto asks for cores - 2; with 3 of 4 slots taken by another (live) run the run gets 1 worker."""
    (tmp_path / "runs").mkdir()
    innerpytest.register_run(tmp_path / "runs", "other", workers=3)
    code, out, err = innerpytest.run(tmp_path, innerpytest.PROBES + "::test_probe_pass", "-q", AHF_MAX_WORKERS=4)
    assert code == 0, out + err
    (rec,) = innerpytest.records(tmp_path)
    assert rec["run"]["workersRequested"] == max(1, (os.cpu_count() or 1) - 2)
    assert rec["run"]["workersGranted"] == 1 and rec["run"]["workers"] == 1
    if rec["run"]["workersRequested"] > 1:
        assert "1 of %d worker(s) granted" % rec["run"]["workersRequested"] in err


def test_not_stress_runs_in_parallel(tmp_path):
    """-m "not stress" is not exclusive (WI-0059 follow-up): the run keeps its workers."""
    code, out, err = innerpytest.run(tmp_path, innerpytest.PROBES + "::test_probe_pass", "-q", "-n", "2", "-m",
                                     "not stress", AHF_MAX_WORKERS=2)
    assert code == 0, out + err
    (rec,) = innerpytest.records(tmp_path)
    assert rec["run"]["exclusive"] is False and rec["run"]["workers"] == 2


def test_no_admission_switch_skips_the_registry(tmp_path):
    code, out, err = innerpytest.run(tmp_path, innerpytest.PROBES + "::test_probe_pass", "-q", "-n", "0",
                                     AHF_NO_ADMISSION=1)
    assert code == 0, out + err
    assert not (tmp_path / "runs" / "direct").exists() or not any((tmp_path / "runs" / "direct").iterdir())
    (rec,) = innerpytest.records(tmp_path)
    assert rec["run"]["admission"] == "off"


def test_a_direct_run_is_registered_and_finished(tmp_path):
    code, out, err = innerpytest.run(tmp_path, innerpytest.PROBES + "::test_probe_pass", "-q", "-n", "0")
    assert code == 0, out + err
    (entry,) = list((tmp_path / "runs" / "direct").iterdir())
    status = admission.read_status(entry)
    assert status["state"] == "finished" and status["exitStatus"] == 0 and status["workers"] == 0


# --- run_suite -----------------------------------------------------------------------------------------------------

@pytest.mark.slow
def test_a_run_through_run_suite_registers_only_once(tmp_path):
    """Acceptance criterion of WI-0059: run_suite registers the run, the pytest inside does not register again."""
    env = innerpytest.env_for(tmp_path)
    proc = subprocess.run([sys.executable, str(REPO / "tools" / "run_suite.py"), "--with-changes", "--workers", "0",
                           "--", innerpytest.PROBES + "::test_probe_pass", "-q", "-p", "no:cacheprovider"],
                          cwd=str(REPO), env=env, capture_output=True, timeout=180)
    out = proc.stdout.decode("utf-8", "replace") + proc.stderr.decode("utf-8", "replace")
    assert proc.returncode == 0, out
    runs = tmp_path / "runs"
    registered = [p for p in runs.glob("*/status.json")] + [p for p in runs.glob("direct/*/status.json")]
    assert len(registered) == 1 and registered[0].parent.parent == runs, registered
    assert not (runs / "direct").exists()
    status = json.loads(registered[0].read_text(encoding="utf-8"))
    assert status["tool"] == "run_suite" and status["state"] == "finished"
    (rec,) = innerpytest.records(tmp_path)
    assert rec["run"]["startedBy"] == "run_suite" and rec["run"]["id"] == status["id"]
    assert rec["logs"]["output"].endswith("output.txt") and rec["logs"]["runDir"] == str(registered[0].parent)
    assert status["historyFile"] and "history: " in out


@pytest.mark.slow
def test_run_in_a_worktree_leaves_no_worktree_and_a_result(tmp_path):
    """End to end on HEAD with a tiny test file; the runs folder is private to this test."""
    env = innerpytest.env_for(tmp_path)
    proc = subprocess.run([sys.executable, str(REPO / "tools" / "run_suite.py"), "--workers", "0", "--",
                           "tests/test_no_v1_dependency.py", "-q"],
                          cwd=str(REPO), env=env, capture_output=True, timeout=180)
    out = proc.stdout.decode("utf-8", "replace")
    assert proc.returncode == 0, out + proc.stderr.decode("utf-8", "replace")
    runs = [p for p in (tmp_path / "runs").iterdir() if (p / "status.json").exists()]
    assert len(runs) == 1
    status = json.loads((runs[0] / "status.json").read_text(encoding="utf-8"))
    assert status["state"] == "finished" and status["exitCode"] == 0 and status["worktreeKept"] is False
    assert not (runs[0] / "tree").exists(), "the worktree must be removed"
    assert (runs[0] / "output.txt").read_text(encoding="utf-8", errors="replace").strip(), "no output kept"
    listed = subprocess.run(["git", "worktree", "list", "--porcelain"], cwd=str(REPO), capture_output=True).stdout
    assert str(runs[0]).replace("\\", "/").encode() not in listed.replace(b"\\", b"/"), "worktree still registered"


@pytest.mark.slow
def test_a_stalled_run_is_killed_and_reported(tmp_path):
    """The watchdog of run_suite: a test that hangs (no output, no live.log line) ends the run with exit 76, and
    stall.txt names the test that was running."""
    env = innerpytest.env_for(tmp_path)
    env["AHF_PROBE"] = "hang"
    started = time.time()
    proc = subprocess.run([sys.executable, str(REPO / "tools" / "run_suite.py"), "--with-changes", "--workers", "0",
                           "--stall-timeout", "5", "--", innerpytest.PROBES + "::test_probe_hang", "-q",
                           "-p", "no:cacheprovider"], cwd=str(REPO), env=env, capture_output=True, timeout=120)
    out = proc.stdout.decode("utf-8", "replace") + proc.stderr.decode("utf-8", "replace")
    assert proc.returncode == run_suite.EXIT_STALLED, out
    assert time.time() - started < 90, "the watchdog did not end the run early"
    (stall,) = (tmp_path / "runs").glob("*/stall.txt")
    assert "test_probe_hang" in stall.read_text(encoding="utf-8"), stall.read_text(encoding="utf-8")


@pytest.mark.slow
def test_a_failing_run_returns_the_exit_code_of_pytest(tmp_path):
    env = innerpytest.env_for(tmp_path)
    proc = subprocess.run([sys.executable, str(REPO / "tools" / "run_suite.py"), "--workers", "0", "--",
                           "tests/does_not_exist.py", "-q"], cwd=str(REPO), env=env, capture_output=True, timeout=120)
    assert proc.returncode not in (0, run_suite.EXIT_TOOL_FAILED), proc.stdout.decode("utf-8", "replace")


# --- history records of real runs ----------------------------------------------------------------------------------

def _check_record(rec):
    assert rec["schema"] == history.SCHEMA
    assert len(rec["code"]["sha"]) == 40 and isinstance(rec["code"]["dirty"], bool) and rec["code"]["worktree"]
    assert rec["logs"]["runLog"] and Path(rec["logs"]["runLog"]).is_dir()
    assert rec["load"] is not None and rec["load"]["samples"] >= 1 and "extMean" in rec["load"]
    assert rec["load"]["ownTree"] in ("job", "psutil")
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


# --- job object ----------------------------------------------------------------------------------------------------

JOB_PROBE = r"""
import json, subprocess, sys, time
sys.path.insert(0, sys.argv[1])
from support import loadsampler
s = loadsampler.LoadSampler(interval=0.1).start()
flags = s._own.limit_flags() if s.method == "job" else None
child = subprocess.Popen([sys.executable, "-c", "pass"])
child.wait()
try:
    subprocess.Popen([sys.executable, "-c", "pass"], creationflags=0x01000000).wait()   # CREATE_BREAKAWAY_FROM_JOB
    breakaway = "started"
except OSError as e:
    breakaway = "refused: %s" % e.winerror
deadline = time.time() + 10
while len(s.samples) < 3 and time.time() < deadline:
    time.sleep(0.02)
s.stop()
print(json.dumps({"method": s.method, "flags": flags, "breakaway": breakaway, "samples": len(s.samples),
                  "procs": max(x.procs for x in s.samples)}))
"""


@pytest.mark.skipif(sys.platform != "win32", reason="job objects are Windows only")
def test_the_job_object_only_counts(tmp_path):
    """Owner's conditions for the job object (WI-0059 follow-up): the job has no limit flags (no KILL_ON_JOB_CLOSE,
    no BREAKAWAY_OK); it only counts. Runs in a process of its own, so this worker is not put into a job. Shows what
    happens to a child that asks to break away: Windows refuses to start it (doc/HOW-TO.md)."""
    proc = subprocess.run([sys.executable, "-c", JOB_PROBE, str(REPO / "tests")], capture_output=True, timeout=60)
    assert proc.returncode == 0, proc.stderr.decode("utf-8", "replace")
    result = json.loads(proc.stdout.decode().strip().splitlines()[-1])
    assert result["method"] == "job" and result["flags"] == 0, result
    assert result["breakaway"].startswith("refused"), result
    assert result["samples"] >= 3


def test_the_sampler_measures_and_stops():
    """Puts this worker into a job object (that is why it is here, not in the fast tier)."""
    from support import loadsampler
    sampler = loadsampler.LoadSampler(interval=0.1).start()
    deadline = time.time() + 10                       # a loaded machine delays the thread: wait for the state
    while len(sampler.samples) < 3 and time.time() < deadline:
        time.sleep(0.05)
    sampler.stop()
    assert len(sampler.samples) >= 3
    assert all(0.0 <= s.sys <= 100.0 and 0.0 <= s.ext <= 100.0 for s in sampler.samples)
    assert sampler.method in ("job", "psutil")


# --- recheck -------------------------------------------------------------------------------------------------------

def _recheck(tmp_path, *args, probe="fail"):
    env = innerpytest.env_for(tmp_path, AHF_PROBE=probe)
    proc = subprocess.run([sys.executable, str(REPO / "tools" / "recheck.py"), *args], cwd=str(REPO), env=env,
                          capture_output=True, timeout=240)
    return proc.returncode, proc.stdout.decode("utf-8", "replace") + proc.stderr.decode("utf-8", "replace")


def _red_probes(folder, sha, dirty=False):
    probes = innerpytest.PROBES
    innerpytest.fake_record(folder, "orig", 1, sha, [(probes + "::test_probe_pass", "failed", 0.1, 90.0),
                                                     (probes + "::test_probe_fail", "failed", 0.1, 90.0)], dirty=dirty)


def _check_recheck(folder, code, out, at):
    assert code == recheck.EXIT_RED_AGAIN, out
    assert "green again" in out and "red again" in out
    recs = history.load_records(folder)
    assert [r["run"]["id"] for r in recs][0] == "orig" and len(recs) == 2, out
    new = recs[1]
    assert new["run"]["recheckOf"] == "orig" and new["run"]["startedBy"] == "recheck"
    assert new["run"]["recheckAt"] == at and new["run"]["exclusive"] is True
    assert new["run"]["workers"] == 0                       # serial
    assert {t["id"].split("::")[1]: t["outcome"] for t in new["tests"]} == {"test_probe_pass": "passed",
                                                                         "test_probe_fail": "failed"}
    return new


@pytest.mark.slow
def test_recheck_runs_the_red_tests_at_the_commit_of_the_run(tmp_path):
    """The recheck is a run of its own: serial, exclusive, at the commit of the run in a worktree of it (the probe
    file must be in that commit, so HEAD is used), with its own record (recheckOf); the first record stays."""
    sha = _git_head()
    _red_probes(tmp_path / "history", sha)
    code, out = _recheck(tmp_path, "orig")
    new = _check_recheck(tmp_path / "history", code, out, sha)
    assert new["code"]["sha"] == sha and new["code"]["dirty"] is False
    assert "runs" in new["code"]["worktree"].replace("\\", "/") and not Path(new["code"]["worktree"]).exists()


@pytest.mark.slow
def test_recheck_here_runs_in_this_checkout_also_for_a_dirty_run(tmp_path):
    _red_probes(tmp_path / "history", "c" * 40, dirty=True)
    code, out = _recheck(tmp_path, "orig")
    assert code == recheck.EXIT_NOT_REPRODUCIBLE and "--here" in out
    code, out = _recheck(tmp_path, "orig", "--here")
    new = _check_recheck(tmp_path / "history", code, out, recheck.WORKING_TREE)
    assert Path(new["code"]["worktree"]).resolve() == REPO.resolve()


# --- synthetic load (needs a quiet machine) ------------------------------------------------------------------------

@pytest.mark.idle
@pytest.mark.slow
def test_external_load_shows_in_the_figures_of_the_test(tmp_path):
    """Acceptance criterion of WI-0059: with synthetic load from outside the run (a helper burns every core during
    one test) the external CPU of that test is clearly higher than for the same kind of test without load, and a test
    that burns the cores itself (own process tree) does not count as external load. Marked idle: it runs only with
    -m idle, and such a run waits for an idle machine and runs alone (admission), so the reference test is quiet. The
    burners run at idle priority; the test checks the relation, not absolute numbers."""
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
