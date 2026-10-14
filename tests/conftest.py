"""Shared fixtures for the AutoHotFlow v2 test suite (see doc/TEST-STRATEGY.md).

Environment variables:
  AHF_AHK2_EXE   path to the AutoHotkey v2 interpreter (default: C:\\Program Files\\AutoHotkey\\v2\\AutoHotkey64.exe)
  AHF_TEST_KEEP  set to 1 to keep the temporary data directories after a test (failed tests keep theirs anyway,
                 see "Run log" below)
  AHF_TEST_LOGS  folder for the run logs (default: %TEMP%/ahf_testruns); the newest 15 runs are kept

Run log: every run writes %TEMP%/ahf_testruns/<time>-<pid>/ with summary.txt (command, counts, failed tests,
slowest tests), results.txt (one line per test, in start order, with UTC and local start time), failures/<test>.txt
(message, traceback, captured output, times, session) and data/<test>/ (evidence of every failed test: the data
directory with Log/ and Reports/, stderr of the processes, and diagnosis/: snapshot of the supervisor and a crash
report fetched from the still running session at the moment of the failure). The path is printed at the end of
the run. Times: the application logs in UTC (ts yyyyMMddHHmmss), the report folders use local time; results.txt and
failures/ give both.
"""

import itertools
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path

import pytest

from support import ahk as ahk_locator
from support import wirebool
from support.procs import ProcessTracker

TESTS_DIR = Path(__file__).resolve().parent
RUN_COUNTER = itertools.count(1)


@pytest.hookimpl(tryfirst=True)
def pytest_cmdline_main(config):
    """Measurements must never run in parallel with other load (idle CPU, latency, memory): a run that asks
    for stress or soak tests (-m stress / -m soak) is switched to a single process, whatever pytest.ini says."""
    asked = config.getoption("markexpr") or ""
    if ("stress" in asked or "soak" in asked) and getattr(config.option, "numprocesses", 0):
        config.option.numprocesses = 0
        config.option.dist = "no"


# Foundation tier: tests of the base that later work packages are not expected to change (IPC, process
# coordination, diagnosis, the test tooling). Not in the default run, see doc/TEST-STRATEGY.md section 6. The list is
# central on purpose: one place shows what counts as foundation. Paths are relative to tests/.
FOUNDATION_FILES = {
    "integration/test_pipe.py", "integration/test_peer.py", "integration/test_supervisor.py", "integration/test_role.py",
    "fault/test_process_crash.py", "fault/test_process_hang.py", "fault/test_pipe_break.py", "fault/test_timeouts.py",
    "fault/test_shutdown.py", "fault/test_orphans.py", "fault/test_supervisor_stall.py", "fault/test_faultkit.py",
    "fault/test_diagnose.py", "fault/test_report.py", "fault/test_debug_dump.py", "fault/test_debug_role.py",
    "support/test_client_hub.py", "support/test_procs.py", "support/test_framing.py", "support/test_wirebool.py",
    "support/test_dialogwatch.py",
}
# AHK unit files (tests/ahk/<name>.test.ahk) of the same kind, and the checks of the runner itself.
FOUNDATION_AHK = {
    "frame", "message", "dispatcher", "child_launcher", "children_output", "supervisor_tick", "core_args",
    "core_debug", "core_errors", "core_ids", "core_log", "core_snapshot", "json", "diag_log", "diag_report",
    "report_files", "selfcheck", "pipe_listener_security",
}
FOUNDATION_RUNNER_CHECKS = {
    "test_failing_and_erroring_cases_are_reported_red", "test_unhandled_error_ends_run_without_dialog",
    "test_script_without_finish_has_no_summary", "test_hung_script_is_killed_at_timeout",
}


def _is_foundation(item, tests_dir):
    try:
        rel = item.path.relative_to(tests_dir).as_posix()
    except ValueError:
        return False
    if rel in FOUNDATION_FILES:
        return True
    if rel == "test_ahk_runner.py":
        params = getattr(getattr(item, "callspec", None), "params", {})
        ahk_file = params.get("ahk_file")
        if ahk_file is not None:
            return Path(ahk_file).name.removesuffix(".test.ahk") in FOUNDATION_AHK
        return item.originalname in FOUNDATION_RUNNER_CHECKS
    return False


# --- run log (see the module docstring) ----------------------------------------------------------------------

RUNLOG_KEEP = 15
RUNLOG_ENV = "AHF_TESTRUN_DIR"        # set by the controller process, inherited by the xdist workers
_CONFIG = [None]


def _safe_name(nodeid):
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", nodeid)[-150:]


def _runlog_dir():
    path = os.environ.get(RUNLOG_ENV)
    if path:
        Path(path).mkdir(parents=True, exist_ok=True)
        return Path(path)
    return None


def _stamps(epoch):
    """UTC and local time of an epoch value: the application logs in UTC, report folders carry local time."""
    return "%s.%03dZ (local %s)" % (time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(epoch)), int(epoch * 1000) % 1000,
                                   time.strftime("%H:%M:%S", time.localtime(epoch)))


def _collect_diagnosis(session, target):
    """Called while a failed test's processes still run: asks the supervisor of the session for its snapshot (works
    without storage, holds the log ring and the output of the children) and for a crash report (written by storage
    into the test's data directory, which is copied afterwards). Every step has a short deadline; nothing here may
    fail the test run."""
    try:
        from support import pipenames
        from support.ahfclient import AhfClient
        client = AhfClient(pipenames.hub_pipe(session), "testdiag", connect_timeout=1.5)
    except Exception as e:          # no supervisor (the test ended it itself, or the test has no session)
        try:
            target.mkdir(parents=True, exist_ok=True)       # the folder does not exist yet at this point
            (target / "diagnosis-none.txt").write_text("no diagnosis: %s: %s\n" % (type(e).__name__, e),
                                                       encoding="utf-8")
        except OSError:
            pass
        return
    try:
        target.mkdir(parents=True, exist_ok=True)
        storage_up = False
        for name, type_, payload, timeout in (("snapshot_supervisor.json", "cmd.diag.snapshot", {}, 3.0),
                                              ("report_answer.json", "cmd.diag.report", {"reason": "test-failed"}, 8.0)):
            if type_ == "cmd.diag.report" and not storage_up:
                (target / name).write_text("no report: storage is not connected in this session\n", encoding="utf-8")
                continue
            try:
                answer = client.request("supervisor", type_, payload, timeout=timeout)["payload"]
                (target / name).write_text(json.dumps(answer, indent=2, ensure_ascii=False), encoding="utf-8")
                if type_ == "cmd.diag.snapshot":
                    links = answer.get("snapshot", {}).get("hub", {}).get("links", [])
                    storage_up = any(link.get("name") == "storage" for link in links)
            except Exception as e:
                (target / name).write_text("no answer: %s: %s\n" % (type(e).__name__, e), encoding="utf-8")
    finally:
        try:
            client.close()
        except Exception:
            pass


def _prune_runlogs(base):
    runs = sorted((p for p in base.iterdir() if p.is_dir()), key=lambda p: p.name)
    for old in runs[:-RUNLOG_KEEP]:
        shutil.rmtree(old, ignore_errors=True)


def pytest_addoption(parser):
    parser.addoption("--all", action="store_true", default=False,
                     help="also run the slow, foundation and gui tests (stress and soak still need -m stress / -m soak)")
    parser.addoption("--foundation", action="store_true", default=False,
                     help="run only the foundation tests, including the slow ones (no gui, stress, soak)")


DEFAULT_DIR_GUARD_ENV = "AHF_DATA_DIR"    # read by the supervisor when --data is missing (Supervisor.DataDir)


def _install_default_dir_guard(config):
    """A process of a test that starts without --data would work in %APPDATA%\\AutoHotFlow, the real directory of
    the project owner. The controller points the fallback to an empty guard directory, which workers and child
    processes inherit; default_dir_guard (below) fails the test that puts anything into it."""
    guard = tempfile.mkdtemp(prefix="ahf-default-data-guard-")
    os.environ[DEFAULT_DIR_GUARD_ENV] = guard
    config._ahf_guard_dir = guard


def pytest_configure(config):
    if not hasattr(config, "workerinput"):                                         # the controller (or a plain run)
        _install_default_dir_guard(config)
    if not hasattr(config, "workerinput") and not os.environ.get(RUNLOG_ENV):     # the controller (or a plain run)
        base = Path(os.environ.get("AHF_TEST_LOGS") or Path(tempfile.gettempdir()) / "ahf_testruns")
        try:
            base.mkdir(parents=True, exist_ok=True)
            _prune_runlogs(base)
            os.environ[RUNLOG_ENV] = str(base / ("%s-%d" % (time.strftime("%Y%m%d-%H%M%S"), os.getpid())))
            config._ahf_runlog_started = time.time()
            config._ahf_results = []
        except OSError:
            pass          # no log is better than no test run
    config.addinivalue_line("markers", "stress: long-running stress test, run with -m stress")
    config.addinivalue_line("markers", "soak: endurance test (minutes), run with -m soak")
    config.addinivalue_line("markers", "fault: fault injection test (kill, freeze, timeout)")
    config.addinivalue_line("markers", "slow: takes about 3 s or more (waits for deadlines); not in the default run, "
                                       "run with -m slow or --all")
    config.addinivalue_line("markers", "foundation: tests of the IPC and process base (set in conftest, "
                                       "FOUNDATION_FILES); not in the default run, run with --foundation or --all")
    config.addinivalue_line("markers", "gui: shows a window or a dialog on the desktop; not in the default run, "
                                       "run with -m gui or --all")


def pytest_collection_modifyitems(config, items):
    # Tiers (doc/TEST-STRATEGY.md section 6). The default run keeps only the fast tests without windows. A group is
    # switched on by naming its marker in -m (stress and soak: full-size tests only, their smoke variants are slow);
    # --all switches on slow, foundation and gui. A test in several tiers runs only when all of them are on.
    asked = config.getoption("markexpr") or ""
    run_all = config.getoption("--all")
    only_foundation = config.getoption("--foundation")
    for item in items:
        if _is_foundation(item, TESTS_DIR):
            item.add_marker(pytest.mark.foundation)
    if only_foundation:
        run_all = True
        asked += " foundation"
        kept = [i for i in items if i.get_closest_marker("foundation") is not None
                and i.get_closest_marker("gui") is None]
        config.hook.pytest_deselected(items=[i for i in items if i not in kept])
        items[:] = kept
    for item in items:
        # smoke variants in tests/stress are not marked themselves: they count as slow
        if "stress" in item.path.parts and not any(item.get_closest_marker(m) for m in ("stress", "soak")):
            item.add_marker(pytest.mark.slow)
    for marker in ("stress", "soak", "slow", "foundation", "gui"):
        if marker == "gui" and only_foundation:
            continue          # already removed above
        if marker not in asked and not (run_all and marker in ("slow", "foundation", "gui")):
            # a full-size stress or soak test that was asked for is not dropped because it is also foundation or slow
            exempt = marker in ("slow", "foundation", "gui")
            kept = [i for i in items if i.get_closest_marker(marker) is None
                    or (exempt and any(i.get_closest_marker(m) for m in ("stress", "soak")))]
            if len(kept) != len(items):
                config.hook.pytest_deselected(items=[i for i in items if i not in kept])
                items[:] = kept
    # Hard limit per test, so nothing hangs unnoticed (pytest-timeout).
    for item in items:
        if item.get_closest_marker("timeout") is None:
            item.add_marker(pytest.mark.timeout(120))


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    report = outcome.get_result()
    setattr(item, "rep_" + report.when, report)
    # Fixture teardown comes after this hook: a failed test's supervisor still runs, so it can be asked now.
    if report.when == "call" and report.failed and os.environ.get(RUNLOG_ENV):
        session = item.funcargs.get("session_id") if hasattr(item, "funcargs") else None
        if session:
            try:
                _collect_diagnosis(session, _runlog_dir() / "data" / _safe_name(item.nodeid) / "diagnosis")
            except Exception:       # an exception in a hook aborts the whole xdist run (INTERNALERROR)
                pass


def pytest_sessionstart(session):
    _CONFIG[0] = session.config


def pytest_runtest_logreport(report):
    """Controller side (the reports of the workers arrive here too): results list and failures/<test>.txt."""
    config = _CONFIG[0]
    results = getattr(config, "_ahf_results", None)
    run_dir = _runlog_dir() if results is not None else None
    if run_dir is None:
        return
    if report.when == "call" or (report.when == "setup" and report.outcome != "passed"):
        results.append((report.nodeid, report.outcome, report.duration, getattr(report, "start", 0.0)))
    if report.failed:
        try:
            fdir = run_dir / "failures"
            fdir.mkdir(exist_ok=True)
            start = getattr(report, "start", 0.0)
            parts = ["%s  [%s]" % (report.nodeid, report.when),
                     "start: %s" % _stamps(start), "end:   %s" % _stamps(getattr(report, "stop", start)),
                     "worker: %s" % getattr(getattr(getattr(report, "node", None), "gateway", None), "id", "-"),
                     "", report.longreprtext]
            for title, content in report.sections:
                parts.append("\n----- %s -----\n%s" % (title, content))
            (fdir / (_safe_name(report.nodeid) + "." + report.when + ".txt")).write_text(
                "\n".join(parts), encoding="utf-8", errors="replace")
        except OSError:
            pass


def pytest_sessionfinish(session, exitstatus):
    config = session.config
    guard = getattr(config, "_ahf_guard_dir", None)
    if guard:
        shutil.rmtree(guard, ignore_errors=True)
    results = getattr(config, "_ahf_results", None)
    run_dir = _runlog_dir() if results is not None else None
    if run_dir is None or not results:
        return
    try:
        counts = {}
        for _, outcome, _, _ in results:
            counts[outcome] = counts.get(outcome, 0) + 1
        lines = ["command: pytest " + " ".join(config.invocation_params.args),
                 "started: " + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(config._ahf_runlog_started)),
                 "duration: %.1f s" % (time.time() - config._ahf_runlog_started),
                 "counts: " + ", ".join("%s %d" % kv for kv in sorted(counts.items())), "",
                 "failed:"]
        lines += ["  %s  %s" % (_stamps(st), n) for n, o, _, st in sorted(results, key=lambda r: r[3])
                  if o == "failed"] or ["  (none)"]
        lines += ["", "slowest 20 (call durations):"]
        lines += ["  %6.1f s  %s" % (d, n) for n, _, d, _ in sorted(results, key=lambda r: -r[2])[:20]]
        (run_dir / "summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
        (run_dir / "results.txt").write_text(
            "".join("%s  %-8s %7.2f s  %s\n" % (time.strftime("%H:%M:%S", time.gmtime(st)) + "Z/"
                                                  + time.strftime("%H:%M:%S", time.localtime(st)), o, d, n)
                    for n, o, d, st in sorted(results, key=lambda r: r[3])), encoding="utf-8")
    except OSError:
        pass


def pytest_terminal_summary(terminalreporter):
    run_dir = os.environ.get(RUNLOG_ENV)
    if run_dir and getattr(terminalreporter.config, "_ahf_results", None):
        terminalreporter.write_line("Run log: " + run_dir)


@pytest.fixture(autouse=True)
def default_dir_guard():
    """Fails a test after which the default data directory (the guard directory, see above) is not empty: some
    process was started without --data. The leftovers are removed, so only the tests running at that moment notice."""
    guard = os.environ.get(DEFAULT_DIR_GUARD_ENV)
    yield
    if not guard or not Path(guard).is_dir():
        return
    leftovers = sorted(p.name for p in Path(guard).iterdir())
    if leftovers:
        for p in Path(guard).iterdir():
            shutil.rmtree(p, ignore_errors=True) if p.is_dir() else p.unlink(missing_ok=True)
        pytest.fail("a process worked in the default data directory (guard %s): %s. Start every process of a test "
                    "with --data=<datadir>." % (guard, ", ".join(leftovers[:10])), pytrace=False)


@pytest.fixture(autouse=True)
def strict_wire_booleans():
    """A frame that a Python test peer decoded and that carries 1/0 in a boolean protocol field fails the test (WI-26)."""
    wirebool.take_violations()
    yield
    bad = wirebool.take_violations()
    assert not bad, "boolean protocol fields not sent as JSON true/false: " + "; ".join(bad[:10])


@pytest.fixture(scope="session")
def ahk_exe():
    """Path to the AutoHotkey v2 interpreter. Skips the test if it is not installed."""
    path, reason = ahk_locator.find_ahk_exe()
    if path is None:
        pytest.skip(reason)
    return path


@pytest.fixture
def datadir(request):
    """A fresh temporary data directory for one test. Kept if AHF_TEST_KEEP=1."""
    path = tempfile.mkdtemp(prefix="ahf-test-")
    yield Path(path)
    if os.environ.get("AHF_TEST_KEEP") == "1":
        print("\nAHF_TEST_KEEP: data directory kept at " + path)
        return
    failed = any(getattr(getattr(request.node, "rep_" + w, None), "failed", False) for w in ("setup", "call"))
    run_dir = _runlog_dir() if failed else None
    if run_dir is not None:       # the evidence of a failed test: log files, stderr of the processes
        try:
            shutil.copytree(path, run_dir / "data" / _safe_name(request.node.nodeid), dirs_exist_ok=True,
                            ignore_dangling_symlinks=True)
        except (OSError, shutil.Error):
            pass
    shutil.rmtree(path, ignore_errors=True)


@pytest.fixture
def session_id():
    """A unique session id, used in pipe names so parallel tests do not collide."""
    return "t" + uuid.uuid4().hex[:12]


@pytest.fixture
def procs():
    """Process tracker. Everything started through it is killed with its children at teardown."""
    tracker = ProcessTracker()
    yield tracker
    survivors = tracker.close()
    assert not survivors, "processes left behind by the test: %s" % survivors


@dataclass
class RunResult:
    returncode: "int | None"
    timed_out: bool
    stdout: str
    stderr: str
    out_path: Path
    records: list = field(default_factory=list)

    @property
    def ok(self):
        return not self.timed_out and self.returncode == 0


@pytest.fixture
def run_ahk(ahk_exe, datadir, procs):
    """Runs an AHK script as a process and waits for it.

    Convention: the script receives the result file path as its FIRST argument
    (see tests/ahk/lib/Assert.ahk). The file is returned as `out_path`, and its JSON
    lines are parsed into `records`. A run longer than `timeout` seconds is killed
    together with its children and reported as timed_out.
    """

    def run(script, *args, timeout=60):
        n = next(RUN_COUNTER)
        out_path = datadir / ("out-%d.jsonl" % n)
        stdout_path = datadir / ("run-%d.stdout" % n)
        stderr_path = datadir / ("run-%d.stderr" % n)
        script_path = Path(script).resolve()
        with open(stdout_path, "wb") as out, open(stderr_path, "wb") as err:
            proc = procs.start([ahk_exe, "/ErrorStdOut=UTF-8", str(script_path), str(out_path), *map(str, args)],
                               stdout=out, stderr=err, cwd=str(script_path.parent))
            try:
                returncode = proc.wait(timeout=timeout)
                timed_out = False
            except subprocess.TimeoutExpired:
                procs.kill(proc)
                returncode = None
                timed_out = True
        stdout = stdout_path.read_bytes().decode("utf-8", "replace")
        stderr = stderr_path.read_bytes().decode("utf-8", "replace")
        # load-time errors arrive on stdout/stderr thanks to /ErrorStdOut; dialogs are caught by the watcher
        from ahf_dialogwatch import shared_watcher
        for ev in shared_watcher().events(proc.pid):
            stderr += ev.summary() + "\n"
        return RunResult(returncode, timed_out, stdout, stderr, out_path, read_records(out_path))

    return run


def read_records(path):
    """Parses a JSON-lines result file. A missing file gives an empty list."""
    if not Path(path).exists():
        return []
    records = []
    text = Path(path).read_text(encoding="utf-8-sig")
    for line in text.splitlines():
        if line.strip():
            records.append(json.loads(line))
    return records
