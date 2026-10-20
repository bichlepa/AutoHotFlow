"""WI-0093: cmd.flow.patch in the engine (PROTOCOL 4.2, ARCHITECTURE 4.2): commit, conflict, a refused list, the busy
state of a deletion, a running instance that follows a connection added during its run (E0001), a removed next element
(M-0017, the running case), and the meta race (a patch committed while storage writes a rename is kept).

The engine runs as in test_engine.py (a real process, a Python stand-in for storage). The fixtures and helpers are
imported from there. Flows that a test needs are written before the engine starts (fixture `slow_flows`).
"""

import json
import threading
import time

import pytest

from support.ahfclient import AhfClient
from test_engine import (DONE, SLEEP, StorageStub, ask, collect_until, element_states, engine, flowdir,  # noqa: F401
                         hub, is_type, make_flow, observer, pipe, runs, subscribe_flow, wait_ready)

FLOW = "skeleton"
NEW_ELEMENT = "element0000000010"       # the skeleton's ElementIDCounter is 4: the numbers above it are free
NEW_CONNECTION = "connection0000000011"


class HoldingStorage(StorageStub):
    """StorageStub that writes flows and keeps their cmd.storage.flow.write requests while `hold` is set (the meta race).
    Held requests are written and answered by release_write()."""

    def __init__(self, pipe, datadir):
        super().__init__(pipe, datadir)
        self.hold = False
        self.held_writes = []

    def _handle(self, msg):
        if msg.get("type") != "cmd.storage.flow.write":
            return super()._handle(msg)
        if self.hold:
            self.held_writes.append(msg)
            return
        self._write(msg)

    def _write(self, msg):
        target = self.datadir / msg["payload"]["path"]
        target.write_text(msg["payload"]["text"], encoding="utf-8")
        self.client.reply(msg, {"ok": True})

    def release_write(self):
        self._write(self.held_writes.pop(0))


@pytest.fixture
def storage(hub, pipe, flowdir):
    stub = HoldingStorage(pipe, flowdir).start()
    yield stub
    stub.close()


@pytest.fixture
def slow_flows(flowdir):
    """Two copies of the skeleton whose Action_Sleep runs for a second: the runs of the tests stay in the sleep."""
    make_flow(flowdir, "live", sleep_ms=1000)
    make_flow(flowdir, "gone", sleep_ms=1000)


def patch(obs, base, ops, flow=FLOW):
    return obs.request("engine", "cmd.flow.patch", {"flowId": flow, "baseRev": base, "ops": ops}, timeout=5)["payload"]


def definition(obs, flow=FLOW):
    return ask(obs, "cmd.flow.get", {"flowId": flow})["definition"]


def rev_of(obs, flow=FLOW):
    for f in ask(obs, "cmd.engine.snapshot")["flows"]:
        if f["flowId"] == flow:
            return f["rev"]
    return None


def move(element_id, x):
    return {"op": "element.update", "id": element_id, "fields": {"x": x}}


def wait_until_sleeping(obs):
    collect_until(obs, lambda m: m["type"] == "evt.element.state" and m["payload"]["elementId"] == SLEEP
                  and m["payload"]["state"] == "running")


# --- commit, conflict, refusal ---------------------------------------------------------------------------------------

def test_a_patch_commits_a_new_revision_at_once_and_the_file_waits_for_a_save(pipe, flowdir, engine):
    with subscribe_flow(pipe, FLOW) as obs:
        wait_ready(obs)
        answer = obs.request("engine", "cmd.flow.patch", {"flowId": FLOW, "baseRev": 1, "ops": [move(SLEEP, 77)]},
                             timeout=5)
        assert answer["payload"]["ok"] is True and answer["payload"]["rev"] == 2, answer
        committed = collect_until(obs, is_type("evt.flow.committed"), timeout=5)[-1][1]["payload"]
        assert committed["flowId"] == FLOW and committed["rev"] == 2 and committed["byMeta"] is False, committed
        assert definition(obs)["allElements"][SLEEP]["x"] == 77
        assert rev_of(obs) == 2
    on_disk = json.loads((flowdir / "Flows" / (FLOW + ".json")).read_text(encoding="utf-8"))
    assert on_disk["allElements"][SLEEP]["x"] != 77, "a patch is not written before cmd.flow.save"


def test_a_second_patch_on_the_old_revision_is_a_conflict_and_changes_nothing(pipe, flowdir, engine):
    with subscribe_flow(pipe, FLOW) as obs:
        wait_ready(obs)
        assert patch(obs, 1, [move(SLEEP, 10)])["ok"] is True
        answer = patch(obs, 1, [move(SLEEP, 20)])
        assert answer["ok"] is False and answer["error"]["code"] == "conflict", answer
        assert answer["rev"] == 2 and answer["definition"]["allElements"][SLEEP]["x"] == 10
        assert definition(obs)["allElements"][SLEEP]["x"] == 10


def test_a_refused_operation_refuses_the_whole_list(pipe, flowdir, engine):
    with subscribe_flow(pipe, FLOW) as obs:
        wait_ready(obs)
        before = definition(obs)
        ops = [move(SLEEP, 55),
               {"op": "connection.add", "connection": {"ID": NEW_CONNECTION, "from": SLEEP, "to": SLEEP,
                                                      "ConnectionType": "normal"}}]
        answer = patch(obs, 1, ops)
        assert answer["ok"] is False and answer["error"]["code"] == "bad_payload", answer
        assert NEW_CONNECTION in answer["error"]["message"] and "itself" in answer["error"]["message"], answer
        assert rev_of(obs) == 1
        assert definition(obs) == before


def test_a_new_element_and_its_connection_raise_the_counter(pipe, flowdir, engine):
    new_element = {"ID": NEW_ELEMENT, "type": "action", "class": "Action_Do_nothing", "package": "Default",
                   "packageVersion": "1.2.0", "name": "Added", "x": "0", "y": "630", "StandardName": "1", "pars": {}}
    ops = [{"op": "element.add", "element": new_element},
           {"op": "connection.add", "connection": {"ID": NEW_CONNECTION, "from": SLEEP, "to": NEW_ELEMENT,
                                                  "ConnectionType": "normal", "type": "Connection"}}]
    with subscribe_flow(pipe, FLOW) as obs:
        wait_ready(obs)
        assert patch(obs, 1, ops)["rev"] == 2
        after = definition(obs)
        assert after["allElements"][NEW_ELEMENT]["name"] == "Added"
        assert after["allConnections"][NEW_CONNECTION]["to"] == NEW_ELEMENT
        assert after["ElementIDCounter"] == "12", "the connection number 11 raises the counter to 12"
        again = patch(obs, 2, [{"op": "element.add", "element": new_element}])
        assert again["ok"] is False and again["error"]["code"] == "bad_payload"
        assert "exists already" in again["error"]["message"], again


def test_a_patch_of_a_flow_whose_deletion_is_pending_is_busy(pipe, flowdir, engine):
    with subscribe_flow(pipe, FLOW) as obs:
        wait_ready(obs)
        obs.send("engine", "cmd.flow.delete", {"flowId": FLOW})
        answer = patch(obs, 1, [move(SLEEP, 5)])
        assert answer["ok"] is False and answer["error"]["code"] == "busy", answer


# --- changes during a run (E0001, M-0017) ----------------------------------------------------------------------------

def test_a_running_instance_follows_a_connection_added_during_its_run(pipe, flowdir, slow_flows, engine):
    with subscribe_flow(pipe, "live") as obs:
        wait_ready(obs)
        ask(obs, "cmd.flow.start", {"flowId": "live"})
        wait_until_sleeping(obs)
        ops = [{"op": "element.add", "element": {"ID": NEW_ELEMENT, "type": "action", "class": "Action_Do_nothing",
                                                 "package": "Default", "name": "Added", "pars": {}}},
               {"op": "connection.add", "connection": {"ID": NEW_CONNECTION, "from": SLEEP, "to": NEW_ELEMENT,
                                                      "ConnectionType": "normal"}}]
        assert patch(obs, 1, ops, flow="live")["ok"] is True
        got = collect_until(obs, is_type("evt.instance.ended"), timeout=10)
    states = element_states(got)
    assert (NEW_ELEMENT, "finished", 0, None) in states, states
    assert got[-1][1]["payload"]["reason"] == "finished"


def test_a_removed_next_element_is_not_run_and_the_running_element_ends_normally(pipe, flowdir, slow_flows, engine):
    with subscribe_flow(pipe, "gone") as obs:
        wait_ready(obs)
        ask(obs, "cmd.flow.start", {"flowId": "gone"})
        wait_until_sleeping(obs)
        assert patch(obs, 1, [{"op": "element.remove", "id": DONE}], flow="gone")["ok"] is True
        got = collect_until(obs, is_type("evt.instance.ended"), timeout=10)
    states = element_states(got)
    assert (SLEEP, "finished", 0, None) in states, states
    assert not [s for s in states if s[0] == DONE], "the removed element must not run"
    assert got[-1][1]["payload"]["reason"] == "finished"


# --- the meta race (ARCHITECTURE 4.2) ---------------------------------------------------------------------------------

def test_a_patch_committed_while_storage_writes_a_rename_is_kept(pipe, flowdir, storage, engine):
    with subscribe_flow(pipe, FLOW) as obs:
        wait_ready(obs)
        storage.hold = True
        meta_client = AhfClient(pipe, "meta")
        answer = {}

        def rename():
            answer["reply"] = meta_client.request("engine", "cmd.flow.meta.update", {"flowId": FLOW, "name": "Renamed"},
                                                  timeout=10)["payload"]

        worker = threading.Thread(target=rename)
        worker.start()
        deadline = time.monotonic() + 10
        while not storage.held_writes and time.monotonic() < deadline:
            time.sleep(0.02)
        assert storage.held_writes, "the rename did not reach storage"
        # The rename waits for storage; a patch is not busy for it, and it is committed on top of the revision 1 patch.
        assert patch(obs, 1, [move(SLEEP, 77)])["rev"] == 2
        storage.hold = False
        storage.release_write()
        worker.join(timeout=10)
        meta_client.close()
        assert answer["reply"]["ok"] is True and answer["reply"]["rev"] == 3, answer
        current = definition(obs)
        assert current["name"] == "Renamed"
        assert current["allElements"][SLEEP]["x"] == 77, "the patch committed during the rename is kept"
        assert rev_of(obs) == 3
