"""Machine-wide admission of test runs (WI-0059): every pytest run, whether started directly or through
tools/run_suite.py or tools/recheck.py, registers its xdist workers here, so parallel agent sessions cannot overload
the machine together.

Registry: <AHF_RUNS_DIR> (default %TEMP%\\ahf_runs). A run of run_suite or recheck has its folder <id>\\ with
status.json; a direct pytest run has direct\\<id>\\status.json. An entry counts while its state is "running" and its
process (pid plus create time) is alive, so a killed run frees its slots at the next check. Check-and-register happens
under a short lock file (admission.lock), so two starts cannot both pass the check.

Rules: the sum of the workers of all running runs stays <= AHF_MAX_WORKERS (default: logical cores - 2, at least 1);
a serial run counts as 1. A run gets min(requested, free) workers, at least 1. A run that asks for stress or soak
tests (-m stress / -m soak) waits until no other run is active and blocks the start of others while it runs.
Waiting has no time limit unless AHF_ADMISSION_TIMEOUT (seconds) is set.
"""

import json
import os
import re
import shutil
import tempfile
import time
from pathlib import Path

import psutil

EXCLUSIVE_MARKERS = ("stress", "soak")
LOCK_STALE_S = 30.0          # a lock file older than this was left behind by a crashed process
DIRECT_KEEP = 30             # finished direct-run entries kept in the registry
WAIT_MESSAGE_EVERY_S = 30.0
EXIT_ADMISSION_TIMEOUT = 75  # EX_TEMPFAIL: the run did not start, try again later


class AdmissionError(Exception):
    pass


class AdmissionTimeout(AdmissionError):
    pass


def runs_dir():
    return Path(os.environ.get("AHF_RUNS_DIR") or Path(tempfile.gettempdir()) / "ahf_runs")


def max_workers():
    """AHF_MAX_WORKERS, default logical cores - 2, at least 1."""
    try:
        value = int(os.environ.get("AHF_MAX_WORKERS", ""))
        if value >= 1:
            return value
    except ValueError:
        pass
    return max(1, (os.cpu_count() or 1) - 2)


def auto_workers():
    """What -n auto asks for: all logical cores - 2, at least 1."""
    return max(1, (os.cpu_count() or 1) - 2)


def admission_timeout():
    try:
        value = float(os.environ.get("AHF_ADMISSION_TIMEOUT", ""))
        return value if value > 0 else None
    except ValueError:
        return None


def is_exclusive_markexpr(expr):
    """True when a -m expression names stress or soak (conservative: 'not stress' counts too)."""
    return bool(expr) and any(re.search(r"\b%s\b" % m, expr) for m in EXCLUSIVE_MARKERS)


def is_exclusive(pytest_args):
    """True when the run asks for stress or soak tests with -m (measurements need an idle machine)."""
    args = list(pytest_args)
    for i, arg in enumerate(args):
        expr = None
        if arg == "-m" and i + 1 < len(args):
            expr = args[i + 1]
        elif arg.startswith("-m") and len(arg) > 2:
            expr = arg[2:]
        if is_exclusive_markexpr(expr):
            return True
    return False


# --- registry ------------------------------------------------------------------------------------------------------

def _alive(info):
    try:
        proc = psutil.Process(info["pid"])
        return abs(proc.create_time() - info["pidCreated"]) < 1.0
    except (psutil.Error, KeyError, TypeError):
        return False


def _status_files(base):
    yield from base.glob("*/status.json")
    yield from base.glob("direct/*/status.json")


def active_runs(base, exclude=None):
    found = []
    for status in _status_files(base):
        if exclude is not None and status.parent == exclude:
            continue
        try:
            info = json.loads(status.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if info.get("state") == "running" and _alive(info):
            info["dir"] = str(status.parent)
            found.append(info)
    return found


def find_run(base, run_id):
    """The folder of a registered run, or None."""
    for candidate in (base / run_id, base / "direct" / run_id):
        if (candidate / "status.json").is_file():
            return candidate
    return None


def read_status(run_dir):
    try:
        return json.loads((Path(run_dir) / "status.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def write_json_atomic(path, data):
    """Temp file and rename, so a reader never sees half a file. Windows refuses the rename while another process has
    the target open for a moment; that is retried."""
    path = Path(path)
    tmp = path.with_name("%s.%d.tmp" % (path.name, os.getpid()))
    tmp.write_bytes(json.dumps(data, indent=2, ensure_ascii=False).encode("utf-8"))
    for attempt in range(50):
        try:
            os.replace(tmp, path)
            return
        except PermissionError:
            if attempt == 49:
                tmp.unlink(missing_ok=True)
                raise
            time.sleep(0.02)


def write_status(run_dir, **fields):
    path = Path(run_dir) / "status.json"
    info = read_status(run_dir)
    info.update(fields)
    write_json_atomic(path, info)


def slots_of(info):
    """Workers a registered run holds; a serial run (0 workers) counts as 1."""
    try:
        return max(1, int(info.get("workers") or 0))
    except (TypeError, ValueError):
        return 1


class Admission:
    """Check-and-register under a short lock file, so two starts cannot both pass the check."""

    def __init__(self, base, deadline_s=LOCK_STALE_S + 15):
        self.path = Path(base) / "admission.lock"
        self.deadline_s = deadline_s

    def __enter__(self):
        deadline = time.time() + self.deadline_s
        while True:
            try:
                self.fd = os.open(str(self.path), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                return self
            except FileExistsError:
                try:
                    if time.time() - self.path.stat().st_mtime > LOCK_STALE_S:     # left behind by a crashed tool
                        self.path.unlink()
                        continue
                except OSError:
                    pass
                if time.time() > deadline:
                    raise AdmissionError("admission lock %s is held" % self.path)
                time.sleep(0.05)

    def __exit__(self, *exc):
        os.close(self.fd)
        try:
            self.path.unlink()
        except OSError:
            pass


def decide(others, requested, exclusive, limit, max_runs=None):
    """Pure rule: (granted workers, None) when the run may start, (None, reason) when it has to wait.
    requested 0 means a serial run (granted 0, holds 1 slot)."""
    used = sum(slots_of(o) for o in others)
    if any(o.get("exclusive") for o in others):
        return None, "a measurement run is active (-m stress / -m soak)"
    if exclusive and others:
        return None, "%d run(s) active, a measurement needs an idle machine" % len(others)
    if max_runs is not None and len(others) >= max_runs:
        return None, "%d run(s) active (limit --max-runs %d)" % (len(others), max_runs)
    free = limit - used
    if not exclusive and free < 1:
        return None, "%d run(s) active, %d/%d workers" % (len(others), used, limit)
    if exclusive or requested <= 0:
        return 0, None
    return max(1, min(requested, free)), None


def admit(base, run_dir, info, requested, exclusive, say, max_runs=None, timeout=None, limit=None,
          poll_s=1.0):
    """Waits until the run may start, then registers it as running in run_dir/status.json.
    Returns (granted workers, seconds waited). Raises AdmissionTimeout after `timeout` seconds (None: no limit)."""
    base = Path(base)
    base.mkdir(parents=True, exist_ok=True)
    limit = limit or max_workers()
    started = time.time()
    last_msg = None
    while True:
        try:
            with Admission(base):
                others = active_runs(base, exclude=Path(run_dir))
                granted, blocked = decide(others, requested, exclusive, limit, max_runs)
                if granted is not None:
                    waited = round(time.time() - started, 1)
                    Path(run_dir).mkdir(parents=True, exist_ok=True)
                    write_status(run_dir, **info, state="running", pid=os.getpid(),
                                 pidCreated=psutil.Process().create_time(), workers=granted,
                                 requested=requested, exclusive=exclusive, maxWorkers=limit,
                                 admitted=time.strftime("%Y-%m-%d %H:%M:%S"), waited=waited)
                    if last_msg is not None:
                        say("admitted after %.0f s: %s" % (waited, "%d worker(s)" % granted if granted
                                                           else "serial"))
                    return granted, waited
        except AdmissionError as e:      # a lock that is held too long: it expires, keep waiting
            blocked = str(e)
        now = time.time()
        if last_msg is None or now - last_msg >= WAIT_MESSAGE_EVERY_S:
            say("waiting: " + blocked)
            last_msg = now
        if timeout is not None and now - started >= timeout:
            raise AdmissionTimeout("gave up after %.0f s (AHF_ADMISSION_TIMEOUT): %s" % (now - started, blocked))
        time.sleep(poll_s)


def finish(run_dir, **fields):
    try:
        write_status(run_dir, state="finished", finished=time.strftime("%Y-%m-%d %H:%M:%S"), **fields)
    except OSError:
        pass


def new_direct_dir(base):
    """Folder of a direct pytest run in the registry: direct/<time>-p<pid>. Old finished entries are pruned."""
    direct = Path(base) / "direct"
    direct.mkdir(parents=True, exist_ok=True)
    stem = "%s-p%d" % (time.strftime("%Y%m%d-%H%M%S"), os.getpid())
    n = 1
    while True:
        run_id = stem if n == 1 else "%s-%d" % (stem, n)
        try:
            (direct / run_id).mkdir()
            break
        except FileExistsError:
            n += 1
    _prune_direct(direct)
    return run_id, direct / run_id


def _prune_direct(direct):
    try:
        entries = sorted((p for p in direct.iterdir() if p.is_dir()), key=lambda p: p.name)
    except OSError:
        return
    for old in entries[:-DIRECT_KEEP]:
        info = read_status(old)
        if info.get("state") == "running" and _alive(info):
            continue
        if not info and time.time() - old.stat().st_mtime < 60:
            continue                        # just created by another run, its status is not written yet
        shutil.rmtree(old, ignore_errors=True)
