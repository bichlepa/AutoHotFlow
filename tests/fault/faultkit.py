"""Shared helpers of the fault injection tests (WI-15, doc/TESTSTRATEGIE.md 2, level L4).

A Chain is one supervisor (tools/ahkrun.py -> src/AutoHotFlow.ahk) with its real child roles, plus a
Python observer client ("obs") that subscribes to the process topic and records every event with its
arrival time. Roles are found by name through cmd.process.list (the pid is the only way to hit a process).

Every process of a test carries the unique session id in its command line (--session=<id>). That is how
a test finds its own leftovers (session_processes) and never touches a process that is not its own.

Budgets (WI-15 acceptance, PROTOCOL 4.1a, ARCHITEKTUR 6.2) are constants here, so the tests and the
measurement notes use the same numbers.

Repetition: AHF_FAULT_REPEAT=<n> runs every scenario n times (acceptance: 20). The default is 1, so the
full test run stays short. Each round gets its own session id.
"""

import os
import subprocess
import sys
import threading
import time
from pathlib import Path

import psutil

from support.ahfclient import AhfClient

ROOT = Path(__file__).resolve().parents[2]
ENTRY = ROOT / "src" / "AutoHotFlow.ahk"
AHKRUN = ROOT / "tools" / "ahkrun.py"
SKELETON_SRC = ROOT / "tests" / "data" / "skeleton_flow.json"
SKELETON_FLOW = "skeleton"

REPEATS = max(1, int(os.environ.get("AHF_FAULT_REPEAT", "1")))

EXIT_OK = 0
EXIT_START_FAILED = 1
EXIT_FORCED = 5
EXIT_HUB_LOST = 4          # Role.EXIT_HUB_LOST (orphan guard)

START_BUDGET_S = 10.0      # all children ready (generous for a loaded machine; measured values are printed)
CRASH_BUDGET_S = 1.0       # evt.process.crashed within 1 s of the death (ARCHITEKTUR 6.2)
HANG_BUDGET_S = 8.0        # frozen process reported hung within 8 s (WI-15)
CLEAN_EXIT_BUDGET_S = 2.0  # healthy roles: exit within 2 s (WI-15 shutdown)
ORPHAN_BUDGET_S = 3.0 + 2.0  # Role.ORPHAN_MS (3 s) plus slack (WI-15 orphans)
REQUEST_BUDGET_S = 1.0     # an unanswered request ends at its own limit (test value)

# Roles of a full chain: the UI stub is the manager in stub mode, the engine needs storage for its flows.
FULL_CHAIN = "storage,engine,manager"
STUB_OPTS = ["--ui=stub", "--headless"]


def repeat_ids():
    return list(range(REPEATS))


def wait_until(predicate, timeout, step=0.05):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        value = predicate()
        if value:
            return value
        time.sleep(step)
    return None


def alive(pid):
    try:
        p = psutil.Process(pid)
        return p.is_running() and p.status() != psutil.STATUS_ZOMBIE
    except psutil.NoSuchProcess:
        return False


def session_processes(session):
    """Every live process whose command line names this session (our test processes only)."""
    marker = "--session=" + session
    found = []
    for p in psutil.process_iter(["pid", "cmdline"]):
        try:
            cmd = p.info.get("cmdline") or []
        except psutil.Error:
            continue
        if any(marker in part for part in cmd):
            found.append(p.info["pid"])
    return found


def kill_ours(pid, session):
    """Kills one process, but only if its command line names our session. Returns True if it was ours."""
    try:
        p = psutil.Process(pid)
        cmd = p.cmdline()
    except psutil.Error:
        return False
    if not any(("--session=" + session) in part for part in cmd):
        return False
    try:
        p.kill()
    except psutil.Error:
        pass
    return True


def freeze(pid):
    psutil.Process(pid).suspend()


def thaw(pid):
    try:
        psutil.Process(pid).resume()
    except psutil.Error:
        pass


def death_watch(pid, store, codes=None):
    """Records the perf_counter time when pid ends (and its exit code in codes, if given). Runs in a thread,
    so the test keeps reading events. The exit code is only available while the watcher holds the process."""
    def run():
        code = None
        try:
            code = psutil.Process(pid).wait(timeout=90)
        except (psutil.Error, psutil.TimeoutExpired):
            pass
        if codes is not None:
            codes[pid] = code
        store[pid] = time.perf_counter()
    t = threading.Thread(target=run, name="death-%d" % pid, daemon=True)
    t.start()
    return t


class RoleProc:
    """One role process started by hand (not a child of a supervisor), e.g. an engine with --workers=1.
    Output goes to files. Its pid is found through the supervisor's cmd.process.list only if supervised."""

    def __init__(self, procs, datadir, label, args):
        self.stderr_path = Path(datadir) / ("%s.stderr" % label)
        self._err = open(self.stderr_path, "wb")
        cmd = [sys.executable, str(AHKRUN), "--timeout", "120", str(ENTRY), *args]
        self.proc = procs.start(cmd, stdout=self._err, stderr=self._err, cwd=str(ROOT))

    def text(self):
        self._err.flush()
        return self.stderr_path.read_bytes().decode("utf-8", "replace")

    def close(self):
        self._err.close()


def write_flow(datadir, name, element_class=None):
    """Flows/<name>.json: the skeleton flow, optionally with the sleep element replaced by element_class."""
    import json
    flow = json.loads(SKELETON_SRC.read_text(encoding="utf-8"))
    flow["name"] = name
    if element_class is not None:
        element = flow["allElements"]["element0000000002"]
        element["class"] = element_class
        element["name"] = element_class
        element["pars"] = {}
    path = Path(datadir) / "Flows" / (name + ".json")
    path.parent.mkdir(exist_ok=True)
    path.write_text(json.dumps(flow, ensure_ascii=False, indent=2), encoding="utf-8")


class Sup:
    """One supervisor process (ahkrun -> AutoHotFlow.ahk). Output goes to a file, not to a pipe."""

    def __init__(self, procs, datadir, session, args, label="sup"):
        self.session = session
        self.pipe = "ahf.%s.hub" % session
        self.datadir = Path(datadir)
        self.stderr_path = self.datadir / ("%s.stderr" % label)
        self._err = open(self.stderr_path, "wb")
        cmd = [sys.executable, str(AHKRUN), "--timeout", "120", str(ENTRY),
               "--session=" + session, "--data=" + str(self.datadir), *args]
        self.t0 = time.perf_counter()
        self.proc = procs.start(cmd, stdout=self._err, stderr=self._err, cwd=str(ROOT))

    def ahk_pid(self):
        """The supervisor interpreter: the child of ahkrun (ahkrun itself is self.proc)."""
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            for c in psutil.Process(self.proc.pid).children(recursive=True):
                try:
                    if "autohotkey" in c.name().lower():
                        return c.pid
                except psutil.Error:
                    pass
            time.sleep(0.02)
        raise AssertionError("no AutoHotkey process below ahkrun")

    def wait_exit(self, timeout):
        try:
            return self.proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            return None

    def text(self):
        self._err.flush()
        return self.stderr_path.read_bytes().decode("utf-8", "replace")

    def close(self):
        self._err.close()


def connect(pipe, name, timeout=15.0):
    """Connects to the hub. Retries quickly, so the client is there before the first child is ready."""
    deadline = time.monotonic() + timeout
    while True:
        try:
            return AhfClient(pipe, name, connect_timeout=2.0)
        except Exception:
            if time.monotonic() > deadline:
                raise
            time.sleep(0.005)


class Recorder:
    """Every message the observer receives, with its arrival time (perf_counter), from a thread."""

    def __init__(self, client):
        self.client = client
        self.items = []
        self._cond = threading.Condition()
        self._stop = False
        self._thread = threading.Thread(target=self._run, name="recorder", daemon=True)
        self._thread.start()

    def _run(self):
        while not self._stop:
            try:
                for msg in self.client.events(timeout=0.2):
                    with self._cond:
                        self.items.append((time.perf_counter(), msg))
                        self._cond.notify_all()
            except Exception:
                return

    def stop(self):
        self._stop = True

    def find(self, pred):
        with self._cond:
            return [(t, m) for t, m in self.items if pred(m)]

    def wait(self, pred, timeout):
        """First (time, message) satisfying pred, or None after timeout seconds."""
        deadline = time.monotonic() + timeout
        with self._cond:
            while True:
                for t, m in self.items:
                    if pred(m):
                        return t, m
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    return None
                self._cond.wait(remaining)


def event(type_, **fields):
    """Predicate: a message of this type whose payload has the given values."""
    return lambda m: m.get("type") == type_ and all(m.get("payload", {}).get(k) == v for k, v in fields.items())


def request_ok(client, to, type_, payload=None, timeout=5.0):
    answer = client.request(to, type_, payload or {}, timeout=timeout)
    assert answer["payload"].get("ok"), answer
    return answer["payload"]


class Chain:
    """A supervisor with its children, plus an observer. Use close() (the fixture does) to end everything."""

    def __init__(self, procs, datadir, session, start, extra=(), label="sup"):
        flows = Path(datadir) / "Flows"
        flows.mkdir(exist_ok=True)
        (flows / (SKELETON_FLOW + ".json")).write_bytes(SKELETON_SRC.read_bytes())
        args = ["--start=" + start, *extra]
        self.session = session
        self.procs = procs
        self.sup = Sup(procs, datadir, session, args, label=label)
        self.obs = connect(self.sup.pipe, "obs")
        self.rec = None
        self.frozen = set()
        for topic in ("process", "engine"):
            self.request_ok(self.obs, "supervisor", "cmd.topic.subscribe", {"topic": topic})
        self.rec = Recorder(self.obs)

    # --- queries -----------------------------------------------------------------------------
    def request_ok(self, client, to, type_, payload=None, timeout=5.0):
        return request_ok(client, to, type_, payload, timeout)

    def states(self):
        answer = self.obs.request("supervisor", "cmd.process.list", {}, timeout=5)
        return {p["name"]: p for p in answer["payload"]["processes"]}

    def pid(self, name):
        return self.states()[name]["pid"]

    def wait_ready(self, names, timeout=START_BUDGET_S):
        """Waits until each child is ready (cmd.process.list, PROTOCOL 5a). Returns {name: pid} or raises."""
        def check():
            st = self.states()
            return all(st.get(n, {}).get("state") == "ready" for n in names)
        if not wait_until(check, timeout):
            raise AssertionError("not ready: %s, supervisor said:\n%s" % (names, self.sup.text()))
        return {n: self.states()[n]["pid"] for n in names}

    def wait_restarted_ready(self, name, old_pid, timeout=10.0):
        """Waits until the child has a new pid and is ready again. Returns (new pid, time ready)."""
        def check():
            st = self.states().get(name, {})
            return st.get("state") == "ready" and st.get("pid") not in (0, old_pid)
        if not wait_until(check, timeout):
            raise AssertionError("%s not ready again within %.1f s:\n%s" % (name, timeout, self.sup.text()))
        return self.states()[name]["pid"], time.perf_counter()

    def snapshot_ok(self, timeout=5.0):
        return request_ok(self.obs, "engine", "cmd.engine.snapshot", {}, timeout=timeout)

    # --- control -----------------------------------------------------------------------------
    def freeze(self, pid):
        freeze(pid)
        self.frozen.add(pid)

    def thaw(self, pid):
        thaw(pid)
        self.frozen.discard(pid)

    def request_exit(self, payload=None):
        return self.obs.request("supervisor", "cmd.app.exit", payload or {}, timeout=5)

    def close(self):
        """Ends the chain: thaws frozen processes, asks the supervisor to exit, kills what is left."""
        for pid in list(self.frozen):
            thaw(pid)
        try:
            if self.sup.proc.poll() is None:
                try:
                    self.request_exit()
                except Exception:
                    pass
                if self.sup.wait_exit(timeout=10) is None:
                    self.procs.kill(self.sup.proc)
        finally:
            if self.rec is not None:
                self.rec.stop()
            try:
                self.obs.close()
            except Exception:
                pass
            self.sup.close()
            # whatever is still ours of this session is killed (orphans of a failed test)
            for pid in session_processes(self.session):
                kill_ours(pid, self.session)
            self.leftovers = session_processes(self.session)
