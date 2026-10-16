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


@pytest.mark.parametrize("expr, expected", [
    ("stress", True), ("soak", True), ("idle", True),
    ("not stress", False),                       # the defect of the old substring check (WI-0059 follow-up)
    ("slow or stress", True),
    ("not (stress or soak)", False),
    ("not slow", False), ("slow", False), ("not gui", False), ("", False), ("   ", False), (None, False),
    ("slow and not stress", False),
    ("stress and not stress", False),
    ("not stress or soak", True),
    ("stress and soak", True),
    ("(slow or gui) and not soak", False),
    ("idle and not slow", True),
    ("nostress", False),                         # another marker name, not stress
    ("stress(", True),                           # pytest cannot parse it: conservative
])
def test_one_function_decides_whether_an_expression_selects_exclusive_tests(expr, expected):
    assert admission.selects_exclusive(expr) is expected


def test_the_internal_expression_api_of_pytest_still_works():
    """selects_exclusive uses _pytest.mark.expression (internal API of pytest). If a pytest update changes it, this
    test fails instead of the decision silently falling back to the name check."""
    from _pytest.mark.expression import Expression
    compiled = Expression.compile("slow and not (stress or m(a=1))")
    seen = []

    def matcher(name, /, **kwargs):
        seen.append((name, kwargs))
        return name == "slow"

    assert compiled.evaluate(matcher) is True
    assert ("slow", {}) in seen and ("stress", {}) in seen


def test_admit_registers_with_the_granted_workers(tmp_path):
    innerpytest.register_run(tmp_path, "other", workers=4)
    run_dir = tmp_path / "direct" / "me"
    granted, waited = admission.admit(tmp_path, run_dir, {"id": "me"}, requested=6, exclusive=False, say=_silent,
                                      limit=6)
    assert granted == 2 and waited < 5
    status = admission.read_status(run_dir)
    assert status["state"] == "running" and status["workers"] == 2 and status["requested"] == 6
    assert {r["id"] for r in admission.active_runs(tmp_path)} == {"other", "me"}


def test_admit_gives_up_after_the_timeout_and_says_why(tmp_path):
    innerpytest.register_run(tmp_path, "other", workers=6)
    said = []
    with pytest.raises(admission.AdmissionTimeout):
        admission.admit(tmp_path, tmp_path / "direct" / "me", {}, requested=2, exclusive=False, say=said.append,
                        limit=6, timeout=0.3, poll_s=0.05)
    assert said and said[0] == "waiting: 1 run(s) active, 6/6 workers"


def test_finished_and_dead_runs_hold_no_slots(tmp_path):
    innerpytest.register_run(tmp_path, "finished", workers=6, state="finished")
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
        innerpytest.register_run(tmp_path, "victim", workers=6, pid=victim.pid)
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
