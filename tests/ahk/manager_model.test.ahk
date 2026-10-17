#Requires AutoHotkey v2.0
; Unit tests for src/manager/ManagerModel.ahk (WI-0073): the resync rules (epoch, gap, duplicate, stale answer, one snapshot
; in flight), the connection state, the events that change a flow, the commands and the buttons by selection. The peer is
; a fake that records the requests; no window and no process is involved.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\core\Log.ahk
#Include ..\..\src\manager\ManagerModel.ahk

Log.Configure(Log.Memory)

; The peer of the model: records requests and subscriptions; the test answers them by hand.
class FakePeer {
    __New() {
        this.requests := []
        this.topics := []
        this.failNext := false
    }

    Subscribe(topic) {
        this.topics.Push(topic)
    }

    Request(to, type, payload, callback, timeoutMs := 5000) {
        if (this.failNext) {
            this.failNext := false
            throw Error("not connected")
        }
        this.requests.Push(Map("to", to, "type", type, "payload", payload, "cb", callback, "ms", timeoutMs))
    }

    ; Answers the oldest open request with the payload.
    Answer(payload) {
        req := this.requests.RemoveAt(1)
        req["cb"](FakeAnswer(payload))
        return req
    }

    Count(type) {
        n := 0
        for req in this.requests {
            if (req["type"] = type)
                n += 1
        }
        return n
    }
}

class FakeAnswer {
    __New(payload) {
        this.payload := payload
    }
}

Snap(epoch, seq, flowIds, ready := 1) {
    flows := []
    for id in flowIds
        flows.Push(Map("flowId", id, "name", "Name " id, "category", "", "enabled", 0, "executing", 0, "rev", 1
            , "independentActive", 0, "triggers", []))
    return Map("ok", 1, "epoch", epoch, "seq", seq, "flows", flows
        , "categories", [Map("name", "Work", "flows", []), Map("name", "", "flows", flowIds)], "settings", Map(), "ready", ready)
}

Evt(epoch, seq, extra := "") {
    p := Map("epoch", epoch, "seq", seq)
    if (IsObject(extra)) {
        for k, v in extra
            p[k] := v
    }
    return p
}

NewModel() {
    peer := FakePeer()
    model := ManagerModel(peer)
    model.Start()
    return [peer, model]
}

; A model that has taken its first snapshot (epoch 100, seq 10, flows A and B).
ReadyModel() {
    pm := NewModel()
    pm[1].Answer(Snap(100, 10, ["A", "B"]))
    return pm
}

TestRun.Init()

TestRun.Case("Start subscribes to engine and process and asks for one snapshot", () => CheckStart())
CheckStart() {
    pm := NewModel()
    Assert.Equal(pm[1].topics.Length, 2)
    Assert.Equal(pm[1].requests.Length, 1)
    Assert.Equal(pm[1].requests[1]["type"], "cmd.engine.snapshot")
    Assert.Equal(pm[1].requests[1]["ms"], ManagerModel.SNAPSHOT_MS)
    Assert.Equal(pm[2].engineState, ManagerModel.ENGINE_WAITING)
}

TestRun.Case("A snapshot fills the flows and the categories and subscribes to each flow", () => CheckSnapshot())
CheckSnapshot() {
    pm := ReadyModel()
    m := pm[2]
    Assert.Equal(m.flowIds.Length, 2)
    Assert.Equal(m.Flow("A")["name"], "Name A")
    Assert.Equal(m.categories.Length, 2)
    Assert.Equal(m.engineState, ManagerModel.ENGINE_READY)
    Assert.Equal(m.epoch, 100)
    Assert.Equal(m.lastSeq, 10)
    Assert.True(HasValue(pm[1].topics, "flow:A") && HasValue(pm[1].topics, "flow:B"))
    Assert.Equal(m.OrderedFlowIds()[2], "B")
}

TestRun.Case("A snapshot with ready 0 is the state loading", () => CheckLoading())
CheckLoading() {
    pm := NewModel()
    pm[1].Answer(Snap(100, 1, ["A"], 0))
    Assert.Equal(pm[2].engineState, ManagerModel.ENGINE_LOADING)
}

TestRun.Case("Events that come while a snapshot is out cost one more request, not one each", () => CheckCoalesce())
CheckCoalesce() {
    pm := NewModel()
    m := pm[2]
    loop 5
        m.OnEvent("evt.flow.list.changed", Evt(100, A_Index, Map("added", ["A"])))
    Assert.Equal(pm[1].requests.Length, 1, "still the first request only")
    pm[1].Answer(Snap(100, 5, ["A"]))
    Assert.Equal(pm[1].requests.Length, 1, "one request for the reasons that came meanwhile")
    pm[1].Answer(Snap(100, 5, ["A"]))
    Assert.Equal(pm[1].requests.Length, 0)
    Assert.Equal(m.snapshotCount, 2)
}

TestRun.Case("A gap in seq, a new epoch and a list change ask for a snapshot; an in-order event does not", () => CheckTriggers())
CheckTriggers() {
    pm := ReadyModel()
    m := pm[2]
    m.OnEvent("evt.flow.state", Evt(100, 11, Map("flowId", "A", "enabled", 1, "executing", 0)))
    Assert.Equal(pm[1].requests.Length, 0, "in order")
    m.OnEvent("evt.flow.state", Evt(100, 13, Map("flowId", "A", "enabled", 1, "executing", 0)))
    Assert.Equal(pm[1].requests.Length, 1, "gap")
    pm[1].Answer(Snap(100, 13, ["A", "B"]))
    m.OnEvent("evt.flow.state", Evt(200, 1, Map("flowId", "A", "enabled", 1, "executing", 0)))
    Assert.Equal(pm[1].requests.Length, 1, "new epoch")
    pm[1].Answer(Snap(200, 1, ["A", "B"]))
    m.OnEvent("evt.flow.list.changed", Evt(200, 2, Map("added", ["C"])))
    Assert.Equal(pm[1].requests.Length, 1, "list changed")
}

TestRun.Case("A duplicate event is discarded", () => CheckDuplicate())
CheckDuplicate() {
    pm := ReadyModel()
    m := pm[2]
    m.OnEvent("evt.flow.state", Evt(100, 11, Map("flowId", "A", "enabled", 1, "executing", 1)))
    m.OnEvent("evt.flow.state", Evt(100, 11, Map("flowId", "A", "enabled", 0, "executing", 0)))
    Assert.Equal(m.Flow("A")["enabled"], 1)
    Assert.Equal(m.Flow("A")["executing"], 1)
}

TestRun.Case("A snapshot older than an event already seen is asked for again", () => CheckStale())
CheckStale() {
    pm := ReadyModel()
    m := pm[2]
    m.RequestSnapshot("test")
    m.OnEvent("evt.flow.state", Evt(100, 11, Map("flowId", "A", "enabled", 1, "executing", 1)))
    pm[1].Answer(Snap(100, 10, ["A", "B"]))          ; older than seq 11
    Assert.Equal(m.Flow("A")["executing"], 1, "the old answer did not undo the event")
    Assert.Equal(pm[1].requests.Length, 1)
    Assert.Equal(pm[1].requests[1]["type"], "cmd.engine.snapshot")
}

TestRun.Case("A snapshot of an old epoch that arrives after an event of the new epoch is discarded", () => CheckOldEpoch())
CheckOldEpoch() {
    pm := ReadyModel()
    m := pm[2]
    m.RequestSnapshot("test")                         ; asked in the old epoch (100)
    m.OnEvent("evt.flow.state", Evt(200, 1, Map("flowId", "A", "enabled", 1, "executing", 1)))   ; the engine restarted
    pm[1].Answer(Snap(100, 12, ["A", "B"]))           ; the old answer arrives late
    Assert.Equal(m.epoch, 200, "the epoch was not set back")
    Assert.Equal(m.lastSeq, 1, "the seq was not set back")
    Assert.Equal(m.snapshotCount, 1, "the old answer was not taken")
    Assert.True(pm[1].requests.Length >= 1, "asked again")
    pm[1].Answer(Snap(200, 2, ["A"]))
    Assert.Equal(m.epoch, 200)
    Assert.Equal(m.flowIds.Length, 1)
}

TestRun.Case("flow.state sets the state of the flow and stateError comes and goes", () => CheckFlowState())
CheckFlowState() {
    pm := ReadyModel()
    m := pm[2]
    seen := []
    m.AddListener((kind, data) => seen.Push(kind))
    m.OnEvent("evt.flow.state", Evt(100, 11, Map("flowId", "B", "enabled", 1, "executing", 0, "independentActive", 2
        , "stateError", "cannot read")))
    rec := m.Flow("B")
    Assert.Equal(rec["independentActive"], 2)
    Assert.Equal(rec["stateError"], "cannot read")
    m.OnEvent("evt.flow.state", Evt(100, 12, Map("flowId", "B", "enabled", 1, "executing", 0)))
    Assert.Equal(m.Flow("B")["stateError"], "")
    Assert.Equal(seen.Length, 2)
    Assert.Equal(seen[1], "flow")
}

TestRun.Case("flow.state of an unknown flow asks for a snapshot", () => CheckUnknownFlow())
CheckUnknownFlow() {
    pm := ReadyModel()
    pm[2].OnEvent("evt.flow.state", Evt(100, 11, Map("flowId", "Z", "enabled", 1, "executing", 0)))
    Assert.Equal(pm[1].requests.Length, 1)
}

TestRun.Case("trigger.state and category.changed update the model", () => CheckTriggerAndCategory())
CheckTriggerAndCategory() {
    pm := ReadyModel()
    m := pm[2]
    m.OnEvent("evt.trigger.state", Evt(100, 11, Map("flowId", "A", "elementId", "t1", "enabled", 1, "armed", 1, "message", "")))
    Assert.Equal(m.Flow("A")["triggers"].Length, 1)
    m.OnEvent("evt.trigger.state", Evt(100, 12, Map("flowId", "A", "elementId", "t1", "enabled", 0, "armed", 0, "message", "x")))
    Assert.Equal(m.Flow("A")["triggers"].Length, 1)
    Assert.Equal(m.Flow("A")["triggers"][1]["message"], "x")
    m.OnEvent("evt.category.changed", Evt(100, 13, Map("categories", [Map("name", "", "flows", ["B", "A"])])))
    Assert.Equal(m.OrderedFlowIds()[1], "B")
}

TestRun.Case("The engine going down and coming back: state down, then a snapshot", () => CheckEngineDown())
CheckEngineDown() {
    pm := ReadyModel()
    m := pm[2]
    states := []
    m.AddListener((kind, data) => (kind = "engine" ? states.Push(data) : 0))
    m.OnEvent("evt.process.crashed", Map("name", "engine", "pid", 5, "restart", 1))
    Assert.Equal(m.engineState, ManagerModel.ENGINE_DOWN)
    Assert.Equal(pm[1].requests.Length, 0)
    m.OnEvent("evt.process.crashed", Map("name", "storage", "pid", 6))
    m.OnEvent("evt.process.restarted", Map("name", "engine", "attempt", 1))
    Assert.Equal(pm[1].requests.Length, 1)
    pm[1].Answer(Snap(300, 1, ["A"], 0))
    Assert.Equal(m.engineState, ManagerModel.ENGINE_LOADING)
    Assert.Equal(m.flowIds.Length, 1)
    Assert.Equal(states[1], ManagerModel.ENGINE_DOWN)
}

TestRun.Case("A failed snapshot changes no flow and sets the state down; a later event asks again", () => CheckFailedSnapshot())
CheckFailedSnapshot() {
    pm := ReadyModel()
    m := pm[2]
    m.RequestSnapshot("test")
    pm[1].Answer(Map("ok", 0, "error", Map("code", "not_found", "message", "no peer")))
    Assert.Equal(m.engineState, ManagerModel.ENGINE_DOWN)
    Assert.Equal(m.flowIds.Length, 2)
    m.OnEvent("evt.engine.ready", Evt(400, 1))
    Assert.Equal(pm[1].requests.Length, 1)
}

TestRun.Case("A request that cannot be sent leaves no open snapshot", () => CheckThrowingPeer())
CheckThrowingPeer() {
    peer := FakePeer()
    peer.failNext := true
    m := ManagerModel(peer)
    m.Start()
    Assert.True(!m.snapshotOut)
    Assert.Equal(m.engineState, ManagerModel.ENGINE_DOWN)
    m.OnEvent("evt.engine.ready", Evt(1, 1))
    Assert.Equal(peer.requests.Length, 1)
}

TestRun.Case("Command: the answer reaches the listeners and the callback, with the code of an error", () => CheckCommand())
CheckCommand() {
    pm := ReadyModel()
    m := pm[2]
    got := []
    m.AddListener((kind, data) => (kind = "answer" ? got.Push(data) : 0))
    done := []
    m.Command("cmd.flow.start", Map("flowId", "A"), (ans) => done.Push(ans))
    Assert.Equal(pm[1].requests[1]["ms"], ManagerModel.COMMAND_MS)
    pm[1].Answer(Map("ok", 1, "instanceId", "i1"))
    m.Command("cmd.flow.start", Map("flowId", "B"), (ans) => done.Push(ans))
    pm[1].Answer(Map("ok", 0, "error", Map("code", "busy", "message", "flow is busy")))
    Assert.Equal(got.Length, 2)
    Assert.True(got[1]["ok"])
    Assert.True(!got[2]["ok"])
    Assert.Equal(got[2]["code"], "busy")
    Assert.Equal(got[2]["message"], "flow is busy")
    Assert.Equal(done.Length, 2)
    Assert.Equal(m.lastAnswer["code"], "busy")
}

TestRun.Case("Command: a request that cannot be sent is an answer with not_sent", () => CheckCommandNotSent())
CheckCommandNotSent() {
    pm := ReadyModel()
    pm[1].failNext := true
    got := []
    pm[2].Command("cmd.flow.stop", Map("flowId", "A"), (ans) => got.Push(ans))
    Assert.Equal(got.Length, 1)
    Assert.Equal(got[1]["code"], "not_sent")
}

TestRun.Case("RunOrStop starts a flow that is idle and stops one that runs; without a selection it is an error", () => CheckRun())
CheckRun() {
    pm := ReadyModel()
    m := pm[2]
    got := []
    m.RunOrStop("", (ans) => got.Push(ans))
    Assert.Equal(got[1]["code"], "not_found")
    m.Select("A")
    m.RunOrStop()
    Assert.Equal(pm[1].requests[1]["type"], "cmd.flow.start")
    pm[1].Answer(Map("ok", 1))
    m.OnEvent("evt.flow.state", Evt(100, 11, Map("flowId", "A", "enabled", 0, "executing", 1)))
    Assert.True(m.RunIsStop())
    m.RunOrStop()
    Assert.Equal(pm[1].requests[1]["type"], "cmd.flow.stop")
}

TestRun.Case("The buttons follow the selection; selecting an unknown flow clears it", () => CheckButtons())
CheckButtons() {
    pm := ReadyModel()
    m := pm[2]
    Assert.True(!m.ButtonStates()["Run"])
    Assert.True(m.ButtonStates()["Exit"])
    m.Select("A")
    Assert.True(m.ButtonStates()["Run"])
    m.Select("Nope")
    Assert.Equal(m.selectedFlow, "")
    m.Select("B")
    ; a snapshot without the selected flow clears the selection
    m.RequestSnapshot("test")
    pm[1].Answer(Snap(100, 20, ["A"]))
    Assert.Equal(m.selectedFlow, "")
}

TestRun.Case("The trace keeps the newest entries and returns those after a number", () => CheckTrace())
CheckTrace() {
    peer := FakePeer()
    m := ManagerModel(peer)
    m.TraceOn()
    m.Note("a")
    m.Note("b")
    m.Note("c")
    Assert.Equal(m.Trace(1).Length, 2)
    Assert.Equal(m.Trace(1)[1]["type"], "b")
    Assert.Equal(m.traceCount, 3)
    off := ManagerModel(peer)
    off.Note("x")
    Assert.Equal(off.Trace().Length, 0, "nothing is kept without TraceOn")
}

TestRun.Finish()

HasValue(list, value) {
    for item in list {
        if (item = value)
            return true
    }
    return false
}
