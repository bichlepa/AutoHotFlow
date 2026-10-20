"""WI-0073: the real manager (src/manager/) under the real supervisor, headless. Replaces the tests of the manager (WI-0013).

The supervisor starts storage, engine and manager (--headless) as real processes through tools/ahkrun.py. The skeleton flow
(tests/data/skeleton_flow.json, copied to Flows/skeleton.json) runs in the engine. A Python observer subscribes to the same
topics as the manager, so the two sequences of events can be compared.

The manager keeps a record of everything it sees when it runs headless (ManagerModel.Trace); the test reads it with
cmd.test.trace (PROTOCOL 4.8). Entries: the engine events as received (type evt.*, payload with epoch and seq) and the
entries of the manager itself (manager.ready, manager.snapshot, manager.command, manager.commandAnswer,
manager.prepareExit, manager.show, manager.engine).

Timing: recvMs in the entries is the wall clock (ms, UTC) at arrival. manager.command carries the send time of a forwarded
command, so the arrival latency is measured on the same clock. Python requests reach the hub on its 250 ms fallback timer,
so times that start with a Python send are not used.

The window (ManagerWindow) is tested in tests/gui/test_manager_window.py (gui tier).
"""

import json
import re
import subprocess
import sys
import threading
import time
from pathlib import Path

import psutil
import pytest

from support import pipenames
from support.ahfclient import AhfClient
from support.timing import scaled

ROOT = Path(__file__).resolve().parents[2]
ENTRY = ROOT / "src" / "AutoHotFlow.ahk"
AHKRUN = ROOT / "tools" / "ahkrun.py"
SKELETON_SRC = ROOT / "tests" / "data" / "skeleton_flow.json"
FLOW = "skeleton"
READY_TIMEOUT_S = 15.0


class Sup:
    """One supervisor (ahkrun -> AutoHotFlow.ahk). Output goes to a file, not to a pipe."""

    def __init__(self, procs, datadir, session, args):
        self.session = session
        self.pipe = pipenames.hub_pipe(session)
        self.datadir = Path(datadir)
        self._err = open(self.datadir / "sup.stderr", "wb")
        cmd = [sys.executable, str(AHKRUN), "--timeout", "120", str(ENTRY),
               "--session=" + session, "--data=" + str(self.datadir), *args]
        self.proc = procs.start(cmd, stdout=self._err, stderr=self._err, cwd=str(ROOT))

    def wait_exit(self, timeout):
        try:
            return self.proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            return None

    def close_files(self):
        self._err.close()


class Recorder:
    """Collects every event an AhfClient receives, in arrival order, from a background thread."""

    def __init__(self, client):
        self.client = client
        self.msgs = []
        self._lock = threading.Lock()
        self._stop = False
        self._thread = threading.Thread(target=self._run, name="recorder", daemon=True)
        self._thread.start()

    def _run(self):
        while not self._stop:
            for msg in self.client.events(timeout=0.2):
                with self._lock:
                    self.msgs.append(msg)

    def snapshot(self):
        with self._lock:
            return list(self.msgs)

    def close(self):
        self._stop = True
        self._thread.join(timeout=3.0)


def trace(obs, since=0):
    """The record of the headless manager: entries with a number above since."""
    ans = obs.request("manager", "cmd.test.trace", {"since": since}, timeout=5)
    assert ans["payload"]["ok"], ans
    return ans["payload"]["entries"]


def trace_events(obs, s0):
    """(type, seq) of the engine events with seq above s0 that the manager has seen, in arrival order."""
    out = [(e["type"].replace("evt.element.states", "evt.element.state"), e["payload"]["seq"]) for e in trace(obs)
           if e["type"].startswith("evt.") and "seq" in e["payload"] and e["payload"]["seq"] > s0
           and e["type"] != "evt.log.entry"]
    return dedupe_batches(out)


def dedupe_batches(events):
    """WI-0089: an evt.element.states batch is one event with one seq; the observer sees it as one evt.element.state per
    element (same seq). Equal neighbours are one event."""
    return [ev for i, ev in enumerate(events) if i == 0 or ev != events[i - 1]]


def connect_obs(pipe, timeout=20.0):
    """Connects the observer. A supervisor that starts together with many others (parallel test run) needs
    more than the 5 s of one connect attempt (F-0002), so the attempt is repeated."""
    deadline = time.monotonic() + timeout
    while True:
        try:
            return AhfClient(pipe, "obs", connect_timeout=2.0)
        except Exception:      # no pipe yet, or no sys.welcome yet (AhfTimeout)
            if time.monotonic() > deadline:
                raise
            time.sleep(0.01)


def wait_until(predicate, timeout, step=0.05):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        value = predicate()
        if value:
            return value
        time.sleep(step)
    return None


def process_states(obs):
    ans = obs.request("supervisor", "cmd.process.list", {}, timeout=5)
    return {p["name"]: p for p in ans["payload"]["processes"]}


def wait_ready(obs, names, timeout=READY_TIMEOUT_S):
    def check():
        procs = process_states(obs)
        return all(procs.get(n, {}).get("state") == "ready" for n in names)
    assert wait_until(check, timeout), "not all of %s ready" % (names,)


def engine_snapshot(obs):
    return obs.request("engine", "cmd.engine.snapshot", {}, timeout=5)["payload"]


def wait_flow_loaded(obs, timeout=READY_TIMEOUT_S):
    """The engine says hello before it has loaded its flows (sys.hello is not evt.engine.ready)."""
    def loaded():
        return any(f["flowId"] == FLOW for f in engine_snapshot(obs)["flows"])
    assert wait_until(loaded, timeout), "engine never loaded the flow %s" % FLOW


def flow_data(datadir):
    flows = Path(datadir) / "Flows"
    flows.mkdir(exist_ok=True)
    (flows / (FLOW + ".json")).write_bytes(SKELETON_SRC.read_bytes())


def start_flow(obs):
    ans = obs.request("manager", "cmd.test.command", {"type": "cmd.flow.start", "payload": {"flowId": FLOW}},
                      timeout=8)
    assert ans["payload"]["ok"], ans                       # the manager answered
    assert ans["payload"]["answer"]["ok"], ans             # and the engine accepted the start
    return ans["payload"]["answer"]


def finish(sup, obs):
    """Asks the supervisor to exit and waits for it. Returns its exit code."""
    obs.request("supervisor", "cmd.app.exit", {}, timeout=5)
    code = sup.wait_exit(20)
    assert code is not None, "supervisor did not exit"
    return code


@pytest.fixture
def managed(procs, datadir, session_id):
    """Supervisor with storage, engine and the headless manager; the skeleton flow is in Flows/."""
    flow_data(datadir)
    sup = Sup(procs, datadir, session_id, ["--start=storage,engine,manager", "--headless"])
    obs = connect_obs(sup.pipe)
    wait_ready(obs, ["storage", "engine", "manager"])
    wait_flow_loaded(obs)
    yield sup, obs
    obs.close()
    sup.close_files()


# --- acceptance 2 of the phase: every state change reaches the manager ---------------------------------

@pytest.mark.slow
def test_headless_manager_records_every_skeleton_event_in_order(procs, datadir, session_id, managed):
    sup, obs = managed
    rec = Recorder(obs)
    try:
        for topic in ("engine", "flow:" + FLOW, "log"):
            assert obs.request("supervisor", "cmd.topic.subscribe", {"topic": topic}, timeout=5)["payload"]["ok"]
        # The manager subscribes to the topic of a flow when its snapshot lists the flow (ManagerModel.ApplySnapshot).
        # Until then it cannot receive the events of that flow: the test waits for the model to know the flow first.
        def manager_knows_flow():
            st = obs.request("manager", "cmd.test.state", {}, timeout=5)["payload"]["state"]
            return any(f["flowId"] == FLOW for f in st["flows"])
        assert wait_until(manager_knows_flow, 10), "the manager does not know the flow %s" % FLOW

        # The engine emits its start events (flow list, engine ready) after the flows are loaded. s0 is taken when the
        # engine has been quiet for 0.5 s, so that no start event counts as an event of the flow.
        quiet = {"seq": None, "since": time.monotonic()}

        def engine_quiet():
            sq = engine_snapshot(obs)["seq"]
            if sq != quiet["seq"]:
                quiet["seq"], quiet["since"] = sq, time.monotonic()
                return False
            return time.monotonic() - quiet["since"] >= 0.5

        assert wait_until(engine_quiet, 10), "the engine keeps emitting events"
        s0 = engine_snapshot(obs)["seq"]          # events up to here are not compared
        start_flow(obs)

        def relevant_observed():
            out = []
            for m in rec.snapshot():
                p = m.get("payload", {})
                if str(m.get("to", "")).startswith("topic:") and m.get("type", "").startswith("evt.") \
                        and "seq" in p and p["seq"] > s0 and m["type"] != "evt.log.entry":
                    out.append((m["type"], p["seq"]))
            return dedupe_batches(out)

        # The skeleton run: instance started, flow state, the element state batches (WI-0089: how many depends on the
        # timing, at least one), instance ended, flow state. Wait for the last flow state at the observer ...
        assert wait_until(lambda: sum(1 for t, _ in relevant_observed() if t == "evt.flow.state") >= 2, 10),             relevant_observed()
        observed = relevant_observed()
        # ... and until the manager has recorded as many.
        assert wait_until(lambda: len(trace_events(obs, s0)) >= len(observed), 10),             "the manager recorded fewer events than the observer saw"
        types = [t for t, _ in observed]
        assert types[0] == "evt.instance.started", types
        assert types[-1] == "evt.flow.state", types
        assert 1 <= types.count("evt.element.state") <= 6, types   # batches of the 3 elements (WI-0089)
        assert types.index("evt.element.state") < types.index("evt.instance.ended"), types   # states before the end

        # The manager's record (in the order it received the events) is the proof.
        seen = trace_events(obs, s0)
        assert seen == observed, "manager and observer differ: manager=%s obs=%s" % (seen, observed)

        # Latency from the command of the manager to the arrival of each event, on the clock of the manager.
        entries = trace(obs)
        sent = [e["recvMs"] for e in entries if e["type"] == "manager.command"][-1]
        arrivals = [(e["type"], e["payload"]["seq"], e["recvMs"] - sent) for e in entries
                    if e["type"].startswith("evt.") and "seq" in e["payload"] and e["payload"]["seq"] > s0]
        print("\nlatency ms (command -> manager arrival):", arrivals)
        assert max(ms for _, _, ms in arrivals) < scaled(1000)
    finally:
        rec.close()
    assert finish(sup, obs) == 0

    # (The record is gone with the manager; the latency was taken before the exit, see below.)


# --- acceptance 2: engine restart is seen, the manager is resynced, the manager keeps running ----------

@pytest.mark.slow
def test_engine_restart_is_seen_and_resynced_without_restarting_the_manager(procs, datadir, session_id, managed):
    sup, obs = managed
    rec = Recorder(obs)
    try:
        for topic in ("process", "engine", "log"):
            assert obs.request("supervisor", "cmd.topic.subscribe", {"topic": topic}, timeout=5)["payload"]["ok"]
        before = process_states(obs)
        epoch_before = engine_snapshot(obs)["epoch"]
        manager_pid = before["manager"]["pid"]
        engine_pid = before["engine"]["pid"]

        # Kill the engine process of this test session (started by our supervisor).
        psutil.Process(engine_pid).kill()

        def restarted():
            return any(m.get("type") == "evt.process.restarted" and m["payload"].get("name") == "engine"
                       for m in rec.snapshot())
        assert wait_until(restarted, 15), "observer never saw evt.process.restarted of the engine"

        def new_epoch():
            for m in rec.snapshot():
                if m.get("type") == "evt.engine.ready" and m["payload"].get("epoch") != epoch_before:
                    return m["payload"]["epoch"]
            return None
        epoch_after = wait_until(new_epoch, 15)
        assert epoch_after, "no evt.engine.ready with a new epoch"

        # F-0001: the engine announces its restart itself, with the new epoch, before it is ready.
        def restarted_event():
            for m in rec.snapshot():
                if m.get("type") == "evt.engine.restarted":
                    return m
            return None
        announced = wait_until(restarted_event, 15)
        assert announced, "no evt.engine.restarted on topic engine"
        assert announced["payload"]["epoch"] == epoch_after and announced["payload"]["epoch"] != epoch_before
        assert not any(m.get("type") == "evt.engine.restarted" and m["payload"]["epoch"] == epoch_before
                       for m in rec.snapshot()), "the first start must not announce a restart"

        def resynced_in_log():
            return any(e["type"] == "manager.snapshot" and e["payload"].get("ok") is True
                       and e["payload"].get("epoch") == epoch_after for e in trace(obs))
        assert wait_until(resynced_in_log, 15), "the manager never took a snapshot of the new epoch"

        after = process_states(obs)
        assert after["manager"]["pid"] == manager_pid, "the manager was restarted"
        assert after["manager"]["restarts"] == 0
        assert after["engine"]["pid"] != engine_pid

        # The subscriptions of the manager survived the engine restart: a new run reaches the manager.
        start_flow(obs)

        def run_in_log():
            return any(e["type"] == "evt.instance.ended" and e["payload"].get("epoch") == epoch_after
                       for e in trace(obs))
        assert wait_until(run_in_log, 10), "the manager did not see the run after the restart"
        events = trace(obs)
        assert any(e["type"] == "evt.process.restarted" and e["payload"].get("name") == "engine" for e in events)
        assert any(e["type"] == "manager.engine" and e["payload"].get("state") == "ready" for e in events)
    finally:
        rec.close()
    assert finish(sup, obs) == 0



# --- the manager never blocks on a request ---------------------------------------------------------------

def test_manager_answers_at_once_while_the_engine_is_missing(procs, datadir, session_id):
    flow_data(datadir)
    sup = Sup(procs, datadir, session_id, ["--start=storage,manager", "--headless"])
    obs = connect_obs(sup.pipe)
    try:
        wait_ready(obs, ["storage", "manager"])
        t0 = time.perf_counter()
        ans = obs.request("manager", "cmd.test.command", {"type": "cmd.engine.snapshot", "payload": {}}, timeout=8)
        elapsed = time.perf_counter() - t0
        assert ans["payload"]["ok"], ans                       # the manager answered, not the timeout
        assert ans["payload"]["answer"]["ok"] == 0             # the engine is not there
        assert ans["payload"]["answer"]["error"]["code"] == "not_found", ans
        assert elapsed < scaled(2.0), "answer took %.2f s" % elapsed

        t0 = time.perf_counter()
        pong = obs.request("manager", "sys.ping", {"n": 7}, timeout=5)
        assert time.perf_counter() - t0 < scaled(2.0)
        assert pong["type"] == "sys.pong"
    finally:
        assert finish(sup, obs) == 0
        obs.close()
        sup.close_files()


# --- exit: the manager answers prepareExit; cancelled and normal exits ------------------------------

def test_cancelled_exit_is_answered_and_nothing_stops(procs, datadir, session_id):
    flow_data(datadir)
    sup = Sup(procs, datadir, session_id,
              ["--start=storage,engine,manager", "--headless", "--cancel-exit"])
    obs = connect_obs(sup.pipe)
    rec = Recorder(obs)
    try:
        wait_ready(obs, ["storage", "engine", "manager"])
        for topic in ("process", "log"):
            assert obs.request("supervisor", "cmd.topic.subscribe", {"topic": topic}, timeout=5)["payload"]["ok"]
        assert obs.request("supervisor", "cmd.app.exit", {}, timeout=5)["payload"]["started"] is True

        def cancelled():
            return [m for m in rec.snapshot() if m.get("type") == "evt.app.exitCancelled"]
        got = wait_until(cancelled, 10)
        assert got and got[0]["payload"]["by"] == "manager"
        time.sleep(0.5)
        states = process_states(obs)
        assert states["engine"]["state"] == "ready" and states["storage"]["state"] == "ready"

        def answered_in_log():
            return any(e["type"] == "manager.prepareExit" and e["payload"]["cancel"] is True for e in trace(obs))
        assert wait_until(answered_in_log, 10), "the manager did not record its prepareExit answer"
    finally:
        # The manager always cancels in this mode; the procs fixture ends the tree at teardown.
        rec.close()
        obs.close()
        sup.close_files()


def test_exit_without_cancel_ends_the_manager_cleanly(procs, datadir, session_id):
    flow_data(datadir)
    sup = Sup(procs, datadir, session_id, ["--start=storage,engine,manager", "--headless"])
    obs = connect_obs(sup.pipe)
    try:
        wait_ready(obs, ["storage", "engine", "manager"])
        assert obs.request("supervisor", "cmd.topic.subscribe", {"topic": "process"}, timeout=5)["payload"]["ok"]
        code = finish(sup, obs)
        assert code == 0
    finally:
        obs.close()
        sup.close_files()
