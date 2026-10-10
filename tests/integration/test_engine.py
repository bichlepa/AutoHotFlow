"""WI-10: engine role (src/engine/).

The engine runs as a real process (src/AutoHotFlow.ahk --role=engine, started through tools/ahkrun.py).
Its hub is the Python stand-in tests/support/pyhub.py (WakingHub, see test_peer.py). Its storage is a
Python stand-in as well (StorageStub below, same protocol as WI-12 will implement), so the engine can be
tested before the storage role exists. Observers are AhfClient instances that subscribe to topics.
"""

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
