"""Admission, load figures and history record of one pytest run (WI-0059). tests/conftest.py calls these functions
from its hooks, in the controller only (never in an xdist worker).

Modes of a run (field run.admission of the history record):
  direct     registered and admitted by this controller (tests/support/admission.py)
  run_suite  admitted by tools/run_suite.py (AHF_ADMITTED=<its run id>); registers no second time
  recheck    admitted by tools/recheck.py the same way
  off        AHF_NO_ADMISSION=1: no admission, not registered (debugging, --pdb, -s)
  external   AHF_ADMITTED names a run that is not in the registry: no admission, not registered
A pytest started by a test of a running pytest (the run log variable is inherited) is part of that test: it has no
admission and writes no history record.

Environment: AHF_MAX_WORKERS, AHF_ADMISSION_TIMEOUT, AHF_NO_ADMISSION, AHF_ADMITTED (see admission.py),
AHF_HISTORY_DIR (history.py), AHF_LOAD_SAMPLER=0 (no load sampling, for measuring its overhead).
"""

import os
import socket
import sys
import tempfile
import threading
import time
from pathlib import Path

from support import admission, history, loadsampler

RUNLOG_ENV = "AHF_TESTRUN_DIR"          # set by the controller of a run (conftest), inherited by everything below it
DIALOG_DIR = Path(tempfile.gettempdir()) / "ahf_dialogs"         # tools/ahf_dialogwatch.py OUT_DIR
EXIT_INTERRUPTED = 2


def _say(text):
    sys.stderr.write("[admission] %s\n" % text)
    sys.stderr.flush()


def _stamp(epoch):
    return time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(epoch))


def _requested_workers(config):
    """Workers the command line asks for: -n auto/logical counts as all cores - 2; 0 means serial."""
    n = getattr(config.option, "numprocesses", None)
    if n in ("auto", "logical"):
        requested = admission.auto_workers()
    else:
        try:
            requested = int(n or 0)
        except (TypeError, ValueError):
            requested = 0
    maxp = getattr(config.option, "maxprocesses", None)
    if requested and maxp:
        requested = min(requested, int(maxp))
    return requested


def _tier(config):
    if config.getoption("--foundation", False):
        return "foundation"
    if config.getoption("--all", False):
        return "all"
    if config.getoption("markexpr", ""):
        return "marker"
    return "fast"


def _first_line(report):
    message = getattr(getattr(report.longrepr, "reprcrash", None), "message", None)
    if not message:
        text = getattr(report, "longreprtext", "") or ""
        lines = [line for line in text.splitlines() if line.strip()]
        marked = [line[1:].strip() for line in lines if line.startswith("E ")]
        message = (marked or lines or [""])[0]
    return message.strip().splitlines()[0][:300] if message.strip() else ""


class RunRecorder:
    def __init__(self, config):
        self.config = config
        self.start = time.time()
        self.mode = None
        self.run_id = None
        self.run_dir = None            # registry folder (direct, run_suite, recheck)
        self.registered = False        # this controller registered the run and finishes it
        self.status = {}               # status.json of run_suite / recheck
        self.waited = 0.0
        self.requested = 0
        self.granted = None
        self.exclusive = False
        self.limit = admission.max_workers()
        self.sampler = None
        self.tests = {}
        self.code = {}
        self.history_path = None
        self.history_error = None
        self.red_lines = []
        self.done = False
        self._code_thread = None
        self._old_admitted = os.environ.get("AHF_ADMITTED")

    # --- start ---------------------------------------------------------------------------------------------------

    def begin(self):
        """Admission. Returns None to go on, or an exit code to end pytest before collection."""
        config = self.config
        base = admission.runs_dir()
        self._start_code_info()
        if getattr(config.option, "usepdb", False) and getattr(config.option, "numprocesses", None) in ("auto",
                                                                                                    "logical"):
            config.option.numprocesses = 0          # what xdist does for --pdb with -n auto
            config.option.dist = "no"
        self.requested = _requested_workers(config)
        self.exclusive = admission.selects_exclusive(config.getoption("markexpr", "") or "")
        admitted = os.environ.get("AHF_ADMITTED")
        if admitted:
            run_dir = admission.find_run(base, admitted)
            self.status = admission.read_status(run_dir) if run_dir else {}
            if not self.status:
                self.mode, self.run_id = "external", self._new_id()
            else:
                self.mode = self.status.get("tool") or "run_suite"
                self.run_id, self.run_dir = admitted, run_dir
                self.waited = float(self.status.get("waited") or 0.0)
                granted = int(self.status.get("workers") or 0)
                if self.requested > granted:          # the admission is authoritative, a later -n cannot raise it
                    self._set_workers(granted)
                    self.requested = granted
                if self.requested < int(self.status.get("workers") or 0):
                    admission.write_status(run_dir, workers=self.requested)      # frees the slots it does not use
                self.granted = self.requested
        elif os.environ.get("AHF_NO_ADMISSION") == "1":
            self.mode, self.run_id = "off", self._new_id()
        else:
            self.mode = "direct"
            self.run_id, self.run_dir = admission.new_direct_dir(base)
            info = {"id": self.run_id, "tool": "pytest", "pytestArgs": list(config.invocation_params.args),
                    "cwd": str(Path.cwd()), "started": time.strftime("%Y-%m-%d %H:%M:%S")}
            try:
                self.granted, self.waited = admission.admit(base, self.run_dir, info, requested=self.requested,
                                                            exclusive=self.exclusive, say=_say,
                                                            timeout=admission.admission_timeout(), limit=self.limit)
            except admission.AdmissionTimeout as e:
                _say(str(e))
                self.waited = time.time() - self.start
                self.finish_record(admission.EXIT_ADMISSION_TIMEOUT, complete=False)
                return admission.EXIT_ADMISSION_TIMEOUT
            except KeyboardInterrupt:
                self.waited = time.time() - self.start
                self.finish_record(EXIT_INTERRUPTED, complete=False)
                return EXIT_INTERRUPTED
            self.registered = True
            if self.requested > 0:
                if self.granted < self.requested:
                    _say("%d of %d worker(s) granted (AHF_MAX_WORKERS %d, other runs hold the rest)"
                         % (self.granted, self.requested, self.limit))
                self._set_workers(self.granted)
            os.environ["AHF_ADMITTED"] = self.run_id      # nested runs and the workers register no second time
        if os.environ.get("AHF_LOAD_SAMPLER", "1") != "0":
            self.sampler = loadsampler.LoadSampler(count_runs=lambda: len(admission.active_runs(base))).start()
        return None

    def _set_workers(self, n):
        self.config.option.numprocesses = n
        if n == 0:
            self.config.option.dist = "no"

    def _new_id(self):
        return "%s-p%d" % (time.strftime("%Y%m%d-%H%M%S", time.localtime(self.start)), os.getpid())

    def _start_code_info(self):
        cwd = self.config.rootpath

        def work():
            sha, branch, top, common = history.git_info(cwd)
            self.code = {"sha": sha, "branch": branch, "worktree": top, "commonDir": common,
                         "dirty": history.git_dirty(cwd) if sha else None}

        self._code_thread = threading.Thread(target=work, name="ahf-code-info", daemon=True)
        self._code_thread.start()

    # --- during the run ------------------------------------------------------------------------------------------

    def logreport(self, report):
        entry = self.tests.get(report.nodeid)
        if entry is None:
            entry = self.tests[report.nodeid] = {"id": report.nodeid, "outcome": None, "duration": 0.0,
                                                 "_start": report.start, "_stop": report.stop}
        entry["_start"] = min(entry["_start"], report.start)
        entry["_stop"] = max(entry["_stop"], report.stop)
        xfail = hasattr(report, "wasxfail")
        if report.when == "setup":
            if report.failed:
                entry["outcome"], entry["duration"] = "error", round(report.duration, 3)
            elif report.skipped:
                entry["outcome"], entry["duration"] = ("xfailed" if xfail else "skipped"), round(report.duration, 3)
        elif report.when == "call":
            if report.passed:
                entry["outcome"] = "xpassed" if xfail else "passed"
            elif report.skipped:
                entry["outcome"] = "xfailed" if xfail else "skipped"
            else:
                entry["outcome"] = "failed"
            entry["duration"] = round(report.duration, 3)
        elif report.failed and entry["outcome"] not in history.RED:       # teardown failed
            entry["outcome"] = "error"
        if report.failed and "failure" not in entry:
            entry["failure"] = _first_line(report)

    # --- end -----------------------------------------------------------------------------------------------------

    def finish_record(self, exitstatus, complete=None):
        """Frees the slots, writes the history record. Never raises."""
        if self.done:
            return
        self.done = True
        end = time.time()
        try:
            if self.sampler is not None:
                self.sampler.stop()
            if self.registered:
                admission.finish(self.run_dir, exitStatus=int(exitstatus))
                self.registered = False
            if self._old_admitted is None:
                os.environ.pop("AHF_ADMITTED", None)
            if self._code_thread is not None:
                self._code_thread.join(timeout=30)
            record = self._build(end, int(exitstatus), complete)
            folder = history.history_dir(cwd=self.config.rootpath, common_dir=self.code.get("commonDir"))
            self.history_path = history.write_record(folder, record)
            if self.mode in ("run_suite", "recheck") and self.run_dir:
                admission.write_status(self.run_dir, historyFile=str(self.history_path))
        except Exception as e:          # no record is better than a broken test run
            self.history_error = "%s: %s" % (type(e).__name__, e)

    def unconfigure(self):
        """Fallback when the session never ended normally (usage error after the admission)."""
        if self.registered:
            admission.finish(self.run_dir, exitStatus=-1)
            self.registered = False
        if self.sampler is not None:
            self.sampler.stop()
        if self._old_admitted is None:
            os.environ.pop("AHF_ADMITTED", None)

    def _build(self, end, exitstatus, complete):
        config = self.config
        samples = self.sampler.samples if self.sampler is not None else []
        tests = []
        counts = {}
        for entry in self.tests.values():
            outcome = entry["outcome"] or "incomplete"
            item = {"id": entry["id"], "outcome": outcome, "duration": entry["duration"]}
            load = loadsampler.window_stats(samples, entry["_start"], entry["_stop"])
            if load:
                item.update(load)
            if outcome in history.RED and entry.get("failure") is not None:
                item["failure"] = entry["failure"]
            counts[outcome] = counts.get(outcome, 0) + 1
            tests.append(item)
            if outcome in history.RED:
                self.red_lines.append(item)
        load = loadsampler.run_stats(samples)
        if load is not None:
            load["samplerCostS"] = round(self.sampler.cost_s, 3)
            load["samplerCpuS"] = round(self.sampler.cpu_s, 3)
            load["ownMethod"] = self.sampler.method          # job (exact) or tree (psutil walk, see loadsampler)
            load["series"] = [[round(s.t - self.start, 1), round(s.sys, 1), round(s.ext, 1), s.runs, s.procs]
                              for s in samples]
            load["seriesFields"] = ["t", "sys", "ext", "runs", "procs"]
        code = dict(self.code)
        code.pop("commonDir", None)
        if self.status.get("ref") and code.get("branch") in (None, "HEAD"):
            code["branch"] = self.status["ref"]               # run_suite runs a detached worktree of this ref
        run_log = os.environ.get(RUNLOG_ENV)
        logs = {"runDir": str(self.run_dir) if self.mode in ("run_suite", "recheck") and self.run_dir else None,
                "output": None, "runLog": run_log, "dialogs": self._dialogs(end)}
        if logs["runDir"] and (Path(logs["runDir"]) / "output.txt").exists():
            logs["output"] = str(Path(logs["runDir"]) / "output.txt")
        workers = getattr(config.option, "numprocesses", None)
        return {
            "schema": history.SCHEMA,
            "complete": (exitstatus not in (EXIT_INTERRUPTED, 3, admission.EXIT_ADMISSION_TIMEOUT)
                         if complete is None else complete),
            "run": {
                "id": self.run_id, "start": _stamp(self.start), "startEpoch": round(self.start, 3),
                "end": _stamp(end), "endEpoch": round(end, 3), "durationS": round(end - self.start, 1),
                "waitedS": round(self.waited, 1), "host": socket.gethostname(), "logicalCores": os.cpu_count(),
                "maxWorkers": self.limit, "workersRequested": self.requested, "workersGranted": self.granted,
                "workers": workers if isinstance(workers, int) else None,
                "admission": self.mode, "startedBy": {"run_suite": "run_suite", "recheck": "recheck"}.get(
                    self.mode, "direct"), "exclusive": self.exclusive, "recheckOf": self.status.get("recheckOf"),
                "args": list(config.invocation_params.args), "markexpr": config.getoption("markexpr", "") or "",
                "tier": _tier(config), "exitStatus": exitstatus,
            },
            "code": code,
            "logs": logs,
            "load": load,
            "counts": counts,
            "tests": tests,
        }

    def _dialogs(self, end):
        """Files the dialog guard wrote while this run was going (other runs at the same time can add theirs)."""
        try:
            files = sorted(e.name for e in os.scandir(DIALOG_DIR)
                           if e.is_file() and self.start - 1 <= e.stat().st_mtime <= end + 1)
        except OSError:
            files = []
        return {"dir": str(DIALOG_DIR), "files": files} if files else None

    def summary_lines(self):
        lines = []
        if self.red_lines:
            lines.append("load of the red tests (percent of the machine, mean/peak; ext = without this run's "
                         "processes):")
            for item in self.red_lines:
                if "sysMean" in item:
                    lines.append("  %-6s %s  sys %.0f/%.0f  ext %.0f/%.0f  runs %d" % (
                        item["outcome"], item["id"], item["sysMean"], item["sysPeak"], item["extMean"],
                        item["extPeak"], item["runsMax"]))
                else:
                    lines.append("  %-6s %s  (no load samples)" % (item["outcome"], item["id"]))
        if self.history_path:
            lines.append("History: %s" % self.history_path)
        elif self.history_error:
            lines.append("History: not written (%s)" % self.history_error)
        return lines


def begin(config):
    """Called from pytest_cmdline_main (tryfirst) of the controller. Returns None or an exit code."""
    if hasattr(config, "workerinput"):
        return None
    opt = config.option
    if getattr(opt, "help", False) or getattr(opt, "version", False) or getattr(opt, "collectonly", False):
        return None
    if os.environ.get(RUNLOG_ENV):
        return None                    # a pytest started by a test of a running pytest (see the module docstring)
    recorder = RunRecorder(config)
    config._ahf_run = recorder
    return recorder.begin()


def recorder_of(config):
    return getattr(config, "_ahf_run", None) if config is not None else None
