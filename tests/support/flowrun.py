"""Runs flows headless for tests (WI-49): write the flow, start the session, run, read what happened.

    def test_a_branch(flows):
        fb = FlowBuilder("branch")
        trigger = fb.trigger()
        probe = fb.probe("x")
        fb.chain(trigger, fb.action("Action_TestSetVar", Steps='[{"op":"set","name":"x","value":7}]'), probe)
        run = flows.run(fb)
        assert run.reason == "finished" and run.names[-1].startswith("Probe")
        assert run.probe("x").text == "7"

`flows` (fixture, import it into the test module: `from support.flowrun import flows  # noqa: F401`) is a FlowRunner.
It writes the flows into the data folder `Flows/`, starts one real session (supervisor, storage, engine; the entry point
with the test elements), subscribes to the topics of the flows and the log, and ends the session at teardown. The
fixture fails the test if a process of the session is left behind (the processes of the session carry its id in their
command line). A flow that is added after the session started makes `run` restart the session (the engine loads its
flows at start); variables set in the data folder before the start are loaded by the engine.

What a FlowRun holds (all of it comes from the events of the flow topic and the log topic, no engine command):
  reason       `evt.instance.ended`: finished, exception, flow.stop ...
  steps        one Step per started execution of an element, in start order: element_id, name, state (`finished` or
               `exception`, `running` if it did not end) and message of an exception. A loop shows the element once per
               round. The result of a condition (yes, no) is not an event (`evt.connection.state` does not exist yet):
               the branch shows in the steps.
  path, names  the element IDs and the names of the steps
  log          the log entries of the flow that were written while the instance ran (dicts: ts, level, source, text)
  probe(name)  the variables that a `FlowBuilder.probe` element copied: text, type and location of a variable at that
               place of the flow. Instance and thread variables are not readable after the end of an instance (there
               is no engine request for them before WI-50); the probe element is the way to see them.
Events of several instances of one flow that run at the same time are not told apart (the element event has no
instance ID): use one instance at a time, or read the steps of the flow as a whole.

Global and static variables: `preset_var` (before the start), `read_var`, `wait_var` read and write the pair files
(.ahfvd/.ahfvar, UTF-8 with BOM as v1 writes them; `tests/data/variables/` is the pattern).
"""

import json
import shutil
import subprocess
import sys
import threading
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path

import pytest

from support import pipenames
from support.ahfclient import AhfClient
from support.timing import scaled

ROOT = Path(__file__).resolve().parents[2]
ENTRY = ROOT / "tests" / "integration" / "helpers" / "AutoHotFlowTest.ahk"
AHKRUN = ROOT / "tools" / "ahkrun.py"
START_ROLES = "storage,engine"
START_TIMEOUT_S = 20.0
RUN_TIMEOUT_S = 10.0
FILE_TIMEOUT_S = 8.0
PROBE_PREFIXES = ("global_probe_", "global_probetype_", "global_probeloc_")
BOM = "\ufeff"


def _wait_until(predicate, timeout, step=0.05):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        value = predicate()
        if value:
            return value
        time.sleep(step)
    return None


# --- variable files -----------------------------------------------------------------------------------------------
def _stem(datadir, name, flow_id=None):
    base = Path(datadir) / "Variables"
    return (base / flow_id / name) if flow_id else (base / name)


def write_var(datadir, name, value, flow_id=None):
    """Writes a variable as a pair of files like v1 (UTF-8 with BOM, CRLF). A dict or list becomes an object, anything
    else a text (`str(value)`). `flow_id` makes it a static variable of that flow. Does not touch a running engine."""
    stem = _stem(datadir, name, flow_id)
    stem.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(value, (dict, list)):
        kind, content = "object", json.dumps(value, ensure_ascii=False, indent=2)
    else:
        kind, content = "normal", str(value)
    meta = json.dumps({"name": name, "type": kind}, indent=2)
    for ext, text in ((".ahfvd", meta), (".ahfvar", content)):
        Path(str(stem) + ext).write_bytes((BOM + text.replace("\n", "\r\n")).encode("utf-8"))


def read_var(datadir, name, flow_id=None):
    """(type, content text) of a variable on disk, or None if a file is missing or unreadable. Never raises."""
    stem = _stem(datadir, name, flow_id)
    try:
        texts = []
        for ext in (".ahfvd", ".ahfvar"):
            text = Path(str(stem) + ext).read_bytes().decode("utf-8")
            texts.append(text[1:] if text.startswith(BOM) else text)
        return json.loads(texts[0])["type"], texts[1]
    except (OSError, ValueError, KeyError):
        return None


def var_value(pair):
    """The value of a pair of read_var: the parsed JSON of an object, else the text. None stays None."""
    if pair is None:
        return None
    return json.loads(pair[1]) if pair[0] == "object" else pair[1]


def delete_var(datadir, name, flow_id=None):
    for ext in (".ahfvd", ".ahfvar"):
        Path(str(_stem(datadir, name, flow_id)) + ext).unlink(missing_ok=True)


# --- results --------------------------------------------------------------------------------------------------------
@dataclass
class Step:
    element_id: str
    name: str
    state: str = "running"
    message: str = ""


@dataclass
class Probe:
    text: str
    type: str       # String, Integer, Float, Map, <missing>
    location: str   # instance, thread, global, static, builtin, <missing>


@dataclass
class FlowRun:
    flow_id: str
    instance_id: str
    reason: str = ""
    steps: list = field(default_factory=list)
    log: list = field(default_factory=list)
    _runner: object = None

    @property
    def path(self):
        return [s.element_id for s in self.steps]

    @property
    def names(self):
        return [s.name for s in self.steps]

    def state_of(self, element):
        """The states of every step of the element (a handle, an ID or a name), in order."""
        key = str(element)
        return [s.state for s in self.steps if key in (s.element_id, s.name)]

    def probe(self, name, timeout=FILE_TIMEOUT_S):
        """What the probe element saw for the variable `name`, or None if no probe wrote it within the time."""
        return self._runner.read_probe(name, timeout)

    @property
    def exceptions(self):
        return [s.message for s in self.steps if s.state == "exception"]


class Recorder:
    """Every message of the observer, in arrival order, from a thread."""

    def __init__(self, client):
        self.client = client
        self.items = []
        self._cond = threading.Condition()
        self._stop = False
        self._thread = threading.Thread(target=self._run, name="flowrun-recorder", daemon=True)
        self._thread.start()

    def _run(self):
        while not self._stop:
            try:
                for msg in self.client.events(timeout=0.2):
                    with self._cond:
                        self.items.append(msg)
                        self._cond.notify_all()
            except Exception:
                return

    def mark(self):
        with self._cond:
            return len(self.items)

    def wait(self, pred, timeout, since=0):
        """(index, message) of the first message from `since` on that satisfies pred, or None."""
        deadline = time.monotonic() + timeout
        with self._cond:
            seen = since
            while True:
                while seen < len(self.items):
                    if pred(self.items[seen]):
                        return seen, self.items[seen]
                    seen += 1
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    return None
                self._cond.wait(remaining)

    def slice(self, start, end):
        with self._cond:
            return list(self.items[start:end])

    def stop(self):
        self._stop = True


def session_processes(session):
    import psutil
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


def kill_session(session):
    import psutil
    for pid in session_processes(session):
        try:
            psutil.Process(pid).kill()
        except psutil.Error:
            pass


class FlowRunner:
    """One data folder, flows, and a session (supervisor with storage and engine) that is started on demand."""

    def __init__(self, procs, datadir, session_id):
        self.procs = procs
        self.datadir = Path(datadir)
        self.base_session = session_id
        self.sessions = []              # every session id that was started
        self.flows = {}                 # flow id -> builder or None (added as a file)
        self._names = {}                # flow id -> {element id: name}
        self._loaded = set()            # flow ids that the running session has loaded
        self._sup = None
        self._err = None
        self._obs = None
        self._rec = None
        self._marker = 0

    # --- flows and variables ---------------------------------------------------------------------------------------
    def add(self, builder, flow_id=None):
        """Writes the flow of a FlowBuilder into Flows/. Returns the flow ID."""
        flow_id = builder.write(self.datadir, flow_id)
        self.flows[flow_id] = builder
        self._names[flow_id] = {h.id: h.name for h in builder.handles.values()}
        return flow_id

    def add_file(self, source, flow_id=None):
        """Copies a ready-made flow file (for example one of tests/data/flows) into Flows/. Returns the flow ID."""
        source = Path(source)
        flow_id = flow_id or source.stem
        (self.datadir / "Flows").mkdir(exist_ok=True)
        shutil.copyfile(source, self.datadir / "Flows" / (flow_id + ".json"))
        self.flows[flow_id] = None
        self._names[flow_id] = {}
        return flow_id

    def preset_var(self, name, value, flow_id=None):
        """Global (or, with flow_id, static) variable for the next start of the engine. Not while a session runs."""
        assert self._sup is None, "variables are loaded at the start of the engine: preset them before the first run"
        write_var(self.datadir, name, value, flow_id)

    def read_var(self, name, flow_id=None):
        """(type, content) of a variable on disk, or None. The engine writes a change 200 ms after it (wait_var)."""
        return read_var(self.datadir, name, flow_id)

    def wait_var(self, name, predicate=lambda pair: True, flow_id=None, timeout=FILE_TIMEOUT_S):
        """Waits until the pair of files exists and predicate(pair) is true. Returns the pair or None."""
        def check():
            pair = read_var(self.datadir, name, flow_id)
            return pair if pair is not None and predicate(pair) else None
        return _wait_until(check, scaled(timeout))

    # --- session --------------------------------------------------------------------------------------------------
    def start(self):
        """Starts the session and waits until the engine has loaded every added flow."""
        assert self._sup is None, "session already running"
        session = self.base_session if not self.sessions else "%sr%d" % (self.base_session, len(self.sessions))
        self.sessions.append(session)
        self._err = open(self.datadir / ("flowrun-%d.stderr" % len(self.sessions)), "wb")
        args = [sys.executable, str(AHKRUN), "--timeout", "300", str(ENTRY), "--session=" + session,
                "--data=" + str(self.datadir), "--start=" + START_ROLES]
        self._sup = self.procs.start(args, stdout=self._err, stderr=self._err, cwd=str(ROOT))
        pipe = pipenames.hub_pipe(session)
        deadline = time.monotonic() + scaled(START_TIMEOUT_S)
        while True:
            try:
                self._obs = AhfClient(pipe, "flowrun", connect_timeout=2.0)
                break
            except Exception:
                if time.monotonic() > deadline:
                    raise AssertionError("no connection to the hub of the session:\n" + self.stderr_text())
                time.sleep(0.005)
        for topic in ["log"] + ["flow:" + f for f in self.flows]:
            self.request_ok("supervisor", "cmd.topic.subscribe", {"topic": topic})
        self._rec = Recorder(self._obs)

        def loaded():
            try:
                answer = self._obs.request("engine", "cmd.engine.snapshot", {}, timeout=2)
                have = {f["flowId"] for f in answer["payload"]["flows"]}
            except Exception:
                return False
            return set(self.flows) <= have
        if not _wait_until(loaded, scaled(START_TIMEOUT_S)):
            raise AssertionError("the engine did not load %s:\n%s" % (sorted(self.flows), self.stderr_text()))
        # The variables are loaded after the flows (evt.engine.ready follows them). evt.engine.ready can be missed by
        # an observer that connects late, so the runner counts the variable files that the engine will load.
        want = self._variables_on_disk()

        def vars_loaded():
            try:
                info = self.request_ok("engine", "cmd.diag.snapshot", {})["snapshot"]["info"]
                return info["variables"]["loaded"] >= want
            except Exception:
                return False
        if not _wait_until(vars_loaded, scaled(START_TIMEOUT_S)):
            raise AssertionError("the engine did not load %d variable(s):\n%s" % (want, self.stderr_text()))
        self._loaded = set(self.flows)

    def _variables_on_disk(self):
        """Number of global variables and static variables of the added flows (pairs of files below Variables/)."""
        base = self.datadir / "Variables"
        count = len(list(base.glob("*.ahfvd")))
        for flow_id in self.flows:
            count += len(list((base / flow_id).glob("*.ahfvd")))
        return count

    def stop(self):
        """Ends the session the regular way (cmd.app.exit); kills it if it does not end. Safe to call twice."""
        if self._sup is None:
            return
        try:
            if self._sup.poll() is None:
                try:
                    self._obs.request("supervisor", "cmd.app.exit", {}, timeout=5)
                except Exception:
                    pass
                try:
                    self._sup.wait(timeout=scaled(15))
                except subprocess.TimeoutExpired:
                    self.procs.kill(self._sup)
        finally:
            if self._rec is not None:
                self._rec.stop()
            try:
                self._obs.close()
            except Exception:
                pass
            self._err.close()
            kill_session(self.sessions[-1])
            self._sup = self._obs = self._rec = None
            self._loaded = set()

    def close(self):
        """End of the test: ends the session, then checks that no process of any session is left."""
        self.stop()
        leftovers = {}
        for s in self.sessions:
            if not _wait_until(lambda: not session_processes(s), 5.0):
                leftovers[s] = session_processes(s)
                kill_session(s)
        assert not leftovers, "processes left behind: %s" % leftovers

    def stderr_text(self):
        try:
            self._err.flush()
            return Path(self._err.name).read_bytes().decode("utf-8", "replace")
        except (OSError, ValueError):
            return "(no output)"

    # --- running -----------------------------------------------------------------------------------------------------
    def run(self, flow, timeout=RUN_TIMEOUT_S, trigger=None):
        """Runs one instance of a flow and waits for its end. `flow` is a FlowBuilder (added, and the session started or
        restarted if needed), or the ID of a flow that was added. Returns a FlowRun. Raises AssertionError if the
        instance does not end within `scaled(timeout)` seconds (the message has the output of the session)."""
        flow_id = self.add(flow) if hasattr(flow, "to_dict") else flow
        assert flow_id in self.flows, "unknown flow '%s'" % flow_id
        if self._sup is not None and flow_id not in self._loaded:
            self.stop()
        if self._sup is None:
            self.start()
        self._clear_probes()
        mark = self._rec.mark()
        payload = {"flowId": flow_id}
        if trigger is not None:
            payload["triggerId"] = str(trigger)
        started = self.request_ok("engine", "cmd.flow.start", payload)
        instance_id = started["instanceId"]
        found = self._rec.wait(lambda m: m.get("type") == "evt.instance.ended"
                               and m["payload"].get("instanceId") == instance_id, scaled(timeout), mark)
        if found is None:
            raise AssertionError("instance %s of '%s' did not end within %.1f s:\n%s"
                                 % (instance_id, flow_id, scaled(timeout), self.stderr_text()))
        index, ended = found
        run = FlowRun(flow_id, instance_id, ended["payload"].get("reason", ""), _runner=self)
        run.steps = self._steps(flow_id, self._rec.slice(mark, index + 1))
        run.log = self._log_until(flow_id, mark, index)
        return run

    def _steps(self, flow_id, events):
        names = self._names.get(flow_id, {})
        steps = []
        open_steps = {}     # element id -> steps that have not ended
        for msg in events:
            payload = msg.get("payload", {})
            if msg.get("type") != "evt.element.state" or payload.get("flowId") != flow_id:
                continue
            eid, state = payload["elementId"], payload["state"]
            if state == "running":
                step = Step(eid, names.get(eid, eid))
                steps.append(step)
                open_steps.setdefault(eid, []).append(step)
            elif state in ("finished", "exception") and open_steps.get(eid):
                step = open_steps[eid].pop(0)
                step.state = state
                step.message = payload.get("message", "")
        return steps

    def _log_until(self, flow_id, mark, ended_index):
        """The log entries of the flow up to the end. The entries travel engine, storage, hub and may arrive after
        evt.instance.ended, so the runner sends a marker line of its own through the same path and waits for it."""
        self._marker += 1
        text = "flowrun marker %s %d" % (uuid.uuid4().hex[:8], self._marker)
        self._obs.send("storage", "evt.log.append", {"ts": time.strftime("%Y%m%d%H%M%S", time.gmtime()),
                                                    "level": "f2", "source": "flowrun", "text": text})
        got = self._rec.wait(lambda m: m.get("type") == "evt.log.entry" and m["payload"].get("text") == text,
                             scaled(5.0), mark)
        end = got[0] if got else self._rec.mark()
        out = []
        for msg in self._rec.slice(mark, end):
            p = msg.get("payload", {})
            if msg.get("type") == "evt.log.entry" and p.get("flowId") == flow_id:
                out.append({k: p.get(k) for k in ("ts", "level", "source", "text")})
        return out

    # --- probes ----------------------------------------------------------------------------------------------------
    def _clear_probes(self):
        for path in (self.datadir / "Variables").glob("global_probe*"):
            path.unlink(missing_ok=True)

    def read_probe(self, name, timeout=FILE_TIMEOUT_S):
        got = []
        for prefix in PROBE_PREFIXES:
            pair = self.wait_var(prefix + name, timeout=timeout)
            if pair is None:
                return None
            got.append(pair[1])
        return Probe(*got)

    # --- helpers ---------------------------------------------------------------------------------------------------
    def request_ok(self, to, type_, payload):
        """Sends a request on the observer connection (needs a started session), returns the payload of an ok answer."""
        answer = self._obs.request(to, type_, payload, timeout=scaled(5.0))
        assert answer["payload"].get("ok"), "%s failed: %s" % (type_, answer["payload"])
        return answer["payload"]


@pytest.fixture
def flows(procs, datadir, session_id):
    """A FlowRunner on the data folder of the test. Ends its session and checks for leftover processes at teardown."""
    runner = FlowRunner(procs, datadir, session_id)
    yield runner
    runner.close()
