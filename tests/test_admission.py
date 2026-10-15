"""Machine-wide admission of test runs (WI-0059 part A, tests/support/admission.py). Every test uses its own registry
(AHF_RUNS_DIR in tmp_path), never the real one."""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

import psutil
import pytest

from support import admission, innerpytest

REPO = Path(__file__).resolve().parents[1]


def _register(base, name, workers, pid=None, exclusive=False, state="running"):
    run_dir = base / name
    run_dir.mkdir(parents=True)
    pid = pid or os.getpid()
    admission.write_status(run_dir, id=name, state=state, pid=pid, pidCreated=psutil.Process(pid).create_time(),
                           workers=workers, exclusive=exclusive)
    return run_dir


def _silent(_text):
    pass


@pytest.mark.parametrize("others, requested, exclusive, expected", [
    ([], 6, False, 6),
    ([{"workers": 4}], 6, False, 2),                  # min(requested, free)
    ([{"workers": 6}], 6, False, None),               # no free slot: wait
    ([{"workers": 0}], 6, False, 5),                  # a serial run holds one slot
    ([{"workers": 5}], 0, False, 0),                  # a serial run needs one free slot
    ([{"workers": 6}], 0, False, None),
    ([], 0, True, 0),                                 # measurement on an idle machine
    ([{"workers": 1}], 0, True, None),                # measurement waits for an idle machine
    ([{"workers": 0, "exclusive": True}], 1, False, None),    # a running measurement blocks every other run
])
def test_slots_are_workers(others, requested, exclusive, expected):
    granted, reason = admission.decide(others, requested, exclusive, limit=6)
    assert granted == expected, reason
    assert (reason is None) == (expected is not None)


def test_the_wait_message_names_runs_and_workers():
    _, reason = admission.decide([{"workers": 4}, {"workers": 2}], 2, False, limit=6)
    assert reason == "2 run(s) active, 6/6 workers"


def test_max_runs_of_run_suite_still_applies():
    assert admission.decide([{"workers": 1}, {"workers": 1}], 1, False, limit=6, max_runs=2)[0] is None


def test_max_workers_default_and_override(monkeypatch):
    monkeypatch.delenv("AHF_MAX_WORKERS", raising=False)
    assert admission.max_workers() == max(1, (os.cpu_count() or 1) - 2)
    monkeypatch.setenv("AHF_MAX_WORKERS", "3")
    assert admission.max_workers() == 3
    monkeypatch.setenv("AHF_MAX_WORKERS", "0")          # invalid: the default
    assert admission.max_workers() == max(1, (os.cpu_count() or 1) - 2)


@pytest.mark.parametrize("expr, expected", [("stress", True), ("soak", True), ("not stress", True),
                                            ("slow", False), ("not gui", False), ("", False), (None, False)])
def test_exclusive_marker_expressions(expr, expected):
    assert admission.is_exclusive_markexpr(expr) is expected


def test_admit_registers_with_the_granted_workers(tmp_path):
    _register(tmp_path, "other", workers=4)
    run_dir = tmp_path / "direct" / "me"
    granted, waited = admission.admit(tmp_path, run_dir, {"id": "me"}, requested=6, exclusive=False, say=_silent,
                                      limit=6)
    assert granted == 2 and waited < 5
    status = admission.read_status(run_dir)
    assert status["state"] == "running" and status["workers"] == 2 and status["requested"] == 6
    assert {r["id"] for r in admission.active_runs(tmp_path)} == {"other", "me"}


def test_admit_gives_up_after_the_timeout_and_says_why(tmp_path):
    _register(tmp_path, "other", workers=6)
    said = []
    with pytest.raises(admission.AdmissionTimeout):
        admission.admit(tmp_path, tmp_path / "direct" / "me", {}, requested=2, exclusive=False, say=said.append,
                        limit=6, timeout=0.3, poll_s=0.05)
    assert said and said[0] == "waiting: 1 run(s) active, 6/6 workers"


def test_finished_and_dead_runs_hold_no_slots(tmp_path):
    _register(tmp_path, "finished", workers=6, state="finished")
    dead = subprocess.Popen([sys.executable, "-c", "pass"])
    dead.wait()
    run_dir = tmp_path / "dead"
    run_dir.mkdir()
    admission.write_status(run_dir, state="running", pid=dead.pid, pidCreated=time.time() - 5, workers=6)
    assert admission.active_runs(tmp_path) == []


def test_a_killed_run_frees_its_slots_at_the_next_check(tmp_path):
    """Acceptance criterion of WI-0059: a run that is killed (no clean end, its status stays 'running') no longer
    counts once its process is gone."""
    victim = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
    try:
        _register(tmp_path, "victim", workers=6, pid=victim.pid)
        assert admission.decide(admission.active_runs(tmp_path), 2, False, limit=6)[0] is None
    finally:
        victim.kill()
        victim.wait()
    granted, _ = admission.admit(tmp_path, tmp_path / "direct" / "me", {}, requested=2, exclusive=False,
                                 say=_silent, limit=6, timeout=5)
    assert granted == 2


def test_a_stale_lock_file_expires(tmp_path):
    lock = tmp_path / "admission.lock"
    lock.write_bytes(b"")
    old = time.time() - admission.LOCK_STALE_S - 5
    os.utime(lock, (old, old))
    with admission.Admission(tmp_path, deadline_s=2):
        pass
    assert not lock.exists()


def test_status_is_written_atomically(tmp_path):
    admission.write_status(tmp_path, a=1)
    admission.write_status(tmp_path, b=2)
    assert json.loads((tmp_path / "status.json").read_text(encoding="utf-8")) == {"a": 1, "b": 2}
    assert [p.name for p in tmp_path.iterdir()] == ["status.json"], "no temp file left behind"


def test_old_direct_entries_are_pruned_but_running_ones_kept(tmp_path):
    direct = tmp_path / "direct"
    for i in range(admission.DIRECT_KEEP + 5):
        d = direct / ("20200101-0000%02d-p1" % i)
        d.mkdir(parents=True)
        admission.write_status(d, state="finished")
    running = direct / "20200101-000000-p1"
    admission.write_status(running, state="running", pid=os.getpid(), pidCreated=psutil.Process().create_time())
    admission.new_direct_dir(tmp_path)
    left = sorted(p.name for p in direct.iterdir())
    assert running.name in left
    assert len(left) == admission.DIRECT_KEEP + 1           # the newest ones (the new one among them), the running one


# --- pytest runs (controller hook in tests/conftest.py) --------------------------------------------------------------

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
    _register(tmp_path / "runs", "other", workers=3)
    code, out, err = innerpytest.run(tmp_path, innerpytest.PROBES + "::test_probe_pass", "-q", AHF_MAX_WORKERS=4)
    assert code == 0, out + err
    (rec,) = innerpytest.records(tmp_path)
    assert rec["run"]["workersRequested"] == max(1, (os.cpu_count() or 1) - 2)
    assert rec["run"]["workersGranted"] == 1 and rec["run"]["workers"] == 1
    if rec["run"]["workersRequested"] > 1:
        assert "1 of %d worker(s) granted" % rec["run"]["workersRequested"] in err


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


@pytest.mark.slow
def test_a_run_through_run_suite_registers_only_once(tmp_path):
    """Acceptance criterion of WI-0059: run_suite registers the run, the pytest inside does not register again."""
    env = innerpytest.env_for(tmp_path)
    proc = subprocess.run([sys.executable, str(REPO / "tools" / "run_suite.py"), "--with-changes", "--workers", "0", "--",
                           innerpytest.PROBES + "::test_probe_pass", "-q", "-p", "no:cacheprovider"],
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
