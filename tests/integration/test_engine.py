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
from test_role import RoleHub, RoleRun

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
                self._handle(msg)

    def _handle(self, msg):
        type_ = msg.get("type")
        payload = msg.get("payload", {})
        if type_ == "cmd.storage.flows.list":
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
    args = ["--role=engine", "--session=" + session_id, "--hub=" + pipe, "--data=" + str(datadir)]
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
        assert not flow["enabled"] and not flow["executing"]   # booleans arrive as 0/1 (PROTOCOL 2)
        assert snap["settings"] == {}

        hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})
        assert run.wait_exit(timeout=10) == 0, run.stderr_text()


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
        assert elapsed < 0.5, "instance ended %.3f s after the stop" % elapsed
        assert got[-1][1]["payload"]["reason"] == "flow.stop"
        assert element_states(got) == [(SLEEP, "finished", 0, None)]
        quiet = list(obs.events(timeout=0.4))
        assert not [m for m in quiet if m["type"] == "evt.element.state"], "no further element may run"
        snap = ask(obs, "cmd.engine.snapshot")
        assert not [f for f in snap["flows"] if f["flowId"] == "slow"][0]["executing"]


def test_element_exception_is_reported_and_the_engine_keeps_running(pipe, flowdir, engine):
    make_flow(flowdir, "throw", element_class="Action_TestThrow")
    with subscribe_flow(pipe, "throw") as obs:
        wait_ready(obs)
        ask(obs, "cmd.flow.start", {"flowId": "throw"})
        got = collect_until(obs, is_type("evt.instance.ended"), timeout=10)
        assert element_states(got) == [(TRIGGER, "running", 1, None), (TRIGGER, "finished", 0, None),
                                       (SLEEP, "running", 1, None), (SLEEP, "exception", 0, "test")]
        assert got[-1][1]["payload"]["reason"] == "exception"
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
        assert state["enabled"] == 1 and state["executing"] == 0
        assert ask(obs, "cmd.engine.snapshot")["flows"][0]["enabled"] == 1
        ask(obs, "cmd.flow.disable", {"flowId": "skeleton"})
        assert obs.wait_event("evt.flow.state", timeout=5)["payload"]["enabled"] == 0


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


def test_wait_policy_is_refused_with_busy_until_it_is_implemented(pipe, flowdir, engine):
    make_flow(flowdir, "pol", sleep_ms=5000, policy="wait")
    with subscribe_flow(pipe, "pol") as obs:
        wait_ready(obs)
        ask(obs, "cmd.flow.start", {"flowId": "pol"})
        refused = obs.request("engine", "cmd.flow.start", {"flowId": "pol"}, timeout=5)
        assert refused["payload"]["error"]["code"] == "busy"
        stop_flow(obs, "pol")


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
        assert ask(obs, "cmd.engine.snapshot")["flows"][0]["executing"] == 1
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
        assert elapsed < 2.0, "shutdown took %.3f s" % elapsed


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
