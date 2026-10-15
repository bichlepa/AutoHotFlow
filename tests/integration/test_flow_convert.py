"""WI-0039: conversion of the expression texts of old flows when the engine loads them (end to end).

The engine runs as a real process with the stand-in hub and a stand-in storage (see test_engine.py). A v1 flow with
the test element Action_TestExprParams and an element of a class that does not exist yet is loaded, converted,
saved (cmd.flow.save), loaded again by a second engine: nothing is converted twice, and the element with the unknown
class keeps its v1 texts and gets a marker. The same flow is also converted when a class becomes known later (unit
test tests/ahk/engine_flow_convert.test.ahk).
"""

import json

import pytest

from test_engine import (StorageStub, ask, observer, pipe, runs, hub, wait_for, wait_ready,  # noqa: F401 (fixtures)
                         start_engine)

# the pars of the test element: texts as v1 wrote them
V1_PARS = {
    "Expr": "x := 1.50", "Num": "1.10", "PosInt": "007", "Either": "1.50", "EitherType": "expression",
    "Text": "1.50 %v%", "VarName": "v1.50", "Raw": "1.50", "Script": "a := 1.50\nb := 2",
    "Condition": 'x = 1.50 and "a"."b"',
}
V1_FLOW = {
    "name": "Conv", "category": "Tests", "ElementIDCounter": "3",
    "flowSettings": {"ExecutionPolicy": "default"},
    "allElements": {
        "element0000000001": {"ID": "element0000000001", "type": "trigger", "class": "Trigger_Manual", "x": "0", "y": "0",
                              "enabled": "0", "pars": {"ID": "Conv"}, "name": "Manual", "StandardName": "1"},
        "element0000000002": {"ID": "element0000000002", "type": "action", "class": "Action_TestExprParams", "x": "0",
                              "y": "100", "pars": V1_PARS, "name": "Test", "StandardName": "1"},
        "element0000000003": {"ID": "element0000000003", "type": "action", "class": "Action_NotYetPorted", "x": "0",
                              "y": "200", "pars": {"Expr": "1.50", "Other": '"a"."b"'}, "name": "Later",
                              "StandardName": "1"},
    },
    "allConnections": {
        "connection0000000004": {"ID": "connection0000000004", "type": "connection", "ConnectionType": "normal",
                                 "from": "element0000000001", "to": "element0000000002"},
    },
}
CONVERTED_PARS = {
    "Expr": 'x := "1.50"', "Num": '"1.10"', "PosInt": '"007"', "Either": '"1.50"', "EitherType": "expression",
    "Text": "1.50 %v%", "VarName": "v1.50", "Raw": "1.50", "Script": 'a := "1.50"\nb := 2',
    "Condition": 'x = 1.50 and "a" . "b"',
}


class WritingStorageStub(StorageStub):
    """Also answers cmd.storage.flow.write: writes the file and keeps the request."""

    def __init__(self, pipe, datadir):
        super().__init__(pipe, datadir)
        self.writes = []

    def _handle(self, msg):
        if msg.get("type") == "cmd.storage.flow.write":
            payload = msg["payload"]
            self.writes.append(payload)
            (self.datadir / payload["path"]).write_text(payload["text"], encoding="utf-8", newline="")
            self.client.reply(msg, {"ok": True})
            return
        super()._handle(msg)


@pytest.fixture
def flowdir(datadir):
    (datadir / "Flows").mkdir()
    (datadir / "Flows" / "conv.json").write_text(json.dumps(V1_FLOW, indent=2), encoding="utf-8")
    return datadir


@pytest.fixture
def storage(hub, pipe, flowdir):
    stub = WritingStorageStub(pipe, flowdir).start()
    yield stub
    stub.close()


def load_and_get(procs, flowdir, runs, session_id, pipe, hub, label):
    """Starts an engine, waits until it is ready and returns (run, observer, definition of the flow)."""
    obs = observer(pipe, "engine")
    run = start_engine(procs, flowdir, runs, pipe, session_id, label=label)
    wait_ready(obs)
    got = ask(obs, "cmd.flow.get", {"flowId": "conv"})
    return run, obs, got["definition"]


def stop(hub, run):
    hub.send_to("engine", "sys.shutdown", {"reason": "user", "deadlineMs": 1000})
    assert run.wait_exit(timeout=10) == 0, run.stderr_text()


def conversion_logs(storage):
    return [p["text"] for p in storage.logs if p.get("level") == "f2" and "parameter" in p.get("text", "")]


def test_a_v1_flow_is_converted_saved_and_loaded_again_without_double_conversion(
        procs, flowdir, runs, session_id, pipe, hub, storage):
    # --- first engine: the v1 file is loaded and converted
    run, obs, definition = load_and_get(procs, flowdir, runs, session_id, pipe, hub, "engine1")
    with obs:
        pars = definition["allElements"]["element0000000002"]["pars"]
        assert pars == CONVERTED_PARS
        # the element of the unknown class keeps its v1 texts
        later = definition["allElements"]["element0000000003"]["pars"]
        assert later == {"Expr": "1.50", "Other": '"a"."b"'}
        # no marker and no format version in the definition that clients get
        assert "formatVersion" not in definition
        assert "v1Text" not in definition["allElements"]["element0000000003"]

        # every conversion is in the log with flow, element, parameter, old and new text
        assert wait_for(lambda: len(conversion_logs(storage)) == 6), conversion_logs(storage)
        logs = conversion_logs(storage)
        assert any("element 'element0000000002' parameter 'Expr': 'x := 1.50' -> 'x := \"1.50\"'" in t for t in logs)
        assert any(p.get("flowId") == "conv" for p in storage.logs if p.get("level") == "f2")

        # --- save: the file has the format version, converted texts, and the marker of the waiting element
        saved = ask(obs, "cmd.flow.save", {"flowId": "conv"})
        assert saved["savedRev"] == 1
        assert len(storage.writes) == 1 and storage.writes[0]["path"] == "Flows/conv.json"
        assert storage.writes[0]["backup"] is True
        on_disk = json.loads((flowdir / "Flows" / "conv.json").read_text(encoding="utf-8"))
        assert on_disk["formatVersion"] == 2
        assert on_disk["allElements"]["element0000000002"]["pars"] == CONVERTED_PARS
        assert "v1Text" not in on_disk["allElements"]["element0000000002"]
        assert on_disk["allElements"]["element0000000003"]["v1Text"] is True
        assert on_disk["allElements"]["element0000000003"]["pars"] == {"Expr": "1.50", "Other": '"a"."b"'}
        first_file = (flowdir / "Flows" / "conv.json").read_text(encoding="utf-8")
    stop(hub, run)

    # --- second engine: nothing is converted twice
    storage.logs.clear()
    run2, obs2, definition2 = load_and_get(procs, flowdir, runs, session_id, pipe, hub, "engine2")
    with obs2:
        assert definition2["allElements"]["element0000000002"]["pars"] == CONVERTED_PARS
        assert definition2["allElements"]["element0000000003"]["pars"] == {"Expr": "1.50", "Other": '"a"."b"'}
        assert wait_for(lambda: any("expression texts:" in p.get("text", "") for p in storage.logs))
        assert conversion_logs(storage) == []
        # saving again writes the same file: idempotent
        ask(obs2, "cmd.flow.save", {"flowId": "conv"})
        assert (flowdir / "Flows" / "conv.json").read_text(encoding="utf-8") == first_file
    stop(hub, run2)


def test_the_saved_file_answers_with_an_error_when_storage_cannot_write(procs, flowdir, runs, session_id, pipe, hub):
    class FailingStub(WritingStorageStub):
        def _handle(self, msg):
            if msg.get("type") == "cmd.storage.flow.write":
                self.client.reply(msg, {"ok": False, "error": {"code": "internal", "message": "disk full"}})
                return
            StorageStub._handle(self, msg)

    stub = FailingStub(pipe, flowdir).start()
    try:
        run, obs, _ = load_and_get(procs, flowdir, runs, session_id, pipe, hub, "engine")
        with obs:
            answer = obs.request("engine", "cmd.flow.save", {"flowId": "conv"}, timeout=5)
            assert answer["payload"]["ok"] is False
            assert answer["payload"]["error"]["code"] == "internal"
            unknown = obs.request("engine", "cmd.flow.save", {"flowId": "nope"}, timeout=5)
            assert unknown["payload"]["ok"] is False and unknown["payload"]["error"]["code"] == "not_found"
        stop(hub, run)
    finally:
        stub.close()
