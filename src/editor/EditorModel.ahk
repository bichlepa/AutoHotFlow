#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include SceneBuilder.ahk

; The model of the editor of one flow (WI-0088, PROTOCOL 4.11, ARCHITECTURE 4.1): what the editor shows of the flow. It holds no
; truth: the definition comes from the engine (cmd.flow.get), the states are the engine's events (evt.flow.state,
; evt.trigger.state, evt.element.state, evt.element.warning) and the answer of cmd.flow.runstate, which is authoritative
; for all of them at once. The model has no GUI code and no timer: the role (Editor) gives it the peer and a later(ms, fn)
; function for retries, the window and the headless driver read it.
;
; Resync (PROTOCOL 4.11): cmd.flow.runstate and cmd.flow.get at the start, after evt.engine.ready or evt.engine.restarted,
; after evt.process.ready/restarted of the engine, on a new epoch, and after evt.flow.committed (the definition only). One
; request of a kind is in flight at a time; a reason that comes meanwhile is asked once more when the answer is in.
; Sequence: the editor sees only a few topics, so a gap in seq is normal and causes no resync. An event of the same epoch
; with seq not above the last applied one is already in the state (discarded); an answer below an applied event is stale
; and asked again.
;
; Events for the listeners, fn(kind, data):
;   "state"    the run, trigger, element or flow state changed (the scene is new)
;   "flow"     the definition was replaced (the scene is new, the title may have changed)
;   "engine"   the connection state of the engine changed; data is the new state
;   "ended"    the editor must end: data is the reason ("deleted", "not_found", "closed", "test")
;   "resync"   a resync was asked; data is the reason
class EditorModel {
    static RUNSTATE_MS := 5000
    static DEFINITION_MS := 5000
    static RETRY_MS := 1000
    static RETRY_LIMIT := 30          ; not_found after the flow was seen: retries before the editor ends (the flow is gone)
    static ENGINE_WAITING := "waiting"
    static ENGINE_READY := "ready"
    static ENGINE_DOWN := "down"

    __New(peer, flowId) {
        this.peer := peer
        this.flowId := flowId
        this.later := ""             ; fn(ms, callback): runs callback after ms (the role sets it; tests use a fake)
        this.listeners := []
        this.name := ""
        this.rev := -1
        this.definition := ""        ; the Map of cmd.flow.get as the engine sent it, "" before the first answer
        this.scene := ""             ; the Scene of the last state, "" before the definition
        this.sceneVersion := 0
        this.view := EditorView()
        this.epoch := 0
        this.lastSeq := 0            ; the seq of the last applied event or answer of this epoch
        this.engineState := EditorModel.ENGINE_WAITING
        this.flowState := EditorModel._NoFlowState()
        this.triggers := Map()       ; elementId -> Map(enabled, armed, message), the engine's trigger states
        this.run := Map()            ; elementId -> "running" (the states drawn in S0005, WI-0089 adds the others)
        this.states := Map()         ; elementId -> the last state text of evt.element.state (kept for tests and the snapshot)
        this.warnings := Map()       ; elementId -> Map(count, text), the warnings of the evaluation (drawn with WI-0089)
        this.seen := false           ; the flow was found by the engine at least once
        this.notFoundTries := 0
        this.ended := ""             ; the reason the editor ends, "" while it runs
        this.runOut := false
        this.runAgain := ""
        this.defOut := false
        this.defAgain := ""
        this.resyncCount := 0
        this.lastResync := Map("reason", "", "n", 0)
        this.eventCount := 0
        this.answerCount := 0
        this.frameCount := 0
    }

    AddListener(fn) {
        this.listeners.Push(fn)
    }

    _Notify(kind, data := "") {
        for fn in this.listeners
            fn(kind, data)
    }

    ; --- start and resync -------------------------------------------------------------------------------------------

    ; Subscribes to the topics and asks for the state. The subscriptions are kept by the peer across reconnects.
    Start() {
        this.peer.Subscribe("engine")
        this.peer.Subscribe("settings")
        this.peer.Subscribe("process")
        this.peer.Subscribe("flow:" this.flowId)
        this.Resync("start")
    }

    ; Asks the engine for the state (and the definition, unless withDefinition is false). A reason is recorded as the last resync.
    Resync(reason, withDefinition := true) {
        this.resyncCount += 1
        this.lastResync := Map("reason", reason, "n", this.resyncCount)
        this._Notify("resync", reason)
        this._AskRunstate(reason)
        if (withDefinition)
            this._AskDefinition(reason)
    }

    _AskRunstate(reason) {
        if (this.runOut) {
            this.runAgain := reason
            return
        }
        this.runOut := true
        try {
            this.peer.Request("engine", "cmd.flow.runstate", Map("flowId", this.flowId)
                , (ans) => this._OnRunstate(reason, ans), EditorModel.RUNSTATE_MS)
        } catch as e {
            this.runOut := false
            this._Retry(() => this._AskRunstate(reason), "runstate request failed: " e.Message)
        }
    }

    _AskDefinition(reason) {
        if (this.defOut) {
            this.defAgain := reason
            return
        }
        this.defOut := true
        try {
            this.peer.Request("engine", "cmd.flow.get", Map("flowId", this.flowId)
                , (ans) => this._OnDefinition(reason, ans), EditorModel.DEFINITION_MS)
        } catch as e {
            this.defOut := false
            this._Retry(() => this._AskDefinition(reason), "flow request failed: " e.Message)
        }
    }

    ; The answer of cmd.flow.runstate. Not ok: not_found ends the editor at the start (the flow does not exist), later it is
    ; asked again for a while (the engine may be loading); the other codes are asked again after RETRY_MS.
    _OnRunstate(reason, ans) {
        this.runOut := false
        this.answerCount += 1
        p := ans.payload
        if (!p.Get("ok", 0)) {
            code := EditorModel.Outcome(p)
            this.runAgain := ""        ; the retry below asks anyway
            if (code = "not_found") {
                this._SetEngine(EditorModel.ENGINE_READY)
                if (!this.seen || this.notFoundTries >= EditorModel.RETRY_LIMIT) {
                    this.Finish("not_found")
                    return
                }
                this.notFoundTries += 1
                this._Retry(() => this._AskRunstate("retry"), "flow not found yet (" this.notFoundTries ")")
                return
            }
            this._SetEngine(EditorModel.ENGINE_DOWN)
            this._Retry(() => this._AskRunstate("retry"), "runstate: " code)
            return
        }
        ep := p.Get("epoch", 0)
        sq := p.Get("seq", 0)
        if (ep < this.epoch || (ep = this.epoch && sq < this.lastSeq)) {
            ; An event newer than this answer was applied already (the answer would undo it): ask again at once.
            this.runAgain := ""
            this._AskRunstate("stale")
            return
        }
        this.epoch := ep
        this.lastSeq := sq
        this.seen := true
        this.notFoundTries := 0
        this._SetEngine(EditorModel.ENGINE_READY)
        this._ApplyRunstate(p)
        this._Changed("state")
        this._AgainRunstate()
    }

    ; The answer of cmd.flow.get: the definition, the rev and the title. A failure is asked again.
    _OnDefinition(reason, ans) {
        this.defOut := false
        p := ans.payload
        if (!p.Get("ok", 0)) {
            code := EditorModel.Outcome(p)
            this.defAgain := ""        ; the retry below asks anyway
            if (code = "not_found") {
                if (!this.seen)
                    return                ; the runstate answer ends the editor (it asks the same)
                this._Retry(() => this._AskDefinition("retry"), "definition not found yet")
                return
            }
            this._Retry(() => this._AskDefinition("retry"), "definition: " code)
            return
        }
        definition := p.Get("definition", "")
        if (!(definition is Map))
            definition := Map()
        this.rev := p.Get("rev", this.rev)
        this.definition := definition
        this.name := EditorModel.TextOf(definition, "name")
        this.view := EditorView.FromFlowSettings(definition.Get("flowSettings", ""), this.view.Dpi, this.view.Width, this.view.Height)
        this._Rebuild()
        this._Changed("flow")
        this._AgainDefinition()
    }

    _AgainRunstate() {
        if (this.runAgain = "")
            return
        reason := this.runAgain
        this.runAgain := ""
        this._AskRunstate(reason)
    }

    _AgainDefinition() {
        if (this.defAgain = "")
            return
        reason := this.defAgain
        this.defAgain := ""
        this._AskDefinition(reason)
    }

    _Retry(fn, why) {
        this._Log(why)
        if (IsObject(this.later)) {
            later := this.later          ; not this.later(...): that would pass this as the first argument (HOW-TO, callbacks)
            later(EditorModel.RETRY_MS, fn)
        }
    }

    _Log(text) {
        this._Notify("log", text)
    }

    ; Applies the answer of cmd.flow.runstate: flow state, trigger states, element states and warnings.
    _ApplyRunstate(p) {
        flow := p.Get("flow", "")
        if (flow is Map)
            this._SetFlowState(flow)
        this.triggers := Map()
        for t in p.Get("triggers", [])
            this.triggers[t["elementId"]] := EditorModel._TriggerOf(t)
        this.run := Map()
        this.states := Map()
        this.warnings := Map()
        for e in p.Get("elements", []) {
            id := e["elementId"]
            this.states[id] := e.Get("state", "")
            if (e.Get("state", "") = "running")
                this.run[id] := "running"
            if (e.Get("warnings", 0) > 0)
                this.warnings[id] := Map("count", e["warnings"], "text", e.Get("lastWarning", ""))
        }
    }

    _SetFlowState(flow) {
        this.flowState := Map("enabled", flow.Get("enabled", 0) ? 1 : 0
            , "independentActive", flow.Get("independentActive", 0), "executing", flow.Get("executing", 0) ? 1 : 0
            , "instances", flow.Get("instances", 0), "stateError", EditorModel.TextOf(flow, "stateError"))
    }

    ; The flow state before the first answer: nothing enabled, nothing running (internal 1 and 0, see the state of the model).
    static _NoFlowState() {
        st := Map()
        st["enabled"] := 0
        st["independentActive"] := 0
        st["executing"] := 0
        st["instances"] := 0
        st["stateError"] := ""
        return st
    }

    static _TriggerOf(t) => Map("enabled", t.Get("enabled", 0) ? 1 : 0, "armed", t.Get("armed", 0) ? 1 : 0
        , "message", EditorModel.TextOf(t, "message"))

    _SetEngine(state) {
        if (this.engineState = state)
            return
        this.engineState := state
        this._Notify("engine", state)
    }

    ; --- events ----------------------------------------------------------------------------------------------------

    ; Every event of the subscribed topics (not evt.settings.changed: the role takes the language from it).
    OnEvent(type, p) {
        this.eventCount += 1
        if (SubStr(type, 1, 12) = "evt.process.") {
            this._OnProcess(type, p)
            return
        }
        if (type = "evt.engine.ready" || type = "evt.engine.restarted") {
            this._Check(p)
            this.Resync(type)
            return
        }
        check := this._Check(p)
        if (check = "duplicate")
            return
        if (type = "evt.flow.list.changed") {
            if (EditorModel._Contains(p.Get("removed", []), this.flowId))
                this.Finish("deleted")
            return
        }
        if (check = "epoch")
            this.Resync("epoch", false)
        switch type {
            case "evt.flow.state":
                this._SetFlowState(p)
                this._Changed("state")
            case "evt.trigger.state":
                if (p.Get("elementId", "") != "") {
                    this.triggers[p["elementId"]] := EditorModel._TriggerOf(p)
                    this._Changed("state")
                }
            case "evt.element.state":
                this._OnElementState(p)
            case "evt.element.warning":
                this._OnWarning(p)
            case "evt.flow.committed":
                if (p.Get("rev", -1) != this.rev)
                    this._AskDefinition("committed")
        }
    }

    _OnElementState(p) {
        id := p.Get("elementId", "")
        if (id = "")
            return
        state := p.Get("state", "")
        this.states[id] := state
        if (state = "running")
            this.run[id] := "running"
        else if (this.run.Has(id))
            this.run.Delete(id)
        this._Changed("state")
    }

    _OnWarning(p) {
        id := p.Get("elementId", "")
        if (id = "")
            return
        this.warnings[id] := Map("count", p.Get("count", 0), "text", EditorModel.TextOf(p, "text"))
    }

    ; Process events of the supervisor: only the engine matters.
    _OnProcess(type, p) {
        if (p.Get("name", "") != "engine")
            return
        switch type {
            case "evt.process.crashed", "evt.process.exited", "evt.process.hung":
                this._SetEngine(EditorModel.ENGINE_DOWN)
            case "evt.process.restarted", "evt.process.ready":
                this.Resync(type)
        }
    }

    ; Checks the epoch and seq of an engine event: "" (in order, or no seq), "epoch" (a new engine process), "duplicate"
    ; (its state is in the state already: seq not above the last applied one). A gap is normal here (see the head).
    _Check(p) {
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
        this.lastSeq := sq
        return ""
    }

    ; --- the scene -------------------------------------------------------------------------------------------------

    ; The definition is new (or the view changed): the scene is built from the definition and the states.
    _Rebuild() {
        if (!(this.definition is Map))
            return
        this.sceneVersion += 1
        this.scene := SceneBuilder.Build(this.definition, this.view, this.run, this.triggers, "", "", this.sceneVersion)
    }

    ; Only the states changed: the scene shares its unchanged items (Scene.WithStates, F-0150).
    _Restate() {
        if (this.scene = "")
            return
        this.sceneVersion += 1
        this.scene := this.scene.WithStates(this.view, this.run, this.triggers, this.sceneVersion)
    }

    ; The view of a canvas of this size and DPI (the window and the headless driver call it). Only the view changes.
    SetCanvas(width, height, dpi := 96) {
        this.view := this.view.Resized(width, height, dpi)
        if (this.scene != "") {
            this.sceneVersion += 1
            this.scene := this.scene.WithStates(this.view, this.run, this.triggers, this.sceneVersion)
        }
    }

    ; The scene to draw now (Scene, "" before the definition arrived).
    CurrentScene() => this.scene   ; (a method, not Scene(): AHK property names are not case sensitive)

    _Changed(kind) {
        if (kind = "state")
            this._Restate()
        this._Notify(kind)
    }

    ; --- the end --------------------------------------------------------------------------------------------------

    ; The editor ends for this reason (planned: the role says bye clean). The first reason counts.
    Finish(reason) {
        if (this.ended != "")
            return
        this.ended := reason
        this._Notify("ended", reason)
    }

    ; --- helpers --------------------------------------------------------------------------------------------------

    ; "ok" or the error code of an answer payload.
    static Outcome(payload) {
        if (payload.Get("ok", 0))
            return "ok"
        if (payload.Has("error") && IsObject(payload["error"]))
            return payload["error"].Get("code", "?")
        return "?"
    }

    static TextOf(m, key) {
        v := m.Get(key, "")
        return IsObject(v) ? "" : String(v)
    }

    static _Contains(list, value) {
        for item in list {
            if (item = value)
                return true
        }
        return false
    }

    ; The state for the test command and the snapshot (PROTOCOL 4.11). Without the view and the frames.
    State() {
        elements := 0, connections := 0
        if (this.definition is Map) {
            elements := this.definition.Get("allElements", Map()).Count
            connections := this.definition.Get("allConnections", Map()).Count
        }
        return Map("flowId", this.flowId, "name", this.name, "rev", this.rev, "elements", elements
            , "connections", connections, "run", this.run.Clone(), "triggers", this.triggers.Clone()
            , "warnings", this.warnings.Clone(), "flowState", this.flowState.Clone(), "engine", this.engineState
            , "epoch", this.epoch, "seq", this.lastSeq, "resyncs", this.resyncCount, "lastResync", this.lastResync.Clone()
            , "ended", this.ended)
    }
}
