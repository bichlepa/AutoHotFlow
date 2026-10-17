#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Time.ahk

; The model of the manager (WI-0073, doc/ARCHITECTURE.md 3, doc/PROTOCOL.md 4.8). It holds the UI state only: the flows with
; their state, the categories and their order, the settings and the state of the connection to the engine. The truth
; stays in the engine (and in storage); the model shows what the engine reports and resyncs when it may have missed
; something. It has no GUI code and no file I/O: the view (ManagerWindow) listens to its events, the headless driver
; (ManagerDriver) calls its operations, and the unit tests give it a fake peer.
;
; The peer is anything with Request(to, type, payload, callback, timeoutMs) and Subscribe(topic) (the Peer of core/ipc).
;
; Events for the listeners, fn(kind, data):
;   "engine"      the state of the connection to the engine changed; data is the new state (see EngineState)
;   "snapshot"    the whole state was replaced by a snapshot of the engine
;   "flow"        one flow changed; data is its record
;   "categories"  the categories or their order changed (the flow records are unchanged)
;   "settings"    the settings changed
;   "selection"   the selected flow changed; data is the flow ID or ""
;   "answer"      the answer to a command of the user; data is Map(type, flowId, ok, code, message, payload, ms)
;
; Resync (PROTOCOL 4.8 and 5): cmd.engine.snapshot after evt.engine.ready, evt.engine.restarted, evt.flow.list.changed, a new
; epoch, a gap in seq, evt.process.restarted/ready of the engine, and after an answer that is older than the newest
; event already seen. One snapshot request is in flight at a time: a reason that comes while one is out is remembered
; and asked once more when the answer is in (loading 200 flows sends 200 list events; they cost one more request, not 200).
class ManagerModel {
    static SNAPSHOT_MS := 5000
    static COMMAND_MS := 5000
    static EXIT_MS := 5000
    static TRACE_MAX := 20000
    ; The values of EngineState.
    static ENGINE_WAITING := "waiting"   ; no snapshot yet
    static ENGINE_LOADING := "loading"   ; the engine answers but has not loaded all flows (snapshot ready false)
    static ENGINE_READY := "ready"
    static ENGINE_DOWN := "down"         ; the engine ended, crashed or does not answer

    ; Wall clock in ms since 1970 (UTC), comparable with the Python clock time.time() * 1000.
    static WallMs() {
        ft := Buffer(8, 0)
        DllCall("GetSystemTimePreciseAsFileTime", "Ptr", ft)
        return Integer(NumGet(ft, 0, "Int64") / 10000 - 11644473600000)
    }

    ; "ok" or the error code of an answer payload.
    static Outcome(payload) {
        if (payload.Get("ok", 0))
            return "ok"
        if (payload.Has("error") && IsObject(payload["error"]))
            return payload["error"].Get("code", "?")
        return "?"
    }

    __New(peer) {
        this.peer := peer
        this.listeners := []
        this.epoch := 0
        this.lastSeq := 0
        this.engineState := ManagerModel.ENGINE_WAITING
        this.flows := Map()             ; flowId -> Map(flowId, name, category, enabled, executing, rev, independentActive, stateError, triggers)
        this.flowIds := []              ; the flow IDs in the order of the last snapshot
        this.categories := []           ; Array of Map(name, flows: [flowId, ..]) in the order of the engine
        this.settings := Map()
        this.selectedFlow := ""
        this.subscribed := Map()        ; flowId -> true, the topics flow:<id> that are subscribed
        this.snapshotOut := false       ; a cmd.engine.snapshot is in flight
        this.snapshotAgain := ""        ; the reason of a resync that came while one was in flight
        this.resyncCount := 0
        this.snapshotCount := 0
        this.eventCount := 0
        this.firstSnapshotMs := 0       ; Time.NowMs() of the first good snapshot
        this.startMs := 0
        this.lastAnswer := ""
        this.recording := false
        this.traceLog := []                ; the record of everything the model saw (tests, TraceOn)
        this.traceCount := 0
    }

    ; --- listeners and trace -------------------------------------------------------------------

    AddListener(fn) {
        this.listeners.Push(fn)
    }

    _Notify(kind, data := "") {
        for fn in this.listeners
            fn(kind, data)
    }

    ; Switches the record of events on (the headless driver does; the product keeps nothing). The newest TRACE_MAX
    ; entries are kept; Trace(since) returns the entries with a number above since.
    TraceOn() {
        this.recording := true
    }

    Note(type, payload := "") {
        if (!this.recording)
            return
        this.traceCount += 1
        this.traceLog.Push(Map("n", this.traceCount, "type", type, "recvMs", ManagerModel.WallMs()
            , "payload", IsObject(payload) ? payload : Map()))
        if (this.traceLog.Length > ManagerModel.TRACE_MAX)
            this.traceLog.RemoveAt(1, this.traceLog.Length - ManagerModel.TRACE_MAX)
    }

    Trace(since := 0) {
        out := []
        for entry in this.traceLog {
            if (entry["n"] > since)
                out.Push(entry)
        }
        return out
    }

    ; --- start and resync ----------------------------------------------------------------------

    ; Subscribes to the topics and asks for the first snapshot. Subscriptions are kept by the peer across reconnects.
    Start() {
        this.startMs := Time.NowMs()
        this.peer.Subscribe("engine")
        this.peer.Subscribe("process")
        this.RequestSnapshot("start")
    }

    RequestSnapshot(reason) {
        if (this.snapshotOut) {
            this.snapshotAgain := reason
            return
        }
        this.snapshotOut := true
        this.resyncCount += 1
        try {
            this.peer.Request("engine", "cmd.engine.snapshot", Map(), (ans) => this._OnSnapshot(reason, ans)
                , ManagerModel.SNAPSHOT_MS)
        } catch as e {
            this.snapshotOut := false
            this.Note("manager.error", Map("text", "snapshot request failed: " Type(e) ": " e.Message))
            this._SetEngine(ManagerModel.ENGINE_DOWN)
        }
    }

    ; Callback of cmd.engine.snapshot, called exactly once (answer or timeout). A failure (the engine is down) changes no
    ; flow: the next engine event or process event asks again.
    _OnSnapshot(reason, ans) {
        this.snapshotOut := false
        p := ans.payload
        if (!p.Get("ok", 0)) {
            code := ""
            if (p.Has("error") && IsObject(p["error"]))
                code := p["error"].Get("code", "")
            this.Note("manager.snapshot", Map("reason", reason, "ok", Json.False, "code", code))
            this._SetEngine(ManagerModel.ENGINE_DOWN)
            this._AskAgain()
            return
        }
        ep := p.Get("epoch", 0)
        sq := p.Get("seq", 0)
        if (ep < this.epoch || (ep = this.epoch && sq < this.lastSeq)) {
            ; Events newer than this answer were already applied (an event of a newer epoch, or a later seq of this one; the
            ; epoch is the start time of the engine process): the answer would undo them. Ask again.
            this.Note("manager.snapshot", Map("reason", reason, "ok", Json.True, "stale", Json.True))
            this.RequestSnapshot("stale")
            return
        }
        this.epoch := ep
        this.lastSeq := sq
        this.snapshotCount += 1
        this._Replace(p)
        if (this.firstSnapshotMs = 0)
            this.firstSnapshotMs := Time.NowMs()
        this.Note("manager.snapshot", Map("reason", reason, "ok", Json.True, "epoch", ep, "seq", sq
            , "flows", this.flowIds.Length))
        this._SetEngine(p.Get("ready", 0) ? ManagerModel.ENGINE_READY : ManagerModel.ENGINE_LOADING)
        this._Notify("snapshot")
        this._AskAgain()
    }

    _AskAgain() {
        if (this.snapshotAgain = "")
            return
        reason := this.snapshotAgain
        this.snapshotAgain := ""
        this.RequestSnapshot(reason)
    }

    ; Takes the flows, the categories and the settings of a snapshot as the new state.
    _Replace(p) {
        recs := Map()
        ids := []
        for f in p.Get("flows", []) {
            id := f["flowId"]
            recs[id] := Map("flowId", id, "name", f.Get("name", ""), "category", f.Get("category", "")
                , "enabled", f.Get("enabled", 0), "executing", f.Get("executing", 0), "rev", f.Get("rev", 0)
                , "independentActive", f.Get("independentActive", 0), "stateError", f.Get("stateError", "")
                , "triggers", f.Get("triggers", []))
            ids.Push(id)
        }
        this.flows := recs
        this.flowIds := ids
        this.categories := ManagerModel._CopyCategories(p.Get("categories", []))
        settings := p.Get("settings", Map())
        this.settings := IsObject(settings) ? settings : Map()
        if (this.selectedFlow != "" && !recs.Has(this.selectedFlow))
            this.Select("")
        for id in ids {
            if (!this.subscribed.Has(id)) {
                this.subscribed[id] := true
                this.peer.Subscribe("flow:" id)
            }
        }
    }

    static _CopyCategories(list) {
        out := []
        for c in list
            out.Push(Map("name", c.Get("name", ""), "flows", c.Get("flows", [])))
        return out
    }

    _SetEngine(state) {
        if (this.engineState = state)
            return
        this.engineState := state
        this.Note("manager.engine", Map("state", state))
        this._Notify("engine", state)
    }

    ; --- events --------------------------------------------------------------------------------

    ; Every event of the topics engine, process and flow:<id>. Events of the topic log are not for the model.
    OnEvent(type, p) {
        this.eventCount += 1
        this.Note(type, p)
        if (SubStr(type, 1, 12) = "evt.process.") {
            this._OnProcessEvent(type, p)
            return
        }
        check := this._CheckSequence(p)
        if (check = "duplicate")
            return
        reason := ""
        if (check = "epoch" || check = "gap")
            reason := check
        if (type = "evt.engine.ready" || type = "evt.engine.restarted" || type = "evt.flow.list.changed")
            reason := type
        if (reason != "")
            this.RequestSnapshot(reason)
        switch type {
            case "evt.flow.state":
                this._ApplyFlowState(p)
            case "evt.trigger.state":
                this._ApplyTriggerState(p)
            case "evt.category.changed":
                this.categories := ManagerModel._CopyCategories(p.Get("categories", []))
                this._Notify("categories")
            case "evt.settings.changed":
                settings := p.Get("settings", Map())
                this.settings := IsObject(settings) ? settings : Map()
                this._Notify("settings")
        }
    }

    ; Process events of the supervisor. Only the engine matters to the model.
    _OnProcessEvent(type, p) {
        if (p.Get("name", "") != "engine")
            return
        switch type {
            case "evt.process.crashed", "evt.process.exited", "evt.process.hung":
                this._SetEngine(ManagerModel.ENGINE_DOWN)
            case "evt.process.restarted", "evt.process.ready":
                this.RequestSnapshot(type)
        }
    }

    ; Checks epoch and seq of an engine event (PROTOCOL 4.3). Returns "" (in order, or no seq), "epoch" (new engine
    ; process), "gap" (events were missed) or "duplicate" (already seen).
    _CheckSequence(p) {
        if (!p.Has("seq") || !p.Has("epoch"))
            return ""
        ep := p["epoch"]
        sq := p["seq"]
        if (ep != this.epoch) {
            this.epoch := ep
            this.lastSeq := sq
            return "epoch"
        }
        if (sq <= this.lastSeq)
            return "duplicate"
        gap := (this.lastSeq > 0 && sq > this.lastSeq + 1)
        this.lastSeq := sq
        return gap ? "gap" : ""
    }

    _ApplyFlowState(p) {
        id := p.Get("flowId", "")
        if (!this.flows.Has(id)) {
            this.RequestSnapshot("flow.state of unknown flow " id)
            return
        }
        rec := this.flows[id]
        rec["enabled"] := p.Get("enabled", 0)
        rec["executing"] := p.Get("executing", 0)
        rec["independentActive"] := p.Get("independentActive", 0)
        rec["stateError"] := p.Get("stateError", "")      ; absent: the state is known again
        this._Notify("flow", rec)
    }

    _ApplyTriggerState(p) {
        id := p.Get("flowId", "")
        if (!this.flows.Has(id))
            return
        rec := this.flows[id]
        elementId := p.Get("elementId", "")
        for t in rec["triggers"] {
            if (t["elementId"] = elementId) {
                t["enabled"] := p.Get("enabled", 0)
                t["armed"] := p.Get("armed", 0)
                t["message"] := p.Get("message", "")
                this._Notify("flow", rec)
                return
            }
        }
        rec["triggers"].Push(Map("elementId", elementId, "enabled", p.Get("enabled", 0), "armed", p.Get("armed", 0)
            , "message", p.Get("message", "")))
        this._Notify("flow", rec)
    }

    ; --- the state for the view ---------------------------------------------------------------

    ; The flow record, or "" for an unknown ID.
    Flow(flowId) => this.flows.Has(flowId) ? this.flows[flowId] : ""

    ; The flow IDs in the order of the categories (the uncategorized group last), as the tree shows them. A flow that no
    ; category lists (an event came before the order) follows at the end.
    OrderedFlowIds() {
        out := []
        seen := Map()
        for c in this.categories {
            for id in c["flows"] {
                if (this.flows.Has(id) && !seen.Has(id)) {
                    seen[id] := true
                    out.Push(id)
                }
            }
        }
        for id in this.flowIds {
            if (!seen.Has(id))
                out.Push(id)
        }
        return out
    }

    ; The state of the buttons from the selection: Map(name -> true/false). Operations of later packages are false until
    ; their package exists (Edit: the editor, S0005).
    ButtonStates() {
        has := this.selectedFlow != "" && this.flows.Has(this.selectedFlow)
        return Map("NewCategory", false, "NewFlow", false, "ChangeCategory", false, "Duplicate", false, "Delete", false   ; arch-ok: wire-bool UI state of the buttons, not a protocol field
            , "Edit", false, "Enable", false, "Run", has && this.engineState != ManagerModel.ENGINE_DOWN
            , "Settings", false, "ImportExport", false, "About", false, "Help", false, "ShowLog", false, "Exit", true)
    }

    ; The label of the Run button for the selected flow: "Stop" while it runs, "Run" otherwise.
    RunIsStop() {
        return this.selectedFlow != "" && this.flows.Has(this.selectedFlow) && this.flows[this.selectedFlow]["executing"]
    }

    ; Plain values of the whole state (the driver and the snapshot of the role).
    State() {
        flows := []
        for id in this.flowIds {
            rec := this.flows[id]
            flows.Push(Map("flowId", id, "name", rec["name"], "category", rec["category"]
                , "enabled", Json.Bool(rec["enabled"]), "executing", Json.Bool(rec["executing"]), "rev", rec["rev"]
                , "independentActive", rec["independentActive"], "stateError", rec["stateError"]))
        }
        cats := []
        for c in this.categories
            cats.Push(Map("name", c["name"], "flows", c["flows"]))
        buttons := Map()
        for name, on in this.ButtonStates()
            buttons[name] := Json.Bool(on)
        return Map("engine", this.engineState, "epoch", this.epoch, "seq", this.lastSeq, "flows", flows
            , "categories", cats, "settings", this.settings, "selectedFlow", this.selectedFlow, "buttons", buttons
            , "events", this.eventCount, "resyncs", this.resyncCount, "snapshots", this.snapshotCount
            , "lastAnswer", this.lastAnswer = "" ? Map() : this.lastAnswer)
    }

    ; --- operations ----------------------------------------------------------------------------

    Select(flowId) {
        if (flowId != "" && !this.flows.Has(flowId))
            flowId := ""
        if (flowId = this.selectedFlow)
            return
        this.selectedFlow := flowId
        this._Notify("selection", flowId)
    }

    ; Sends a command to the engine with a timeout. Every answer, a refusal or a timeout included, reaches the listeners as
    ; the event "answer" and goes to done(answer) when it is given. answer is Map(type, flowId, ok, code, message, payload,
    ; ms). Never blocks.
    Command(type, payload, done := "") {
        t0 := Time.NowMs()
        flowId := (payload is Map) ? payload.Get("flowId", "") : ""
        this.Note("manager.command", Map("type", type, "flowId", flowId))
        try {
            this.peer.Request("engine", type, payload, (ans) => this._OnCommandAnswer(type, flowId, t0, ans, done)
                , ManagerModel.COMMAND_MS)
        } catch as e {
            this._Answered(Map("type", type, "flowId", flowId, "ok", false, "code", "not_sent", "message", e.Message
                , "payload", Map(), "ms", 0), done)
        }
    }

    _OnCommandAnswer(type, flowId, t0, ans, done) {
        p := ans.payload
        code := ""
        message := ""
        if (!p.Get("ok", 0)) {
            code := ManagerModel.Outcome(p)
            if (p.Has("error") && IsObject(p["error"]))
                message := p["error"].Get("message", "")
            else if (p.Has("message"))
                message := p["message"]
        }
        this._Answered(Map("type", type, "flowId", flowId, "ok", p.Get("ok", 0) ? true : false, "code", code
            , "message", message, "payload", p, "ms", Integer(Time.NowMs() - t0)), done)
    }

    _Answered(answer, done) {
        this.lastAnswer := Map("type", answer["type"], "flowId", answer["flowId"], "ok", Json.Bool(answer["ok"])
            , "code", answer["code"], "message", answer["message"], "ms", answer["ms"])
        this.Note("manager.commandAnswer", this.lastAnswer)
        this._Notify("answer", answer)
        if (IsObject(done))
            done(answer)
    }

    ; The Run button: starts the flow, or stops it while it runs (v1). The state follows from evt.flow.state.
    RunOrStop(flowId := "", done := "") {
        if (flowId = "")
            flowId := this.selectedFlow
        if (flowId = "" || !this.flows.Has(flowId)) {
            this._Answered(Map("type", "cmd.flow.toggle", "flowId", flowId, "ok", false, "code", "not_found"
                , "message", "no flow selected", "payload", Map(), "ms", 0), done)
            return
        }
        this.Command(this.flows[flowId]["executing"] ? "cmd.flow.stop" : "cmd.flow.start", Map("flowId", flowId), done)
    }

    ; The exit button: asks the supervisor for the clean exit of the application (ARCHITECTURE 6.3).
    Exit(done := "") {
        t0 := Time.NowMs()
        this.Note("manager.exit")
        try {
            this.peer.Request("supervisor", "cmd.app.exit", Map(), (ans) => this._OnExitAnswer(t0, ans, done)
                , ManagerModel.EXIT_MS)
        } catch as e {
            this._Answered(Map("type", "cmd.app.exit", "flowId", "", "ok", false, "code", "not_sent"
                , "message", e.Message, "payload", Map(), "ms", 0), done)
        }
    }

    _OnExitAnswer(t0, ans, done) {
        p := ans.payload
        this._Answered(Map("type", "cmd.app.exit", "flowId", "", "ok", p.Get("ok", 0) ? true : false
            , "code", p.Get("ok", 0) ? "" : ManagerModel.Outcome(p), "message", "", "payload", p
            , "ms", Integer(Time.NowMs() - t0)), done)
    }
}
