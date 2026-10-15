"""WI-0013: manager stub (src/manager/StubManager.ahk, StubGui.ahk) under the real supervisor, headless.

The supervisor starts storage, engine and manager (--ui=stub --headless) as real processes through
tools/ahkrun.py. The skeleton flow (tests/data/skeleton_flow.json, copied to Flows/skeleton.json) runs
in the engine. A Python observer subscribes to the same topics as the stub, so the two sequences of
events can be compared.

The stub's copy of the events is written by storage into Log/Log_manager.txt ("... ui-event {json}").
The test never reads that file while the run is going on: storage fails to append a line when another
process holds the file (OSError 6, "invalid handle"), and the line is lost (WI-0013 findings, F-0004). The
observer subscribes to topic log instead. storage forwards every line after it has been written, so the
test knows when a line is in the file. The file is read once, after the supervisor has ended.

Timing: recvMs in the stub's lines is the wall clock (ms, UTC) at arrival. The stub also logs
stub.command with the send time of a forwarded command, so the arrival latency is measured on the same
clock. Python requests reach the hub on its 250 ms fallback timer, so times that start with a Python
send are not used; only stub.command -> event arrival is measured.

The GUI (StubGui) is not tested here: see doc/MANUAL-CHECKS.md, section "1. Manager stub (GUI)".
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
UI_PREFIX = "ui-event "
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


def ui_lines_from_log(msgs):
    """Parsed ui-event payloads of the manager, from evt.log.entry messages (topic log), in order."""
    out = []
    for m in msgs:
        if m.get("type") != "evt.log.entry":
            continue
        p = m.get("payload", {})
        text = str(p.get("text", ""))
        if p.get("source") == "manager" and text.startswith(UI_PREFIX):
            out.append(json.loads(text[len(UI_PREFIX):]))
    return out


def stub_events_from_file(datadir):
    """Every ui-event line of the stub from the log file. Read once, after the supervisor has ended."""
    path = Path(datadir) / "Log" / "Log_manager.txt"
    out = []
    for line in path.read_bytes().decode("utf-8", "replace").splitlines():
        if UI_PREFIX in line:
            out.append(json.loads(line[line.index(UI_PREFIX) + len(UI_PREFIX):]))
    return out


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
    assert ans["payload"]["ok"], ans                       # the stub answered
    assert ans["payload"]["answer"]["ok"], ans             # and the engine accepted the start
    return ans["payload"]["answer"]


def finish(sup, obs):
    """Asks the supervisor to exit and waits for it. Returns its exit code."""
    obs.request("supervisor", "cmd.app.exit", {}, timeout=5)
    code = sup.wait_exit(20)
    assert code is not None, "supervisor did not exit"
    return code


@pytest.fixture
def stubbed(procs, datadir, session_id):
    """Supervisor with storage, engine and the headless stub; the skeleton flow is in Flows/."""
    flow_data(datadir)
    sup = Sup(procs, datadir, session_id, ["--start=storage,engine,manager", "--ui=stub", "--headless"])
    obs = connect_obs(sup.pipe)
    wait_ready(obs, ["storage", "engine", "manager"])
    wait_flow_loaded(obs)
    yield sup, obs
    obs.close()
    sup.close_files()


# --- acceptance 2 of the phase: every state change reaches the stub ---------------------------------

@pytest.mark.slow
def test_headless_stub_logs_every_skeleton_event_in_order(procs, datadir, session_id, stubbed):
    sup, obs = stubbed
    rec = Recorder(obs)
    try:
        for topic in ("engine", "flow:" + FLOW, "log"):
            assert obs.request("supervisor", "cmd.topic.subscribe", {"topic": topic}, timeout=5)["payload"]["ok"]
        s0 = engine_snapshot(obs)["seq"]          # events up to here are not compared
        start_flow(obs)

        def relevant_observed():
            out = []
            for m in rec.snapshot():
                p = m.get("payload", {})
                if str(m.get("to", "")).startswith("topic:") and m.get("type", "").startswith("evt.") \
                        and "seq" in p and p["seq"] > s0 and m["type"] != "evt.log.entry":
                    out.append((m["type"], p["seq"]))
            return out

        def relevant_stub(lines):
            return [(e["type"], e["payload"]["seq"]) for e in lines
                    if e["type"].startswith("evt.") and "seq" in e["payload"] and e["payload"]["seq"] > s0]

        # The skeleton run has 10 events from the engine (instance started, flow state, 3 x running and
        # finished, instance ended, flow state). Wait for all of them at the observer ...
        assert wait_until(lambda: len(relevant_observed()) >= 10, 10), relevant_observed()
        observed = relevant_observed()
        # ... and until storage has reported as many stub lines (written to the file, forwarded on log).
        assert wait_until(lambda: len(relevant_stub(ui_lines_from_log(rec.snapshot()))) >= len(observed), 10), \
            "storage reported fewer stub lines than the observer saw"
        ui = ui_lines_from_log(rec.snapshot())
        types = [t for t, _ in observed]
        assert types[0] == "evt.instance.started", types
        assert types[-1] == "evt.flow.state", types
        assert types.count("evt.element.state") == 6, types      # 3 elements, running and finished each

        # The stub's lines (as storage wrote them, in the order storage received them) are the proof.
        # Compare them with the observer's sequence of this run.
        stub_run = relevant_stub(ui)
        assert stub_run == observed, "stub and observer differ:\nstub=%s\nobs=%s" % (stub_run, observed)
    finally:
        rec.close()
    assert finish(sup, obs) == 0

    # The file, read once after the end: every line is there, in the same order as the topic log.
    events = stub_events_from_file(sup.datadir)
    sent = [e["recvMs"] for e in events if e["type"] == "stub.command"][-1]
    arrivals = [(e["type"], e["payload"]["seq"], e["recvMs"] - sent) for e in events
                if e["type"].startswith("evt.") and "seq" in e["payload"] and e["payload"]["seq"] > s0]
    print("\nlatency ms (command -> stub arrival):", arrivals)
    assert max(ms for _, _, ms in arrivals) < scaled(1000)
    assert relevant_stub(events) == observed


# --- acceptance 2: engine restart is seen, the stub is resynced, the stub keeps running ----------

@pytest.mark.slow
def test_engine_restart_is_seen_and_resynced_without_restarting_the_stub(procs, datadir, session_id, stubbed):
    sup, obs = stubbed
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
            return any(e["type"] == "stub.snapshot" and e["payload"].get("ok") == 1
                       and e["payload"].get("epoch") == epoch_after for e in ui_lines_from_log(rec.snapshot()))
        assert wait_until(resynced_in_log, 15), "storage never reported a snapshot of the new epoch"

        after = process_states(obs)
        assert after["manager"]["pid"] == manager_pid, "the stub was restarted"
        assert after["manager"]["restarts"] == 0
        assert after["engine"]["pid"] != engine_pid

        # The subscriptions of the stub survived the engine restart: a new run reaches the stub.
        start_flow(obs)

        def run_in_log():
            return any(e["type"] == "evt.instance.ended" and e["payload"].get("epoch") == epoch_after
                       for e in ui_lines_from_log(rec.snapshot()))
        assert wait_until(run_in_log, 10), "the stub did not report the run after the restart"
    finally:
        rec.close()
    assert finish(sup, obs) == 0

    events = stub_events_from_file(sup.datadir)
    assert any(e["type"] == "evt.process.restarted" and e["payload"].get("name") == "engine" for e in events)
    assert any(e["type"] == "stub.snapshot" and e["payload"].get("epoch") == epoch_after for e in events)


# --- the stub never blocks on a request ---------------------------------------------------------------

def test_stub_answers_at_once_while_the_engine_is_missing(procs, datadir, session_id):
    flow_data(datadir)
    sup = Sup(procs, datadir, session_id, ["--start=storage,manager", "--ui=stub", "--headless"])
    obs = connect_obs(sup.pipe)
    try:
        wait_ready(obs, ["storage", "manager"])
        t0 = time.perf_counter()
        ans = obs.request("manager", "cmd.test.command", {"type": "cmd.engine.snapshot", "payload": {}}, timeout=8)
        elapsed = time.perf_counter() - t0
        assert ans["payload"]["ok"], ans                       # the stub answered, not the timeout
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


# --- exit: the stub answers prepareExit; cancelled and normal exits ------------------------------

def test_cancelled_exit_is_answered_and_nothing_stops(procs, datadir, session_id):
    flow_data(datadir)
    sup = Sup(procs, datadir, session_id,
              ["--start=storage,engine,manager", "--ui=stub", "--headless", "--stub-cancel-exit"])
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
            return any(e["type"] == "stub.prepareExit" and e["payload"]["cancel"] is True
                       for e in ui_lines_from_log(rec.snapshot()))
        assert wait_until(answered_in_log, 10), "storage never reported the stub's prepareExit answer"
    finally:
        # The stub always cancels in this mode; the procs fixture ends the tree at teardown.
        rec.close()
        obs.close()
        sup.close_files()


def test_exit_without_cancel_ends_the_stub_cleanly(procs, datadir, session_id):
    flow_data(datadir)
    sup = Sup(procs, datadir, session_id, ["--start=storage,engine,manager", "--ui=stub", "--headless"])
    obs = connect_obs(sup.pipe)
    try:
        wait_ready(obs, ["storage", "engine", "manager"])
        assert obs.request("supervisor", "cmd.topic.subscribe", {"topic": "process"}, timeout=5)["payload"]["ok"]
        code = finish(sup, obs)
        assert code == 0
        assert any(e["type"] == "stub.shutdown" for e in stub_events_from_file(sup.datadir))
    finally:
        obs.close()
        sup.close_files()
