"""WI-28 step c: the crash report (cmd.diag.report, automatic reports, storage's Reports/ folder).
doc/PROTOCOL.md 4.9, doc/ARCHITECTURE.md 6.2.

Real supervisor with its real children (faultkit.Chain). The evidence is the folder Reports/<stamp>_<reason>/ in
the data directory (written by storage) and the answers of the supervisor. Waits are for events or folders; the
time limits are generous because the tests also run in parallel (they are budgets, not expectations).
"""

import json
import time

import psutil
import pytest

from faultkit import STUB_OPTS, event, request_ok, wait_until

from faultfixtures import chains  # noqa: F401  (fixture)

pytestmark = pytest.mark.fault

READY_S = 20.0
REPORT_S = 15.0            # budget for a manual report of a healthy session (measured: well below 1 s)
FROZEN_BUDGET_S = 2.0 + 6.0   # one snapshot deadline (2 s) plus slack for a loaded machine


def report_dirs(datadir, suffix=None):
    root = datadir / "Reports"
    if not root.exists():
        return []
    dirs = sorted(p for p in root.iterdir() if p.is_dir())
    return [p for p in dirs if suffix is None or p.name.endswith(suffix) or ("_" + suffix) in p.name]


def wait_report(datadir, reason, timeout=REPORT_S):
    # the folder appears first, the files follow: wait for the last file that storage writes
    found = wait_until(lambda: [p for p in report_dirs(datadir, reason) if (p / "summary.txt").exists()], timeout)
    assert found, "no report '%s' in %s" % (reason, [p.name for p in report_dirs(datadir)])
    return found[0]


def read_report(folder):
    return json.loads((folder / "report.json").read_text(encoding="utf-8"))


def full_chain(chains, datadir, extra=()):
    chain = chains("storage,engine,manager", [*STUB_OPTS, *extra])
    chain.wait_ready(["storage", "engine", "manager", "worker:1"], timeout=READY_S)
    chain.wait_flows(timeout=READY_S)
    return chain


def manual_report(chain, reason="manual", timeout=REPORT_S):
    answer = chain.obs.request("supervisor", "cmd.diag.report", {"reason": reason}, timeout=timeout)
    return answer["payload"]


# --- a report with all roles ------------------------------------------------------------------------

def test_a_report_has_one_entry_per_role_and_a_readable_summary(chains, datadir):
    chain = full_chain(chains, datadir)
    t0 = time.perf_counter()
    payload = manual_report(chain, "manual")
    took = time.perf_counter() - t0
    print("\nMEASURE manual report with storage, engine, manager, worker:1: %.0f ms" % (took * 1000))
    assert payload["ok"], payload
    assert payload["missing"] == [] and payload["roles"] == 5, payload       # four children and the supervisor
    folder = datadir / payload["path"]
    assert folder.is_dir() and folder.name.endswith("_manual") and payload["path"].startswith("Reports/")
    report = read_report(folder)
    assert set(report["snapshots"]) == {"storage", "engine", "manager", "worker:1", "supervisor"}
    assert report["meta"]["reason"] == "manual" and report["meta"]["auto"] is False
    for name, snap in report["snapshots"].items():
        assert snap["name"] == name and snap["schema"] == 1
    summary = (folder / "summary.txt").read_text(encoding="utf-8")
    for needle in ("AutoHotFlow diagnostic report", "reason:   manual", "== Processes", "== Roles ==",
                   "storage  (pid", "engine  (pid", "manager  (pid", "worker:1  (pid", "supervisor  (pid",
                   "worker pool: size 4"):
        assert needle in summary, (needle, summary)
    # the log files are copied next to the report
    assert (folder / "Log.txt").exists()


def test_the_report_names_follow_the_reason_and_two_in_one_second_do_not_collide(chains, datadir):
    chain = chains("storage")
    chain.wait_ready(["storage"])
    first = manual_report(chain, "my reason/with:odd chars")
    second = manual_report(chain, "my reason/with:odd chars")
    assert first["ok"] and second["ok"], (first, second)
    assert first["path"] != second["path"]
    assert first["path"].endswith("_my-reason-with-odd-chars"), first["path"]
    assert (datadir / first["path"] / "report.json").exists() and (datadir / second["path"] / "report.json").exists()


def test_a_bad_reason_is_refused(chains, datadir):
    chain = chains("storage")
    chain.wait_ready(["storage"])
    for bad in ({}, {"reason": ""}, {"reason": "x" * 61}, {"reason": {"a": 1}}):
        answer = chain.obs.request("supervisor", "cmd.diag.report", bad, timeout=5)["payload"]
        assert answer["ok"] is False and answer["error"]["code"] == "bad_payload", (bad, answer)


def test_only_the_supervisor_may_write_reports(chains, datadir):
    chain = chains("storage")
    chain.wait_ready(["storage"])
    answer = chain.obs.request("storage", "cmd.storage.report.write",
                               {"stamp": "20260101-000000", "reason": "x", "files": {"a.txt": "a"}}, timeout=5)["payload"]
    assert answer["ok"] is False and answer["error"]["code"] == "denied", answer
    assert not report_dirs(datadir)


# --- a frozen role ----------------------------------------------------------------------------------

def test_a_frozen_role_is_marked_and_the_report_is_ready_within_the_deadline(chains, datadir):
    chain = chains("storage,echo:a", ["--test-roles"])
    chain.wait_ready(["storage", "echo:a"])
    chain.freeze(chain.pid("echo:a"))
    t0 = time.perf_counter()
    payload = manual_report(chain, "frozen")
    took = time.perf_counter() - t0
    print("\nMEASURE manual report with one frozen role: %.2f s (deadline per role 2 s)" % took)
    assert payload["ok"], payload
    assert took < FROZEN_BUDGET_S, took
    assert [m["name"] for m in payload["missing"]] == ["echo:a"], payload["missing"]
    assert "no answer within 2000 ms" in payload["missing"][0]["why"], payload["missing"]
    report = read_report(datadir / payload["path"])
    assert "echo:a" not in report["snapshots"] and "storage" in report["snapshots"]
    assert report["missing"][0]["name"] == "echo:a"
    summary = (datadir / payload["path"] / "summary.txt").read_text(encoding="utf-8")
    assert "== Roles without a snapshot ==" in summary and "echo:a: no answer within 2000 ms" in summary, summary


# --- automatic reports ------------------------------------------------------------------------------

def test_a_crash_writes_a_report_by_itself_and_the_rate_limit_holds_back_the_next(chains, datadir):
    chain = chains("storage,crasher", ["--test-roles"])
    chain.wait_ready(["storage", "crasher"])
    old = chain.pid("crasher")
    request_ok(chain.obs, "crasher", "cmd.test.arm", {})
    assert chain.rec.wait(event("evt.process.crashed", name="crasher"), timeout=10) is not None
    folder = wait_report(datadir, "crashed-crasher")
    report = read_report(folder)
    assert report["meta"]["auto"] is True
    # the dead child is in the supervisor's table with its exit code (7) and it is listed as missing or restarted
    sup = report["snapshots"]["supervisor"]
    crasher = [c for c in sup["children"] if c["name"] == "crasher"][0]
    assert crasher["exitCode"] == 7 or crasher["state"] in ("starting", "ready"), crasher
    # the child restarts; a second crash within the minute is counted and suppressed, no second folder
    new, _ = chain.wait_restarted_ready("crasher", old, timeout=15)
    request_ok(chain.obs, "crasher", "cmd.test.arm", {})
    assert chain.rec.wait(lambda m: m.get("type") == "evt.process.crashed" and m["payload"].get("pid") == new,
                          timeout=10) is not None
    assert wait_until(lambda: request_ok(chain.obs, "supervisor", "cmd.diag.snapshot", {})["snapshot"]
                      ["reports"]["autoSuppressed"] >= 1, 10.0)
    assert len(report_dirs(datadir, "crashed-crasher")) == 1, [p.name for p in report_dirs(datadir)]
    # a manual report is not limited
    assert manual_report(chain, "manual")["ok"]


def test_a_hung_role_writes_a_report_by_itself(chains, datadir):
    chain = chains("storage,echo:a", ["--test-roles"])
    chain.wait_ready(["storage", "echo:a"])
    chain.freeze(chain.pid("echo:a"))
    assert chain.rec.wait(event("evt.process.hung", name="echo:a"), timeout=15) is not None
    folder = wait_report(datadir, "hung-echo-a", timeout=20)
    report = read_report(folder)
    assert any(m["name"] == "echo:a" for m in report["missing"]), report["missing"]


def test_a_burst_of_unhandled_errors_writes_a_report(chains, datadir):
    chain = chains("storage,echo:a", ["--test-roles"])
    chain.wait_ready(["storage", "echo:a"])
    request_ok(chain.obs, "echo:a", "cmd.test.throwlater", {"count": 12})       # more than 10, fewer than 21
    folder = wait_report(datadir, "errors-echo-a")
    report = read_report(folder)
    assert report["snapshots"]["echo:a"]["errors"]["count"] >= 10
    assert len(report["snapshots"]["supervisor"]["diagErrors"]) >= 10
    # the role is still alive: 12 errors are not too many
    assert request_ok(chain.obs, "echo:a", "cmd.test.echo", {"x": 1})["echo"] == {"x": 1}


def test_no_automatic_report_while_the_session_ends(chains, datadir):
    chain = chains("storage,echo:a", ["--test-roles"])
    chain.wait_ready(["storage", "echo:a"])
    chain.request_exit()
    assert chain.sup.wait_exit(timeout=20) == 0, chain.sup.text()
    assert not report_dirs(datadir), [p.name for p in report_dirs(datadir)]


# --- storage away ------------------------------------------------------------------------------------

def test_a_report_waits_for_a_restarted_storage_and_is_written_then(chains, datadir):
    chain = chains("storage,engine", [])
    chain.wait_ready(["storage", "engine"], timeout=READY_S)
    old = chain.pid("storage")
    psutil.Process(old).kill()
    t0 = time.perf_counter()
    payload = manual_report(chain, "while-storage-is-down", timeout=20)
    took = time.perf_counter() - t0
    print("\nMEASURE manual report while storage was killed and restarted: %.2f s" % took)
    assert payload["ok"], payload
    folder = datadir / payload["path"]
    report = read_report(folder)
    missing = {m["name"]: m["why"] for m in report["missing"]}
    # the supervisor may or may not have seen the broken pipe when the question went out: both are a missing answer
    assert "storage" in missing and ("not connected" in missing["storage"] or "connection lost" in missing["storage"]), missing
    assert "engine" in report["snapshots"]
    # the crash of storage wrote its own (automatic) report too, once storage was back
    assert wait_report(datadir, "crashed-storage") is not None


def test_a_report_for_a_storage_that_never_returns_is_answered_in_time_and_kept(chains, datadir):
    chain = chains("storage,engine", ["--test-roles", "--restart-max=0", "--report-wait=1500"])
    chain.wait_ready(["storage", "engine"], timeout=READY_S)
    psutil.Process(chain.pid("storage")).kill()
    assert chain.rec.wait(event("evt.process.crashed", name="storage", restart=False), timeout=10) is not None
    t0 = time.perf_counter()
    payload = manual_report(chain, "storage-gone", timeout=20)
    took = time.perf_counter() - t0
    print("\nMEASURE answer for a report without storage (wait 1.5 s): %.2f s" % took)
    assert payload["ok"] is False and payload["error"]["code"] == "peer_gone", payload
    assert 1.0 < took < 10.0, took
    # nothing is written by the supervisor itself, and the report is kept in memory
    assert not report_dirs(datadir)
    reports = request_ok(chain.obs, "supervisor", "cmd.diag.snapshot", {})["snapshot"]["reports"]
    assert reports["unwritten"] >= 1 and reports["written"] == 0, reports
