#Requires AutoHotkey v2.0
; Unit tests for src/editor/EditorModel.ahk (WI-0088, PROTOCOL 4.11): the start and the subscriptions, the resync rules
; (runstate and get, epoch, engine restart and process events, stale answers, one request of a kind in flight, retries),
; the sequence rule (an event at or below the answered seq is discarded, a gap is normal), the events of the flow, the end
; of the editor (deleted, not found) and the scene that follows the states. The peer is a fake that records the requests;
; the later function records the retries, which the test runs by hand.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\core\Json.ahk
#Include ..\..\src\editor\EditorModel.ahk
#Include ..\..\src\elements\Default\_includes_engine.ahk

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

    ; Answers the oldest open request of the type with the payload (a Map). Throws when there is none.
    Answer(type, payload) {
        for i, req in this.requests {
            if (req["type"] = type) {
                this.requests.RemoveAt(i)
                req["cb"](FakeAnswer(payload))
                return
            }
        }
        throw AssertFailed("no open request of " type)
    }

    Count(type) {
        n := 0
        for req in this.requests {
            if (req["type"] = type)
                n += 1
        }
        return n
    }

    Clear() {
        this.requests := []
    }
}

class FakeAnswer {
    __New(payload) {
        this.payload := payload
    }
}

; The retries of the model: fn runs when the test calls RunLater().
class FakeLater {
    __New() {
        this.pending := []
    }

    Add(ms, fn) {
        this.pending.Push(fn)
    }

    RunLater() {
        fns := this.pending
        this.pending := []
        for fn in fns
            fn()
        return fns.Length
    }
}

FLOW := "Flow 7"

; An evt.element.states of the engine (PROTOCOL 4.3) with one element: the fields of p are the element's, flowId, epoch and seq
; belong to the batch. The element tests of the model use it.
OnElementStates(model, p) {
    entry := Map()
    for key, value in p {
        if (key != "flowId" && key != "epoch" && key != "seq")
            entry[key] := value
    }
    model.OnEvent("evt.element.states", Map("flowId", p["flowId"], "elements", [entry], "epoch", p["epoch"]
        , "seq", p["seq"]))
}

; Two actions and a trigger; the connection from the trigger to A (normal) and from A to B.
FlowDefinition() {
    return Json.Parse('{"name": "Demo", "category": "", "flowSettings": {"zoomFactor": "1.000000", "Offsetx": "0", "Offsety": "0"},'
        . '"allElements": {'
        . '"T": {"ID": "T", "type": "trigger", "class": "Trigger_Manual", "package": "Default", "x": 0, "y": 0, "DefaultTrigger": "1"},'
        . '"A": {"ID": "A", "type": "action", "class": "action_Sleep", "package": "Default", "x": 0, "y": 300},'
        . '"B": {"ID": "B", "type": "action", "class": "action_Sleep", "package": "Default", "x": 0, "y": 600}},'
        . '"allConnections": {'
        . '"c1": {"ID": "c1", "from": "T", "to": "A", "ConnectionType": "normal"},'
        . '"c2": {"ID": "c2", "from": "A", "to": "B", "ConnectionType": "normal"}}}')
}

; A model with a fake peer and a fake later, started: the runstate and the definition are answered as the engine would.
Started(epoch := 100, seq := 10) {
    peer := FakePeer()
    model := EditorModel(peer, FLOW)
    later := FakeLater()
    model.later := (ms, fn) => later.Add(ms, fn)
    model.Start()
    return Map("model", model, "peer", peer, "later", later, "epoch", epoch, "seq", seq)
}

Loaded(epoch := 100, seq := 10) {
    t := Started(epoch, seq)
    AnswerRunstate(t, epoch, seq)
    AnswerDefinition(t, 1)
    return t
}

AnswerRunstate(t, epoch, seq, elements := "", triggers := "", flow := "") {
    if (elements = "")
        elements := []
    if (triggers = "")
        triggers := [Map("elementId", "T", "enabled", 1, "armed", 1, "message", "")]
    if (flow = "")
        flow := Map("enabled", 1, "independentActive", 0, "executing", 0, "instances", 0)
    t["peer"].Answer("cmd.flow.runstate", Map("ok", 1, "epoch", epoch, "seq", seq, "flow", flow
        , "triggers", triggers, "elements", elements))
}

AnswerDefinition(t, rev) {
    t["peer"].Answer("cmd.flow.get", Map("ok", 1, "rev", rev, "definition", FlowDefinition()))
}

; The answer payload of a refused request (the values of a parsed answer: true and false are 1 and 0).
ErrorAnswer(code) => Map("ok", 0, "error", Map("code", code, "message", code))

StartSubscribesAndAsks() {
    t := Started()
    peer := t["peer"]
    Assert.True(peer.topics.Length = 4, "four topics")
    Assert.Equal(peer.topics[4], "flow:" FLOW, "the flow topic")
    Assert.Equal(peer.Count("cmd.flow.runstate"), 1, "runstate at the start")
    Assert.Equal(peer.Count("cmd.flow.get"), 1, "definition at the start")
    Assert.Equal(peer.requests[1]["payload"]["flowId"], FLOW, "the flow ID is the one of the editor")
}

AnswersBuildTheScene() {
    t := Loaded()
    model := t["model"]
    Assert.Equal(model.draft.rev, 1, "rev")
    Assert.Equal(model.name, "Demo", "name")
    Assert.Equal(model.engineState, EditorModel.ENGINE_READY, "engine ready")
    Assert.Equal(model.flowState["enabled"], 1, "flow enabled")
    Assert.Equal(model.triggers["T"]["enabled"], 1, "trigger enabled")
    sc := model.CurrentScene()
    Assert.True(sc != "", "a scene after the definition")
    Assert.Equal(sc.Elements.Length, 3, "three elements")
    Assert.Equal(sc.Connections.Length, 2, "two connections")
    Assert.Equal(ElementOf(sc, "T").Trigger["default"], 1, "the default manual trigger (T) has the star")
}

RunningElementIsDrawnAndFinishes() {
    t := Loaded()
    model := t["model"]
    before := model.CurrentScene()
    OnElementStates(model, Map("flowId", FLOW, "elementId", "A", "state", "running", "countRuns", 1
        , "lastRun", "2026-10-19 10:00:00", "epoch", 100, "seq", 11))
    Assert.Equal(model.run["A"], "running", "A runs")
    sc := model.CurrentScene()
    Assert.Equal(sc.Version, before.Version + 1, "a new version for a state change")
    Assert.Equal(ElementOf(sc, "A").Run, "running", "A is drawn running")
    Assert.True(ElementOf(sc, "B") == ElementOf(before, "B"), "B did not change: the same object")
    now := 1000
    model.clock := () => now
    OnElementStates(model, Map("flowId", FLOW, "elementId", "A", "state", "finished", "countRuns", 0
        , "lastRun", "2026-10-19 10:00:00", "epoch", 100, "seq", 12))
    Assert.Equal(model.run["A"], 1, "A fades out from full strength")
    Assert.True(IsNumber(ElementOf(model.CurrentScene(), "A").Run), "A is drawn as a fade")
    Assert.Equal(t["later"].pending.Length, 1, "one fade timer while a tint fades")
    now := 1500
    t["later"].RunLater()
    Assert.True(Abs(model.run["A"] - 0.5) < 0.001, "half faded after half a second")
    Assert.Equal(t["later"].pending.Length, 1, "the timer runs again while the fade goes on")
    now := 2100
    t["later"].RunLater()
    Assert.True(!model.run.Has("A"), "faded out after one second")
    Assert.Equal(ElementOf(model.CurrentScene(), "A").Run, "", "A is not drawn any more")
    Assert.Equal(t["later"].pending.Length, 0, "no fade timer once every fade is over")
}

; An exception keeps its look until the element starts again; its message is kept for the tooltip.
ExceptionKeepsItsLook() {
    t := Loaded()
    model := t["model"]
    now := 1000
    model.clock := () => now
    OnElementStates(model, Map("flowId", FLOW, "elementId", "A", "state", "exception", "countRuns", 0
        , "message", "the expression is wrong", "epoch", 100, "seq", 11))
    Assert.Equal(model.run["A"], "exception", "A keeps the exception look")
    Assert.Equal(model.messages["A"], "the expression is wrong", "the message for the tooltip")
    Assert.Equal(t["later"].pending.Length, 0, "no fade of an exception")
    now := 9000
    t["later"].RunLater()
    Assert.Equal(model.run["A"], "exception", "still the exception look after a while")
    Assert.Equal(ElementOf(model.CurrentScene(), "A").Run, "exception", "drawn as an exception")
    OnElementStates(model, Map("flowId", FLOW, "elementId", "A", "state", "running", "countRuns", 1
        , "epoch", 100, "seq", 12))
    Assert.Equal(model.run["A"], "running", "the next start ends the look")
    Assert.True(!model.messages.Has("A"), "the message is gone with it")
}

; The connection a thread took is tinted at the start of the thread and fades out over one second, while the element runs on.
ConnectionTakenFades() {
    t := Loaded()
    model := t["model"]
    now := 1000
    model.clock := () => now
    OnElementStates(model, Map("flowId", FLOW, "elementId", "A", "state", "running", "countRuns", 1
        , "connectionId", "c1", "epoch", 100, "seq", 11))
    Assert.Equal(model.run["c1"], 1, "the connection is tinted")
    Assert.Equal(model.run["A"], "running", "the element runs")
    Assert.True(ConnectionOf(model.CurrentScene(), "c1").Run != "" && IsNumber(ConnectionOf(model.CurrentScene(), "c1").Run)
        , "the connection is drawn as a fade")
    now := 1400
    t["later"].RunLater()
    Assert.True(Abs(model.run["c1"] - 0.6) < 0.001, "the fade of the connection goes on")
    Assert.Equal(model.run["A"], "running", "the element still runs")
    now := 2100
    t["later"].RunLater()
    Assert.True(!model.run.Has("c1"), "the connection faded out")
    Assert.Equal(model.run["A"], "running", "the element still runs")
}

ConnectionOf(sc, id) {
    for connection in sc.Connections {
        if (connection.Id = id)
            return connection
    }
    throw AssertFailed("no connection " id)
}

; Warnings change the scene without a build, and events between two frames cost one scene (one WithStates) only.
WarningsAreShownAndCoalescedPerFrame() {
    t := Loaded()
    model := t["model"]
    before := model.CurrentScene()
    model.OnEvent("evt.element.warning", Map("flowId", FLOW, "elementId", "A", "count", 2, "text", "f1 line 1",
        "epoch", 100, "seq", 11))
    model.OnEvent("evt.element.warning", Map("flowId", FLOW, "elementId", "A", "count", 3, "text", "f1 line 2",
        "epoch", 100, "seq", 12))
    OnElementStates(model, Map("flowId", FLOW, "elementId", "B", "state", "running", "countRuns", 1,
        "epoch", 100, "seq", 13))
    Assert.Equal(model.warnings["A"]["count"], 3, "the count of the last event")
    sc := model.CurrentScene()
    Assert.Equal(sc.Version, before.Version + 1, "three events, one scene")
    Assert.Equal(ElementOf(sc, "A").WarningCount, 3, "the badge shows the count")
    Assert.Equal(ElementOf(sc, "A").Warning, "f1 line 2", "the text of the last warning")
    Assert.True(ElementOf(sc, "T") == ElementOf(before, "T"), "T did not change: the same object")
    Assert.True(ElementOf(sc, "A") != ElementOf(before, "A"), "A changed: a new object")
    Assert.Equal(CountIssues(sc, "A"), 1, "the warning is listed once in the scene")
    Assert.Equal(model.CurrentScene().Version, sc.Version, "a second ask builds nothing")
}

CountIssues(sc, id) {
    n := 0
    for issue in sc.Warnings {
        if (issue["id"] = id)
            n += 1
    }
    return n
}

; The frame latency (REQ-PRF-060): from the first change a frame shows to the end of that frame.
LatencyOfFrames() {
    t := Loaded()                    ; the answers changed the scene with the real clock: that change is not measured here
    model := t["model"]
    model.pendingAt := 0
    now := 1000
    model.clock := () => now
    OnElementStates(model, Map("flowId", FLOW, "elementId", "A", "state", "running", "countRuns", 1,
        "epoch", 100, "seq", 11))
    now := 1040
    model.CurrentScene()
    model.NoteFrame()
    lat := model.Latency()
    Assert.Equal(lat["n"], 1, "one frame measured")
    Assert.Equal(lat["medianUs"], 40000, "40 ms from the change to the frame")
    model.NoteFrame()
    Assert.Equal(model.Latency()["n"], 1, "a frame without a change is not measured")
    ; twenty more frames of 1 to 20 ms: the 21 values are 1..20 and 40; the median is the 11th (11 ms), the 95 % point the 20th
    for v in [5, 1, 9, 3, 7, 2, 8, 4, 6, 10, 12, 11, 15, 13, 14, 20, 18, 19, 17, 16] {
        now := 2000 + A_Index * 100
        OnElementStates(model, Map("flowId", FLOW, "elementId", "A", "state", "running", "countRuns", 1,
            "epoch", 100, "seq", 12 + A_Index))
        now := now + v
        model.CurrentScene()
        model.NoteFrame()
    }
    lat := model.Latency()
    Assert.Equal(lat["n"], 21, "all frames are kept")
    Assert.Equal(lat["medianUs"], 11000, "the median of the 21 values")
    Assert.Equal(lat["p95Us"], 20000, "the 95 % point")
}

; The sorted copy of the shell sort is sorted and keeps every value.
SortedCopy() {
    sorted := EditorModel._Sorted([5, 3, 9, 1, 7, 3, 0, 12, 8, 2])
    Assert.Equal(sorted.Length, 10, "same count")
    for i, v in sorted {
        if (i > 1)
            Assert.True(sorted[i - 1] <= v, "ascending at " i)
    }
    Assert.Equal(sorted[1], 0, "smallest")
    Assert.Equal(sorted[10], 12, "largest")
}

ElementOf(sc, id) {
    for element in sc.Elements {
        if (element.Id = id)
            return element
    }
    throw AssertFailed("no element " id)
}

EventsAtOrBelowTheAnswerAreDiscarded() {
    t := Loaded(100, 10)
    model := t["model"]
    model.OnEvent("evt.flow.state", Map("flowId", FLOW, "enabled", 0, "independentActive", 0, "executing", 0
        , "instances", 0, "epoch", 100, "seq", 9))
    Assert.Equal(model.flowState["enabled"], 1, "seq 9 is older than the answer (10): discarded")
    model.OnEvent("evt.flow.state", Map("flowId", FLOW, "enabled", 0, "independentActive", 0, "executing", 0
        , "instances", 0, "epoch", 100, "seq", 11))
    Assert.Equal(model.flowState["enabled"], 0, "seq 11 is newer: applied")
    Assert.Equal(t["peer"].Count("cmd.flow.runstate"), 0, "a gap is normal: no resync")
}

GapInSeqIsNormal() {
    t := Loaded(100, 10)
    model := t["model"]
    OnElementStates(model, Map("flowId", FLOW, "elementId", "A", "state", "running", "epoch", 100, "seq", 40))
    Assert.Equal(model.run["A"], "running", "applied after a gap of 29")
    Assert.Equal(t["peer"].Count("cmd.flow.runstate"), 0, "no request for a gap")
}

NewEpochAsksAgain() {
    t := Loaded(100, 10)
    model := t["model"]
    model.OnEvent("evt.flow.state", Map("flowId", FLOW, "enabled", 1, "independentActive", 0, "executing", 0
        , "instances", 0, "epoch", 200, "seq", 1))
    Assert.Equal(t["peer"].Count("cmd.flow.runstate"), 1, "a new epoch asks the state again")
    Assert.Equal(model.lastResync["reason"], "epoch", "the reason")
    AnswerRunstate(t, 200, 1, [Map("elementId", "A", "state", "running", "countRuns", 1, "lastRun", "x")])
    Assert.Equal(model.epoch, 200, "the new epoch")
    Assert.Equal(model.run["A"], "running", "the answer of the new engine")
}

EngineRestartedAndReadyResync() {
    t := Loaded()
    model := t["model"]
    model.OnEvent("evt.engine.restarted", Map("epoch", 100, "seq", 20))
    Assert.Equal(t["peer"].Count("cmd.flow.runstate"), 1, "engine restarted: runstate")
    Assert.Equal(t["peer"].Count("cmd.flow.get"), 1, "engine restarted: the definition is asked as well")
    model.OnEvent("evt.engine.ready", Map("epoch", 100, "seq", 21))
    Assert.Equal(model.lastResync["reason"], "evt.engine.ready", "engine ready resyncs")
}

EngineProcessEventsSetTheConnectionState() {
    t := Loaded()
    model := t["model"]
    model.OnEvent("evt.process.crashed", Map("name", "engine", "pid", 1, "reason", "exited", "exitCode", 7, "restart", 1))
    Assert.Equal(model.engineState, EditorModel.ENGINE_DOWN, "the engine crashed")
    model.OnEvent("evt.process.exited", Map("name", "storage", "pid", 2, "clean", 1, "exitCode", 0))
    Assert.Equal(model.engineState, EditorModel.ENGINE_DOWN, "another process changes nothing")
    model.OnEvent("evt.process.restarted", Map("name", "engine", "attempt", 1))
    Assert.Equal(t["peer"].Count("cmd.flow.runstate"), 1, "a restarted engine is asked")
}

OneRequestOfAKindInFlight() {
    t := Loaded()
    model := t["model"]
    t["peer"].Clear()
    model.OnEvent("evt.engine.restarted", Map("epoch", 100, "seq", 20))
    model.OnEvent("evt.engine.ready", Map("epoch", 100, "seq", 21))
    model.OnEvent("evt.process.restarted", Map("name", "engine", "attempt", 1))
    Assert.Equal(t["peer"].Count("cmd.flow.runstate"), 1, "only one request in flight")
    AnswerRunstate(t, 100, 21)
    Assert.Equal(t["peer"].Count("cmd.flow.runstate"), 1, "the reasons that came meanwhile are asked once more")
    AnswerRunstate(t, 100, 22)
    Assert.Equal(t["peer"].Count("cmd.flow.runstate"), 0, "then nothing more")
}

StaleAnswerIsAskedAgain() {
    t := Started(100, 10)
    model := t["model"]
    OnElementStates(model, Map("flowId", FLOW, "elementId", "A", "state", "running", "epoch", 100, "seq", 30))
    AnswerRunstate(t, 100, 10)            ; the answer is older than the event applied
    Assert.Equal(t["peer"].Count("cmd.flow.runstate"), 1, "stale: asked again")
    Assert.True(model.run.Has("A"), "the stale answer did not undo the event: A stays running")
    AnswerRunstate(t, 100, 31)
    Assert.Equal(model.lastSeq, 31, "the newer answer is applied")
}

FlowListChangedRemovedEndsTheEditor() {
    t := Loaded()
    model := t["model"]
    ends := []
    model.AddListener((kind, data) => (kind = "ended") ? ends.Push(data) : 0)
    model.OnEvent("evt.flow.list.changed", Map("added", ["Flow 9"], "removed", [], "changed", [], "epoch", 100, "seq", 15))
    Assert.Equal(ends.Length, 0, "another flow added: nothing")
    model.OnEvent("evt.flow.list.changed", Map("added", [], "removed", [FLOW], "changed", [], "epoch", 100, "seq", 16))
    Assert.Equal(ends.Length, 1, "the flow removed: the editor ends")
    Assert.Equal(ends[1], "deleted", "the reason")
    Assert.Equal(model.ended, "deleted", "the model says so")
}

NotFoundAtTheStartEndsTheEditorNow() {
    t := Started()
    model := t["model"]
    t["peer"].Answer("cmd.flow.runstate", ErrorAnswer("not_found"))
    Assert.Equal(model.ended, "not_found", "ends at once")
    Assert.Equal(t["later"].RunLater(), 0, "no retry for a flow that does not exist at the start")
}

NotFoundLaterIsAskedAgainForAWhile() {
    t := Loaded()
    model := t["model"]
    t["peer"].Clear()
    model.OnEvent("evt.engine.restarted", Map("epoch", 100, "seq", 20))
    t["peer"].Answer("cmd.flow.runstate", ErrorAnswer("not_found"))
    Assert.Equal(model.ended, "", "the editor goes on")
    Assert.Equal(t["later"].RunLater(), 1, "one retry")
    Assert.Equal(t["peer"].Count("cmd.flow.runstate"), 1, "the retry asks the state again")
    Assert.Equal(model.ended, "", "still not ended")
}

BusyIsAskedAgain() {
    t := Started()
    model := t["model"]
    t["peer"].Answer("cmd.flow.runstate", ErrorAnswer("busy"))
    Assert.Equal(model.ended, "", "busy does not end the editor")
    Assert.Equal(t["later"].RunLater(), 1, "retry after the pause")
    Assert.Equal(t["peer"].Count("cmd.flow.runstate"), 1, "the retry is a new request")
}

CommittedAsksTheDefinitionOnlyForANewRev() {
    t := Loaded()
    model := t["model"]
    model.OnEvent("evt.flow.committed", Map("flowId", FLOW, "rev", 1, "byMeta", 0, "epoch", 100, "seq", 14))
    Assert.Equal(t["peer"].Count("cmd.flow.get"), 0, "the same rev: no request")
    model.OnEvent("evt.flow.committed", Map("flowId", FLOW, "rev", 2, "byMeta", 1, "epoch", 100, "seq", 15))
    Assert.Equal(t["peer"].Count("cmd.flow.get"), 1, "a new rev asks the definition")
    Assert.Equal(t["peer"].Count("cmd.flow.runstate"), 0, "not the state")
}

TriggerAndWarningEvents() {
    t := Loaded()
    model := t["model"]
    model.OnEvent("evt.trigger.state", Map("flowId", FLOW, "elementId", "T", "enabled", 0, "armed", 0
        , "message", "missing", "epoch", 100, "seq", 11))
    Assert.Equal(model.triggers["T"]["enabled"], 0, "the trigger is disabled")
    Assert.Equal(model.triggers["T"]["message"], "missing", "its message")
    model.OnEvent("evt.element.warning", Map("flowId", FLOW, "elementId", "A", "count", 3, "text", "f1 line 2",
        "epoch", 100, "seq", 12))
    Assert.Equal(model.warnings["A"]["count"], 3, "the warning count")
    Assert.Equal(model.warnings["A"]["text"], "f1 line 2", "the warning text")
}

DuplicateEventsAreIgnored() {
    t := Loaded()
    model := t["model"]
    changes := 0
    model.AddListener((kind, data) => (kind = "state") ? changes++ : 0)
    OnElementStates(model, Map("flowId", FLOW, "elementId", "A", "state", "running", "epoch", 100, "seq", 11))
    OnElementStates(model, Map("flowId", FLOW, "elementId", "A", "state", "running", "epoch", 100, "seq", 11))
    Assert.Equal(changes, 1, "the second copy of seq 11 changes nothing")
}

CanvasChangesTheViewOnly() {
    t := Loaded()
    model := t["model"]
    before := model.CurrentScene()
    model.SetCanvas(800, 600, 144)
    sc := model.CurrentScene()
    Assert.Equal(sc.View.Width, 800, "the canvas width")
    Assert.Equal(sc.View.Dpi, 144, "the DPI")
    Assert.Equal(sc.Elements.Length, before.Elements.Length, "the same elements")
}

StateOfTheModel() {
    t := Loaded()
    model := t["model"]
    st := model.State()
    Assert.Equal(st["elements"], 3, "elements of the definition")
    Assert.Equal(st["connections"], 2, "connections of the definition")
    Assert.Equal(st["rev"], 1, "rev")
}

TestRun.Init()

TestRun.Case("Editor model: start subscribes to the topics and asks the state and the definition", StartSubscribesAndAsks)
TestRun.Case("Editor model: the answers give the states and the scene", AnswersBuildTheScene)
TestRun.Case("Editor model: a running element is drawn running and fades out after a finish", RunningElementIsDrawnAndFinishes)
TestRun.Case("Editor model: an exception keeps its look and its message until the next start", ExceptionKeepsItsLook)
TestRun.Case("Editor model: the connection a thread took is tinted and fades in one second", ConnectionTakenFades)
TestRun.Case("Editor model: warnings show in the scene, and the events of a frame cost one scene", WarningsAreShownAndCoalescedPerFrame)
TestRun.Case("Editor model: the frame latency is the time from the change to the end of its frame", LatencyOfFrames)
TestRun.Case("Editor model: the sorted copy of the latencies is sorted", SortedCopy)
TestRun.Case("Editor model: events at or below the answered seq are discarded", EventsAtOrBelowTheAnswerAreDiscarded)
TestRun.Case("Editor model: a gap in seq is normal and causes no resync", GapInSeqIsNormal)
TestRun.Case("Editor model: a new epoch asks the state again and takes the new answer", NewEpochAsksAgain)
TestRun.Case("Editor model: engine restarted and engine ready resync", EngineRestartedAndReadyResync)
TestRun.Case("Editor model: engine process events set the connection state and resync on ready", EngineProcessEventsSetTheConnectionState)
TestRun.Case("Editor model: one request of a kind is in flight, the reasons meanwhile are asked once more", OneRequestOfAKindInFlight)
TestRun.Case("Editor model: a stale answer is asked again at once", StaleAnswerIsAskedAgain)
TestRun.Case("Editor model: the flow removed from the list ends the editor, another flow does not", FlowListChangedRemovedEndsTheEditor)
TestRun.Case("Editor model: not found at the start ends the editor without a retry", NotFoundAtTheStartEndsTheEditorNow)
TestRun.Case("Editor model: not found after a restart is asked again for a while", NotFoundLaterIsAskedAgainForAWhile)
TestRun.Case("Editor model: busy is asked again after a pause", BusyIsAskedAgain)
TestRun.Case("Editor model: evt.flow.committed asks the definition for a new rev only", CommittedAsksTheDefinitionOnlyForANewRev)
TestRun.Case("Editor model: trigger states and warnings per element", TriggerAndWarningEvents)
TestRun.Case("Editor model: a duplicate event changes nothing", DuplicateEventsAreIgnored)
TestRun.Case("Editor model: a canvas changes the view and keeps the elements", CanvasChangesTheViewOnly)
TestRun.Case("Editor model: the state of the model for the test command", StateOfTheModel)

TestRun.Finish()
