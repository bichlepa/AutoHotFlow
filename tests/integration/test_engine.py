"""WI-10: engine role (src/engine/).

The engine runs as a real process (src/AutoHotFlow.ahk --role=engine, started through tools/ahkrun.py).
Its hub is the Python stand-in tests/support/pyhub.py (WakingHub, see test_peer.py). Its storage is a
Python stand-in as well (StorageStub below, same protocol as WI-12 will implement), so the engine can be
tested before the storage role exists. Observers are AhfClient instances that subscribe to topics.
"""

import json
import shutil
import threading
import time
from pathlib import Path

import pytest

from support.ahfclient import AhfClient
from support.timing import scaled
from test_role import (FLOOD_PINGS, STALL_S, RoleHub, RoleRun, StallingHub, ahk_process, first_pong_of,
                       flood_pings, pongs_from, wait_hello)

ROOT = Path(__file__).resolve().parents[2]
SKELETON_SRC = ROOT / "tests" / "data" / "skeleton_flow.json"
READY_TIMEOUT_S = 15.0


class StorageStub:
    """Answers cmd.storage.flows.list and cmd.storage.flow.read from a data directory (Flows/*.json)."""

    def __init__(self, pipe, datadir):
        self.datadir = Path(datadir)
        self.client = AhfClient(pipe, "storage")
        self._stop = False
        self._thread = threading.Thread(target=self._serve, name="storage-stub", daemon=True)
        self.list_calls = 0
        self.read_calls = []
        self.logs = []          # payloads of evt.log.append (noReply), in arrival order

    def start(self):
        self._thread.start()
        return self

    def close(self):
        self._stop = True
        self.client.close()
        self._thread.join(timeout=3.0)

    def _serve(self):
        while not self._stop:
            for msg in self.client.events(timeout=0.2):
                try:
                    self._handle(msg)
                except Exception:       # the test closed the client while a message was being answered
                    if not self._stop:
                        raise

    def _handle(self, msg):
        type_ = msg.get("type")
        payload = msg.get("payload", {})
        if type_ == "evt.log.append":
            self.logs.append(payload)
        elif type_ == "cmd.storage.flows.list":
            self.list_calls += 1
            files = []
            for p in sorted((self.datadir / "Flows").glob("*.json")):
                files.append({"path": "Flows/" + p.name, "name": p.stem, "mtime": int(p.stat().st_mtime)})
            self.client.reply(msg, {"ok": True, "files": files})
        elif type_ == "cmd.storage.flow.read":
            path = payload.get("path", "")
            self.read_calls.append(path)
            target = self.datadir / path
            if target.is_file():
                self.client.reply(msg, {"ok": True, "text": target.read_text(encoding="utf-8")})
            else:
                self.client.reply(msg, {"ok": False, "error": {"code": "not_found", "message": path}})


@pytest.fixture
def pipe(session_id):
    return "ahf.engine.%s" % session_id


@pytest.fixture
def runs(procs):
    started = []
    yield started
    for run in started:
        run.close_files()


@pytest.fixture
def hub(pipe):
    with RoleHub(pipe) as h:
        yield h


@pytest.fixture
def flowdir(datadir):
    """A data directory with the skeleton flow in Flows/, as storage would hold it."""
    (datadir / "Flows").mkdir()
    shutil.copy(SKELETON_SRC, datadir / "Flows" / "skeleton.json")
    return datadir


@pytest.fixture
def storage(hub, pipe, flowdir):
    stub = StorageStub(pipe, flowdir).start()
    yield stub
    stub.close()


def start_engine(procs, datadir, runs, pipe, session_id, label="engine"):
    args = ["--role=engine", "--session=" + session_id, "--hub=" + pipe, "--data=" + str(datadir), "--workers=0"]
    run = RoleRun(procs, datadir, label, args)
    runs.append(run)
    return run


def observer(pipe, *topics):
    """A client that subscribes to the topics first (PROTOCOL 5a: subscribe, then take the snapshot)."""
    client = AhfClient(pipe, "obs")
    for topic in topics:
        answer = client.request("supervisor", "cmd.topic.subscribe", {"topic": topic}, timeout=5)
        assert answer["payload"]["ok"], answer
    return client


def wait_ready(obs, timeout=READY_TIMEOUT_S):
    msg = obs.wait_event("evt.engine.ready", timeout=timeout)
    return msg["payload"]


def ask(obs, type_, payload=None, timeout=5.0):
    """Sends a request to the engine and returns its payload (the answer must not be an error)."""
    answer = obs.request("engine", type_, payload or {}, timeout=timeout)
    assert answer["payload"].get("ok") is True, answer   # a real JSON boolean (PROTOKOLL 2)
    return answer["payload"]


# --- start and snapshot -----------------------------------------------------------------------------

def test_engine_loads_flow_announces_ready_and_answers_snapshot(procs, datadir, runs, session_id, pipe, hub,
                                                              flowdir, storage):
    with observer(pipe, "engine") as obs:
        run = start_engine(procs, flowdir, runs, pipe, session_id)
        ready = wait_ready(obs)
        assert ready["epoch"] > 0 and ready["seq"] >= 1
        assert storage.list_calls == 1 and storage.read_calls == ["Flows/skeleton.json"]

        snap = ask(obs, "cmd.engine.snapshot")
        assert snap["ok"] and snap["epoch"] == ready["epoch"]
        assert [f["flowId"] for f in snap["flows"]] == ["skeleton"]
        flow = snap["flows"][0]
        assert flow["name"] == "Skeleton" and flow["rev"] == 1
        assert flow["enabled"] is False and flow["executing"] is False   # real JSON booleans (PROTOCOL 2)
        assert snap["settings"] == {}

        hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})
        assert run.wait_exit(timeout=10) == 0, run.stderr_text()


class HoldingStorageStub(StorageStub):
    """Does not answer cmd.storage.flow.read by itself: the test answers the held requests one by one."""

    def __init__(self, pipe, datadir, answer_code=None):
        super().__init__(pipe, datadir)
        self.held = []
        self.max_held = 0
        self.answer_code = answer_code      # when set, the first read is answered with this error code

    def _handle(self, msg):
        if msg.get("type") != "cmd.storage.flow.read":
            return super()._handle(msg)
        self.read_calls.append(msg["payload"].get("path", ""))
        self.held.append(msg)
        self.max_held = max(self.max_held, len(self.held))
        if self.answer_code:
            self.client.reply(self.held.pop(), {"ok": False, "error": {"code": self.answer_code, "message": "test"}})

    def release_one(self):
        msg = self.held.pop(0)
        target = self.datadir / msg["payload"]["path"]
        self.client.reply(msg, {"ok": True, "text": target.read_text(encoding="utf-8")})


class DyingStorageStub(StorageStub):
    """Serves `serve` reads, then answers every read with peer_gone (as the hub does for a storage that has died)."""

    def __init__(self, pipe, datadir, serve):
        super().__init__(pipe, datadir)
        self.serve = serve
        self.ok_paths = []
        self.failed_paths = []

    def _handle(self, msg):
        if msg.get("type") != "cmd.storage.flow.read":
            return super()._handle(msg)
        path = msg["payload"].get("path", "")
        if len(self.ok_paths) < self.serve:
            self.ok_paths.append(path)
            return super()._handle(msg)
        self.read_calls.append(path)
        self.failed_paths.append(path)
        self.client.reply(msg, {"ok": False, "error": {"code": "peer_gone", "message": "storage gone"}})


def wait_for(predicate, timeout=5.0):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if predicate():
            return True
        time.sleep(0.02)
    return False


def test_engine_reads_at_most_two_flow_files_at_a_time_while_loading(procs, datadir, runs, session_id, pipe, hub,
                                                                    flowdir):
    # WI-24: the next read is sent when an answer has been handled, so pings get their turn in between.
    for n in range(8):
        shutil.copy(SKELETON_SRC, flowdir / "Flows" / ("copy%d.json" % n))
    stub = HoldingStorageStub(pipe, flowdir).start()
    try:
        with observer(pipe, "engine") as obs:
            run = start_engine(procs, flowdir, runs, pipe, session_id)
            assert wait_for(lambda: len(stub.held) == 2), "expected two requests in flight, got %d" % len(stub.held)
            time.sleep(0.5)
            assert len(stub.held) == 2 and len(stub.read_calls) == 2, "more than two reads in flight: %s" % stub.read_calls
            for answered in range(1, 10):
                stub.release_one()
                expected = min(2, 9 - answered)         # held requests after this answer: the next one has followed
                assert wait_for(lambda: len(stub.held) == expected),                     "after answer %d: %d held, expected %d" % (answered, len(stub.held), expected)
            assert stub.max_held <= 2, stub.max_held
            wait_ready(obs)
            snap = ask(obs, "cmd.engine.snapshot")
            assert len(snap["flows"]) == 9
            hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})
            assert run.wait_exit(timeout=10) == 0, run.stderr_text()
    finally:
        stub.close()


def test_engine_does_not_ask_for_more_files_when_storage_has_stopped_answering(procs, datadir, runs, session_id, pipe,
                                                                              hub, flowdir):
    # A storage that does not answer would make 200 reads wait for their deadline one after the other once
    # they are staggered; after the first transport failure no further file is asked for (WI-24). Since WI-31 this
    # is no error either: the engine waits, and when storage answers again it reads everything (no file had a result).
    for n in range(8):
        shutil.copy(SKELETON_SRC, flowdir / "Flows" / ("copy%d.json" % n))
    stub = DyingStorageStub(pipe, flowdir, serve=0).start()
    try:
        with observer(pipe, "engine") as obs:
            run = start_engine(procs, flowdir, runs, pipe, session_id)
            assert wait_for(lambda: len(stub.failed_paths) >= 1, timeout=READY_TIMEOUT_S), "no read was asked"
            seen = [m for m in obs.events(timeout=2.5) if m["type"] in ("evt.storage.error", "evt.engine.ready")]
            assert not seen, [m["type"] + " " + str(m["payload"]) for m in seen]
            assert set(stub.read_calls) <= {"Flows/copy0.json", "Flows/copy1.json"}, stub.read_calls   # only the first two, again and again at 1 s intervals
            stub.serve = 100                                       # storage answers again; the engine polls the state
            wait_ready(obs)
            snap = ask(obs, "cmd.engine.snapshot")
            assert snap["ok"] and len(snap["flows"]) == 9
            hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})
            assert run.wait_exit(timeout=10) == 0, run.stderr_text()
    finally:
        stub.close()


def test_engine_waits_for_a_storage_that_starts_5_s_after_it_and_reports_no_error(procs, datadir, runs, session_id,
                                                                                 pipe, hub, flowdir):
    # WI-31 (F-31, F-24): before, the engine gave up after 5 tries in 2.5 s and never loaded; every try that hit
    # "no peer 'storage'" was also reported as evt.storage.error.
    with observer(pipe, "engine") as obs:
        run = start_engine(procs, flowdir, runs, pipe, session_id)
        assert hub.wait_for_peer("engine", timeout=READY_TIMEOUT_S)
        early = []
        deadline = time.monotonic() + 5.0
        while time.monotonic() < deadline:                 # storage is late by 5 s
            early += [m for m in obs.events(timeout=0.2) if m["type"] in ("evt.storage.error", "evt.engine.ready")]
        assert not early, [m["type"] + " " + str(m["payload"]) for m in early]
        stub = StorageStub(pipe, flowdir).start()
        try:
            errors = []
            for msg in obs.events(timeout=READY_TIMEOUT_S):
                if msg["type"] == "evt.storage.error":
                    errors.append(msg)
                elif msg["type"] == "evt.engine.ready":
                    break
            else:
                pytest.fail("no evt.engine.ready after storage came up\n" + run.stderr_text())
            assert not errors, [m["payload"] for m in errors]
            assert stub.list_calls == 1 and stub.read_calls == ["Flows/skeleton.json"]
            snap = ask(obs, "cmd.engine.snapshot")
            assert [f["flowId"] for f in snap["flows"]] == ["skeleton"]
            hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})
            assert run.wait_exit(timeout=10) == 0, run.stderr_text()
        finally:
            stub.close()


def test_engine_resumes_loading_when_storage_restarts_in_the_middle_and_loads_only_the_missing_files(
        procs, datadir, runs, session_id, pipe, hub, flowdir):
    # WI-31 (F-24 follow-up): before, the files after the break were failed as errors and never loaded again.
    for n in range(19):
        shutil.copy(SKELETON_SRC, flowdir / "Flows" / ("copy%02d.json" % n))
    all_paths = sorted("Flows/" + p.name for p in (flowdir / "Flows").glob("*.json"))
    assert len(all_paths) == 20
    first = DyingStorageStub(pipe, flowdir, serve=7).start()
    second = None
    try:
        with observer(pipe, "engine") as obs:
            run = start_engine(procs, flowdir, runs, pipe, session_id)
            assert wait_for(lambda: len(first.failed_paths) >= 1, timeout=READY_TIMEOUT_S), "storage never failed"
            first.close()                                   # the storage process is gone
            assert not [m for m in obs.events(timeout=1.0) if m["type"] in ("evt.engine.ready", "evt.storage.error")]
            second = StorageStub(pipe, flowdir).start()     # it starts again: evt.process.ready storage
            errors = []
            for msg in obs.events(timeout=READY_TIMEOUT_S):
                if msg["type"] == "evt.storage.error":
                    errors.append(msg)
                elif msg["type"] == "evt.engine.ready":
                    break
            else:
                pytest.fail("no evt.engine.ready after storage came back\n" + run.stderr_text())
            assert not errors, [m["payload"] for m in errors]
            snap = ask(obs, "cmd.engine.snapshot")
            assert len(snap["flows"]) == 20
            assert set(first.ok_paths) | set(second.read_calls) == set(all_paths)
            assert not set(first.ok_paths) & set(second.read_calls), "files that were loaded were read again"
            assert len(second.read_calls) == 20 - len(first.ok_paths)
            hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})
            assert run.wait_exit(timeout=10) == 0, run.stderr_text()
    finally:
        first.close()
        if second:
            second.close()


def test_flow_get_returns_the_definition_and_unknown_flow_is_not_found(procs, datadir, runs, session_id, pipe,
                                                                      hub, flowdir, storage):
    with observer(pipe, "engine") as obs:
        run = start_engine(procs, flowdir, runs, pipe, session_id)
        wait_ready(obs)

        got = ask(obs, "cmd.flow.get", {"flowId": "skeleton"})
        assert got["ok"] and got["rev"] == 1
        definition = got["definition"]
        assert definition["name"] == "Skeleton"
        assert sorted(definition["allElements"].keys()) == ["element0000000001", "element0000000002",
                                                           "element0000000003"]
        assert definition["allElements"]["element0000000002"]["pars"]["Duration"] == "200"

        missing = obs.request("engine", "cmd.flow.get", {"flowId": "nope"}, timeout=5)
        assert not missing["payload"]["ok"]
        assert missing["payload"]["error"]["code"] == "not_found"

        no_id = obs.request("engine", "cmd.flow.get", {}, timeout=5)
        assert no_id["payload"]["error"]["code"] == "bad_payload"

        hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})
        assert run.wait_exit(timeout=10) == 0, run.stderr_text()


def test_broken_flow_file_is_reported_and_does_not_block_the_start(procs, datadir, runs, session_id, pipe, hub,
                                                                   flowdir, storage):
    (flowdir / "Flows" / "broken.json").write_text("{ not json", encoding="utf-8")
    with observer(pipe, "engine") as obs:
        run = start_engine(procs, flowdir, runs, pipe, session_id)
        err = obs.wait_event("evt.storage.error", timeout=READY_TIMEOUT_S)
        assert err["payload"]["op"] == "flow.parse"
        assert err["payload"]["path"] == "Flows/broken.json"
        wait_ready(obs)

        snap = ask(obs, "cmd.engine.snapshot")
        assert [f["flowId"] for f in snap["flows"]] == ["skeleton"]

        hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})
        assert run.wait_exit(timeout=10) == 0, run.stderr_text()


# --- running flows ----------------------------------------------------------------------------------

TRIGGER, SLEEP, DONE = "element0000000001", "element0000000002", "element0000000003"


def make_flow(flowdir, name, sleep_ms=200, policy="default", element_class=None):
    """Writes Flows/<name>.json: the skeleton with a changed second element (see tests/data)."""
    flow = json.loads(SKELETON_SRC.read_text(encoding="utf-8"))
    flow["name"] = name
    flow["flowSettings"]["ExecutionPolicy"] = policy
    element = flow["allElements"][SLEEP]
    if element_class is None:
        element["pars"] = {"Duration": str(sleep_ms), "Unit": "Milliseconds"}
    else:
        element["class"] = element_class
        element["name"] = element_class
        element["pars"] = {}
    (flowdir / "Flows" / (name + ".json")).write_text(json.dumps(flow, ensure_ascii=False, indent=2),
                                                      encoding="utf-8")


def subscribe_flow(pipe, flow_id):
    return observer(pipe, "engine", "flow:" + flow_id)


def collect_until(obs, predicate, timeout=10.0):
    """Returns [(monotonic time, message)] up to and including the first message that satisfies predicate."""
    got = []
    for msg in obs.events(timeout=timeout):
        got.append((time.monotonic(), msg))
        if predicate(msg):
            return got
    raise AssertionError("expected message not received; got %s" % [m["type"] for _, m in got])


def wait_for(predicate, timeout=3.0):
    """Polls predicate until it returns a true value (log lines arrive on another connection)."""
    deadline = time.monotonic() + timeout
    while True:
        value = predicate()
        if value or time.monotonic() > deadline:
            return value
        time.sleep(0.02)


def element_states(got):
    """(elementId, state, countRuns, message) of the evt.element.state messages in got."""
    return [(m["payload"]["elementId"], m["payload"]["state"], m["payload"]["countRuns"],
             m["payload"].get("message")) for _, m in got if m["type"] == "evt.element.state"]


def is_type(type_):
    return lambda m: m.get("type") == type_


def stop_flow(obs, flow_id):
    return ask(obs, "cmd.flow.stop", {"flowId": flow_id})


def check_seq(got):
    seqs = [m["payload"]["seq"] for _, m in got if "seq" in m.get("payload", {})]
    assert seqs == sorted(seqs) and len(set(seqs)) == len(seqs), seqs
    epochs = {m["payload"]["epoch"] for _, m in got if "epoch" in m.get("payload", {})}
    assert len(epochs) == 1, epochs


@pytest.fixture
def engine(procs, datadir, runs, session_id, pipe, hub, flowdir, storage):
    """A running engine with the flows of flowdir (write them before using this fixture)."""
    run = start_engine(procs, flowdir, runs, pipe, session_id)
    yield run
    if run.proc.poll() is None:
        hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 2000})
        run.wait_exit(timeout=10)


def test_start_emits_the_documented_event_order(pipe, flowdir, engine):
    with subscribe_flow(pipe, "skeleton") as obs:
        wait_ready(obs)
        started = ask(obs, "cmd.flow.start", {"flowId": "skeleton"})
        # The engine sends evt.instance.ended first, then evt.flow.state with executing 0 (PROTOCOL 4.3).
        got = collect_until(obs, lambda m: m["type"] == "evt.flow.state" and m["payload"]["executing"] == 0)
    types = [m["type"] for _, m in got if m["type"] != "evt.engine.ready"]
    assert types[0] == "evt.instance.started" and got[0][1]["payload"]["instanceId"] == started["instanceId"]
    assert types[-2:] == ["evt.instance.ended", "evt.flow.state"] and got[-2][1]["payload"]["reason"] == "finished"
    assert element_states(got) == [
        (TRIGGER, "running", 1, None), (TRIGGER, "finished", 0, None),
        (SLEEP, "running", 1, None), (SLEEP, "finished", 0, None),
        (DONE, "running", 1, None), (DONE, "finished", 0, None),
    ]
    flow_states = [m["payload"]["executing"] for _, m in got if m["type"] == "evt.flow.state"]
    assert flow_states == [1, 0]
    sleep_running = next(t for t, m in got if m["type"] == "evt.element.state" and m["payload"]["elementId"] == SLEEP
                         and m["payload"]["state"] == "running")
    sleep_done = next(t for t, m in got if m["type"] == "evt.element.state" and m["payload"]["elementId"] == SLEEP
                      and m["payload"]["state"] == "finished")
    assert sleep_done - sleep_running >= 0.18, "Action_Sleep 200 ms finished after %.3f s" % (sleep_done - sleep_running)
    check_seq(got)


def test_stop_during_sleep_ends_the_instance_within_500_ms(pipe, flowdir, engine):
    make_flow(flowdir, "slow", sleep_ms=5000)
    with subscribe_flow(pipe, "slow") as obs:
        wait_ready(obs)
        ask(obs, "cmd.flow.start", {"flowId": "slow"})
        collect_until(obs, lambda m: m["type"] == "evt.element.state" and m["payload"]["elementId"] == SLEEP
                      and m["payload"]["state"] == "running")
        t0 = time.monotonic()
        stopped = stop_flow(obs, "slow")
        got = collect_until(obs, is_type("evt.instance.ended"), timeout=5)
        elapsed = got[-1][0] - t0
        assert stopped["stopped"] == 1
        assert elapsed < scaled(0.5), "instance ended %.3f s after the stop" % elapsed
        assert got[-1][1]["payload"]["reason"] == "flow.stop"
        assert element_states(got) == [(SLEEP, "finished", 0, None)]
        quiet = list(obs.events(timeout=0.4))
        assert not [m for m in quiet if m["type"] == "evt.element.state"], "no further element may run"
        snap = ask(obs, "cmd.engine.snapshot")
        assert not [f for f in snap["flows"] if f["flowId"] == "slow"][0]["executing"]


def test_element_exception_is_reported_and_the_engine_keeps_running(pipe, flowdir, engine, storage):
    make_flow(flowdir, "throw", element_class="Action_TestThrow")
    with subscribe_flow(pipe, "throw") as obs:
        wait_ready(obs)
        ask(obs, "cmd.flow.start", {"flowId": "throw"})
        got = collect_until(obs, is_type("evt.instance.ended"), timeout=10)
        assert element_states(got) == [(TRIGGER, "running", 1, None), (TRIGGER, "finished", 0, None),
                                       (SLEEP, "running", 1, None), (SLEEP, "exception", 0, "test")]
        assert got[-1][1]["payload"]["reason"] == "exception"
        logged = wait_for(lambda: [e for e in storage.logs if e.get("level") == "f0"
                                   and "unhandled exception in element" in e.get("text", "")])
        assert logged, storage.logs
        again = ask(obs, "cmd.flow.start", {"flowId": "throw"})     # the engine still runs flows
        assert again["instanceId"]
        collect_until(obs, is_type("evt.instance.ended"), timeout=10)


def test_worker_element_is_reported_as_exception_not_skipped(pipe, flowdir, engine):
    make_flow(flowdir, "worker", element_class="Action_TestBlockWorker")
    with subscribe_flow(pipe, "worker") as obs:
        wait_ready(obs)
        ask(obs, "cmd.flow.start", {"flowId": "worker"})
        got = collect_until(obs, is_type("evt.instance.ended"), timeout=10)
        states = element_states(got)
        assert states[-1][:2] == (SLEEP, "exception") and "worker not available" in states[-1][3]
        assert got[-1][1]["payload"]["reason"] == "exception"


def test_toggle_starts_and_stops_a_flow(pipe, flowdir, engine):
    make_flow(flowdir, "slow", sleep_ms=5000)
    with subscribe_flow(pipe, "slow") as obs:
        wait_ready(obs)
        def executing():
            snap = ask(obs, "cmd.engine.snapshot")
            return [f["executing"] for f in snap["flows"] if f["flowId"] == "slow"][0]

        assert ask(obs, "cmd.flow.toggle", {"flowId": "slow"})["action"] == "started"
        assert executing() == 1
        assert ask(obs, "cmd.flow.toggle", {"flowId": "slow"})["action"] == "stopped"
        assert executing() == 0


def test_enable_and_disable_set_the_flag_and_report_it(pipe, flowdir, engine):
    with subscribe_flow(pipe, "skeleton") as obs:
        wait_ready(obs)
        ask(obs, "cmd.flow.enable", {"flowId": "skeleton"})
        state = obs.wait_event("evt.flow.state", timeout=5)["payload"]
        assert state["enabled"] is True and state["executing"] is False
        assert ask(obs, "cmd.engine.snapshot")["flows"][0]["enabled"] is True
        ask(obs, "cmd.flow.disable", {"flowId": "skeleton"})
        assert obs.wait_event("evt.flow.state", timeout=5)["payload"]["enabled"] is False


@pytest.mark.parametrize("policy", ["parallel", "default"])
def test_parallel_and_default_policy_start_a_second_instance(pipe, flowdir, engine, policy):
    make_flow(flowdir, "pol", sleep_ms=5000, policy=policy)
    with subscribe_flow(pipe, "pol") as obs:
        wait_ready(obs)
        first = ask(obs, "cmd.flow.start", {"flowId": "pol"})["instanceId"]
        second = ask(obs, "cmd.flow.start", {"flowId": "pol"})["instanceId"]
        assert first != second
        assert stop_flow(obs, "pol")["stopped"] == 2


def test_skip_policy_refuses_a_second_start_with_busy(pipe, flowdir, engine):
    make_flow(flowdir, "pol", sleep_ms=5000, policy="skip")
    with subscribe_flow(pipe, "pol") as obs:
        wait_ready(obs)
        ask(obs, "cmd.flow.start", {"flowId": "pol"})
        refused = obs.request("engine", "cmd.flow.start", {"flowId": "pol"}, timeout=5)
        assert not refused["payload"]["ok"] and refused["payload"]["error"]["code"] == "busy"
        stop_flow(obs, "pol")


def instance_log(got, ids):
    """['started:1', 'queued:2', ...] of the evt.instance.* messages in got; the number is the index in ids."""
    return ["%s:%d" % (m["type"].split(".")[-1], ids.index(m["payload"]["instanceId"]) + 1)
            for _, m in got if m["type"].startswith("evt.instance.")]


def test_wait_policy_queues_the_starts_and_runs_them_one_after_the_other(pipe, flowdir, engine):
    make_flow(flowdir, "pol", sleep_ms=300, policy="wait")
    with subscribe_flow(pipe, "pol") as obs:
        wait_ready(obs)
        answers = [ask(obs, "cmd.flow.start", {"flowId": "pol"}) for _ in range(3)]
        ids = [a["instanceId"] for a in answers]
        assert len(set(ids)) == 3
        assert "waiting" not in answers[0] and answers[1]["waiting"] is True and answers[2]["waiting"] is True
        assert ask(obs, "cmd.engine.snapshot")["flows"][0]["executing"] is True
        ended = []

        def third_ended(m):
            if m["type"] == "evt.instance.ended":
                ended.append(m)
            return len(ended) == 3

        got = collect_until(obs, third_ended, timeout=10)
        # The first events were sent before the observer read them: the start of 1 and the queueing of 2 and 3
        # are part of got, in this order.
        assert instance_log(got, ids) == ["started:1", "queued:2", "queued:3", "ended:1", "started:2", "ended:2",
                                          "started:3", "ended:3"]
        assert [m["payload"]["reason"] for m in ended] == ["finished"] * 3
        # No two instances ran at the same time: each Sleep started after the one before had finished.
        sleeps = [(m["payload"]["state"], t) for t, m in got
                  if m["type"] == "evt.element.state" and m["payload"]["elementId"] == SLEEP]
        assert [s for s, _ in sleeps] == ["running", "finished"] * 3, sleeps
        queued = [m["payload"]["position"] for _, m in got if m["type"] == "evt.instance.queued"]
        assert queued == [1, 2]
        check_seq(got)
        # The flow is executing until the last instance has ended; evt.flow.state 0 follows the last ended.
        flow_states = [m["payload"]["executing"] for _, m in got if m["type"] == "evt.flow.state"]
        assert flow_states == [1, 1, 1], flow_states
        assert obs.wait_event("evt.flow.state", timeout=5)["payload"]["executing"] == 0


def test_wait_policy_stop_ends_the_running_and_the_waiting_instances(pipe, flowdir, engine):
    make_flow(flowdir, "pol", sleep_ms=5000, policy="wait")
    with subscribe_flow(pipe, "pol") as obs:
        wait_ready(obs)
        ids = [ask(obs, "cmd.flow.start", {"flowId": "pol"})["instanceId"] for _ in range(3)]
        assert stop_flow(obs, "pol")["stopped"] == 3
        got = collect_until(obs, lambda m: m["type"] == "evt.flow.state" and m["payload"]["executing"] == 0,
                            timeout=5)
        # The waiting instances end first and never start (PROTOCOL 4.3).
        assert instance_log(got, ids) == ["started:1", "queued:2", "queued:3", "ended:2", "ended:3", "ended:1"]
        assert ask(obs, "cmd.engine.snapshot")["flows"][0]["executing"] == 0
        assert not [m for m in obs.events(timeout=0.4) if m["type"] == "evt.instance.started"]


def test_stop_policy_stops_the_running_instance_and_starts_a_new_one(pipe, flowdir, engine):
    make_flow(flowdir, "pol", sleep_ms=5000, policy="stop")
    with subscribe_flow(pipe, "pol") as obs:
        wait_ready(obs)
        first = ask(obs, "cmd.flow.start", {"flowId": "pol"})["instanceId"]
        second = ask(obs, "cmd.flow.start", {"flowId": "pol"})["instanceId"]
        assert first != second
        ended = collect_until(obs, lambda m: m["type"] == "evt.instance.ended"
                              and m["payload"]["instanceId"] == first, timeout=5)
        assert ended[-1][1]["payload"]["reason"] == "policy stop"
        assert ask(obs, "cmd.engine.snapshot")["flows"][0]["executing"] is True
        stop_flow(obs, "pol")


def test_invalid_policy_value_is_bad_payload(pipe, flowdir, engine):
    make_flow(flowdir, "pol", policy="bogus")
    with subscribe_flow(pipe, "pol") as obs:
        wait_ready(obs)
        answer = obs.request("engine", "cmd.flow.start", {"flowId": "pol"}, timeout=5)
        assert answer["payload"]["error"]["code"] == "bad_payload"


def test_shutdown_stops_running_instances_and_says_bye_within_the_deadline(procs, datadir, runs, session_id, pipe,
                                                                           hub, flowdir, storage):
    make_flow(flowdir, "slow", sleep_ms=5000)
    with subscribe_flow(pipe, "slow") as obs:
        run = start_engine(procs, flowdir, runs, pipe, session_id)
        wait_ready(obs)
        ask(obs, "cmd.flow.start", {"flowId": "slow"})
        collect_until(obs, lambda m: m["type"] == "evt.element.state" and m["payload"]["elementId"] == SLEEP
                      and m["payload"]["state"] == "running")
        t0 = time.monotonic()
        hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 2000})
        got = collect_until(obs, is_type("evt.instance.ended"), timeout=5)
        assert got[-1][1]["payload"]["reason"] == "shutdown"
        bye = hub.wait_received(lambda m: m.get("type") == "sys.bye" and m.get("from") == "engine", timeout=3)
        assert bye is not None and bye["payload"]["clean"] is not None
        assert run.wait_exit(timeout=5) == 0, run.stderr_text()
        elapsed = time.monotonic() - t0
        assert elapsed < scaled(2.0), "shutdown took %.3f s" % elapsed


MANY_INSTANCES = 40


def test_shutdown_with_many_instances_and_a_hub_that_reads_late_delivers_every_ended(procs, datadir, runs,
                                                                                      session_id, pipe, flowdir):
    # WI-30 (F-26 cause A): at sys.shutdown the send queue of the engine is full (the hub reads nothing for
    # STALL_S). StopAll still reaches the observer with one evt.instance.ended per instance, then sys.bye.
    make_flow(flowdir, "many", sleep_ms=10000, policy="parallel")
    with StallingHub(pipe, first_pong_of("engine"), STALL_S) as hub:
        storage = StorageStub(pipe, flowdir).start()
        try:
            with subscribe_flow(pipe, "many") as obs:
                run = start_engine(procs, flowdir, runs, pipe, session_id)
                wait_ready(obs)
                ids = {ask(obs, "cmd.flow.start", {"flowId": "many"})["instanceId"] for _ in range(MANY_INSTANCES)}
                assert len(ids) == MANY_INSTANCES
                pid = wait_hello(hub, "engine")
                ahk = ahk_process(pid)
                flood_pings(hub, "engine")
                hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 3000})
                assert ahk.wait(timeout=10) == 0, run.stderr_text()
                ended = {}
                deadline = time.monotonic() + 10.0
                while len(ended) < MANY_INSTANCES and time.monotonic() < deadline:
                    for msg in obs.events(timeout=0.5):
                        if msg.get("type") == "evt.instance.ended":
                            ended[msg["payload"]["instanceId"]] = msg["payload"]["reason"]
                assert hub.stalled.is_set()
                assert set(ended) == ids, "%d of %d evt.instance.ended" % (len(ended), MANY_INSTANCES)
                assert set(ended.values()) == {"shutdown"}, set(ended.values())
                bye = hub.wait_received(lambda m: m.get("type") == "sys.bye" and m.get("from") == "engine", timeout=5)
                assert bye is not None and bye["payload"]["clean"] is True, "sys.bye lost"
                assert pongs_from(hub, "engine") == list(range(1, FLOOD_PINGS + 1))
        finally:
            storage.close()


# --- patch schema (PROTOCOL 4.2) -----------------------------------------------------------------

def test_patch_with_a_stale_base_revision_is_a_conflict_with_the_current_state(pipe, flowdir, engine):
    with subscribe_flow(pipe, "skeleton") as obs:
        wait_ready(obs)
        answer = obs.request("engine", "cmd.flow.patch", {"flowId": "skeleton", "baseRev": 0, "ops": []}, timeout=5)
        payload = answer["payload"]
        assert not payload["ok"] and payload["error"]["code"] == "conflict"
        assert payload["rev"] == 1 and payload["definition"]["name"] == "Skeleton"


def test_patch_with_the_current_revision_and_no_operations_changes_nothing(pipe, flowdir, engine):
    with subscribe_flow(pipe, "skeleton") as obs:
        wait_ready(obs)
        answer = ask(obs, "cmd.flow.patch", {"flowId": "skeleton", "baseRev": 1, "ops": []})
        assert answer["ok"] and answer["rev"] == 1
        assert ask(obs, "cmd.engine.snapshot")["flows"][0]["rev"] == 1


def test_patch_operations_are_validated_and_refused_until_phase_3(pipe, flowdir, engine):
    cases = [
        ({"flowId": "skeleton", "baseRev": 1, "ops": [{"op": "element.add"}]}, "not applied before phase 3"),
        ({"flowId": "skeleton", "baseRev": 1, "ops": [{"op": "no.such.op"}]}, "unknown patch operation"),
        ({"flowId": "skeleton", "baseRev": 1, "ops": [{"x": 1}]}, "needs an 'op' field"),
        ({"flowId": "skeleton", "baseRev": 1, "ops": "nope"}, "must be an array"),
        ({"flowId": "skeleton", "ops": []}, "baseRev"),
        ({"flowId": "nope", "baseRev": 1, "ops": []}, None),
    ]
    with subscribe_flow(pipe, "skeleton") as obs:
        wait_ready(obs)
        for payload, text in cases:
            error = obs.request("engine", "cmd.flow.patch", payload, timeout=5)["payload"]["error"]
            assert error["code"] in ("bad_payload", "not_found"), error
            if text is not None:
                assert text in error["message"], error
        assert ask(obs, "cmd.engine.snapshot")["flows"][0]["rev"] == 1
