#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Time.ahk
#Include SceneBuilder.ahk
#Include FlowStatus.ahk
#Include EditorDraft.ahk

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
;   "view"     the view changed (ChangeView, WI-0090): the status bar and the frame follow it
class EditorModel {
    static FADE_MS := 1000           ; a tint of a finished element or of a connection fades out this long (v1)
    static FADE_TICK_MS := 33        ; the fade is drawn about 30 times per second; its timer runs only while a tint fades
    static LATENCY_KEEP := 1000      ; the frame latencies kept for the measurement (the last ones)
    static RUNSTATE_MS := 5000
    static DEFINITION_MS := 5000
    static RETRY_MS := 1000
    static RETRY_LIMIT := 30          ; not_found after the flow was seen: retries before the editor ends (the flow is gone)
    static VIEW_SAVE_MS := 2000      ; the view is written this long after its last change (E0086, WI-0096)
    static FLUSH_MS := 1000          ; the view is written when the editor closes; the bye waits at most this long
    static ENGINE_WAITING := "waiting"
    static ENGINE_READY := "ready"
    static ENGINE_DOWN := "down"

    __New(peer, flowId) {
        this.peer := peer
        this.flowId := flowId
        this.later := ""             ; fn(ms, callback): runs callback after ms (the role sets it; tests use a fake)
        this.listeners := []
        this.name := ""
        this.session := ""           ; the session of this editor (cmd.flow.patch), set by the role
        this.draft := EditorDraft(peer, flowId, this)   ; the committed definition, the queue, undo, redo, selection
        this.viewSeq := 0            ; counts the view changes: the view is written only after the last one
        this.scene := ""             ; the Scene of the last state, "" before the definition
        this.sceneVersion := 0
        this.view := EditorView()
        this.viewLoaded := false     ; the view was read from the flow settings (the first definition, F-0166)
        this.drag := ""              ; the drag of the pointer (SetDrag): Map("ids", Map, "dx", n, "dy", n, "heights", Map) or ""
        this.dragCache := ""         ; Map("base", Scene, "version", n, "scene", Scene): the last drag scene (CurrentScene)
        this.epoch := 0
        this.lastSeq := 0            ; the seq of the last applied event or answer of this epoch
        this.engineState := EditorModel.ENGINE_WAITING
        this.flowState := EditorModel._NoFlowState()
        this.triggers := Map()       ; elementId -> Map(enabled, armed, message), the engine's trigger states
        this.run := Map()            ; elementId or connectionId -> "running", "exception" or a number 0 < n <= 1 (a fade)
        this.fading := Map()         ; ID -> Time.NowMs() at the start of its fade (elements and connections, WI-0089)
        this.messages := Map()       ; elementId -> the message of the exception it ended with (for the tooltip, WI-0090)
        this.states := Map()         ; elementId -> the last state text of evt.element.state (kept for tests and the snapshot)
        this.warnings := Map()       ; elementId -> Map(count, text), the warnings of the evaluation (WI-0089)
        this.clock := ""             ; fn() -> ms for the fades and the latencies (tests set it; "" = Time.NowMs)
        this.fadeScheduled := false
        this.restateDirty := false   ; a state changed: the scene is made when it is asked for (one build per frame)
        this.pendingAt := 0          ; the time of the first change that no frame has shown yet (0 = none)
        this.latencies := []         ; ms from a change to the end of the frame that showed it (NoteFrame)
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
        if (ep != this.epoch)
            this.draft.NewEpoch()    ; a new engine process: the queue and the undo steps go (WI-0096)
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
        this.name := EditorModel.TextOf(definition, "name")
        if (!this.viewLoaded) {
            ; The view is read once, from the first definition: a later definition (a foreign change, an answer after a
            ; refusal) must not take back a zoom the user made and that is not saved yet (WI-0098, F-0166).
            this.view := EditorView.FromFlowSettings(definition.Get("flowSettings", ""), this.view.Dpi, this.view.Width
                , this.view.Height)
            this.viewLoaded := true
        }
        this.draft.Accept(definition, p.Get("rev", this.draft.rev))   ; the draft tells the model (DraftChanged)
        this._AgainDefinition()
    }

    ; The draft changed (a definition, an edit, an undo, a refusal): the scene is built again and the role follows.
    DraftChanged(kind) {
        this._Rebuild()
        this._Changed("flow")
    }

    ; The selection changed (EditorDraft.SetSelection): the scene takes it, the scene is not built again.
    SelectionChanged() {
        if (this.scene != "")
            this.scene := this.scene.WithInteraction(this.draft.selection, this.scene.Rect, this.scene.ConnectingRequest
                , this.scene.Ghost)
        this._Changed("state")
    }

    ; The IDs of the selection (an Array, in the order the selection has them).
    SelectionIds() {
        ids := []
        for id in this.draft.selection
            ids.Push(id)
        return ids
    }

    ; The drag of the pointer (WI-0098): the elements of ids move by (dx, dy) flow units and the loops of heights take the
    ; new heights; "" ends the drag. The flow does not change here: the pointer sends the patch on drop. The scene is drawn
    ; as the drag makes it (CurrentScene), at once.
    SetDrag(drag) {
        this.drag := drag
        this.sceneVersion += 1
        this._Changed("view")
    }

    ; The selection rectangle being drawn (WI-0098, a FlowRect in flow units; "" removes it). The scene takes it at once.
    SetRect(rect) {
        if (this.scene = "")
            return
        this.sceneVersion += 1
        this.scene := this.scene.WithInteraction(this.draft.selection, rect, this.scene.ConnectingRequest
            , this.scene.Ghost)
        this._Changed("view")
    }

    ; The box of the new element being placed (WI-0099, a FlowRect in flow units; "" removes it). The scene takes it at once.
    SetGhost(rect) {
        if (this.scene = "")
            return
        this.sceneVersion += 1
        this.scene := this.scene.WithInteraction(this.draft.selection, this.scene.Rect, this.scene.ConnectingRequest, rect)
        this._Changed("view")
    }

    ; Runs fn after ms through the role's timer (none in a test without one).
    Schedule(ms, fn) {
        if (IsObject(this.later)) {
            later := this.later          ; not this.later(...): that would pass this as the first argument (HOW-TO, callbacks)
            later(ms, fn)
        }
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
        flowInfo := p.Get("flow", "")
        if (flowInfo is Map)
            this._SetFlowState(flowInfo)
        this.triggers := Map()
        for t in p.Get("triggers", [])
            this.triggers[t["elementId"]] := EditorModel._TriggerOf(t)
        this.run := Map()            ; the answer is the truth: a fade of an earlier event is dropped
        this.fading := Map()
        this.messages := Map()
        this.states := Map()
        this.warnings := Map()
        for e in p.Get("elements", []) {
            id := e["elementId"]
            state := e.Get("state", "")
            this.states[id] := state
            if (state = "running") {
                this.run[id] := "running"
            } else if (state = "exception") {
                this.run[id] := "exception"
                this.messages[id] := EditorModel.TextOf(e, "message")
            }
            if (e.Get("warnings", 0) > 0)
                this.warnings[id] := Map("count", e["warnings"], "text", EditorModel.TextOf(e, "lastWarning"))
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
            if (this._Check(p) = "epoch")
                this.draft.NewEpoch()          ; a new engine process (WI-0096): the queue and the undo steps go
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
        if (check = "epoch") {
            this.draft.NewEpoch()
            this.Resync("epoch", false)
        }
        switch type {
            case "evt.flow.state":
                this._SetFlowState(p)
                this._Changed("state")
            case "evt.trigger.state":
                if (p.Get("elementId", "") != "") {
                    this.triggers[p["elementId"]] := EditorModel._TriggerOf(p)
                    this._Changed("state")
                }
            case "evt.element.states":
                ; one batch of the flow (PROTOCOL 4.3): each entry is one element, in the order the engine sent them
                for entry in p.Get("elements", [])
                    this._OnElementState(entry)
            case "evt.element.warning":
                this._OnWarning(p)
            case "evt.flow.committed":
                ; our own patch (its answer follows, or came already) is no reason to ask again (PROTOCOL 4.11)
                rev := p.Get("rev", -1)
                if (rev != this.draft.rev && !this.draft.OwnCommit(rev))
                    this._AskDefinition("committed")
        }
    }

    ; The run state of an element (v1 tint, WI-0089): running while it runs; a finished element and the connection its
    ; thread took fade out over FADE_MS; an exception keeps its own look (no fade) until the element starts again.
    _OnElementState(p) {
        id := p.Get("elementId", "")
        if (id = "")
            return
        state := p.Get("state", "")
        this.states[id] := state
        switch state {
            case "running":
                this._Unfade(id)
                if (this.messages.Has(id))
                    this.messages.Delete(id)
                this.run[id] := "running"
                connectionId := p.Get("connectionId", "")
                if (connectionId != "")
                    this._Fade(connectionId, 1)
            case "exception":
                this._Unfade(id)
                this.run[id] := "exception"
                this.messages[id] := EditorModel.TextOf(p, "message")
            case "finished":
                ; the connection of a start that ended in the same batch is tinted as well (PROTOCOL 4.11)
                connectionId := p.Get("connectionId", "")
                if (connectionId != "")
                    this._Fade(connectionId, 1)
                if (this.run.Has(id) && this.run[id] = "running")
                    this._Fade(id, 1)
                else
                    this._Unfade(id)
        }
        this._Changed("state")
    }

    ; Starts the fade of an ID at the strength given (1 = full tint) and schedules the fade timer.
    _Fade(id, strength) {
        this.run[id] := strength
        this.fading[id] := this._Now()
        this._ScheduleFade()
    }

    _Unfade(id) {
        if (this.fading.Has(id))
            this.fading.Delete(id)
        if (this.run.Has(id) && IsNumber(this.run[id]))
            this.run.Delete(id)
    }

    ; One step of the fades: the strength of each fading ID by the time since its start; a finished fade is removed.
    ; The timer is set again only while a fade is still running.
    _FadeTick() {
        this.fadeScheduled := false
        now := this._Now()
        for id, startedAt in this.fading.Clone() {
            strength := 1 - (now - startedAt) / EditorModel.FADE_MS
            if (strength <= 0)
                this._Unfade(id)
            else
                this.run[id] := strength
        }
        this._Changed("state")
        if (this.fading.Count > 0)
            this._ScheduleFade()
    }

    _ScheduleFade() {
        if (this.fadeScheduled || !IsObject(this.later))
            return
        this.fadeScheduled := true
        later := this.later          ; not this.later(...): that would pass this as the first argument (HOW-TO, callbacks)
        later(EditorModel.FADE_TICK_MS, () => this._FadeTick())
    }

    _OnWarning(p) {
        id := p.Get("elementId", "")
        if (id = "")
            return
        this.warnings[id] := Map("count", p.Get("count", 0), "text", EditorModel.TextOf(p, "text"))
        this._Changed("state")
    }

    ; The time now in ms: the clock of the test, or Time.NowMs.
    _Now() {
        if (this.clock = "")
            return Time.NowMs()
        clock := this.clock
        return clock()
    }

    ; A frame was drawn with the scene of CurrentScene: the time since the first change it shows is a latency. REQ-PRF-060:
    ; from the arrival of the event at the editor to the end of its frame (the event carries no time of the engine).
    NoteFrame() {
        if (this.pendingAt = 0)
            return
        this.latencies.Push(this._Now() - this.pendingAt)
        if (this.latencies.Length > EditorModel.LATENCY_KEEP)
            this.latencies.RemoveAt(1)
        this.pendingAt := 0
    }

    ; The latency of the frames as Map(n, medianUs, p95Us), whole microseconds (0 when there is none).
    Latency() {
        n := this.latencies.Length
        if (n = 0)
            return Map("n", 0, "medianUs", 0, "p95Us", 0)
        sorted := EditorModel._Sorted(this.latencies)
        return Map("n", n, "medianUs", Round(sorted[Max(1, Ceil(n * 0.5))] * 1000)
            , "p95Us", Round(sorted[Max(1, Ceil(n * 0.95))] * 1000))
    }

    ; A sorted copy of a list of numbers (shell sort: an Array has no Sort in AHK v2, HOW-TO objects-maps-arrays).
    static _Sorted(list) {
        out := []
        for v in list
            out.Push(v)
        gap := out.Length // 2
        while (gap > 0) {
            for i, v in out {
                if (i <= gap)
                    continue
                j := i
                while (j > gap && out[j - gap] > v) {
                    out[j] := out[j - gap]
                    j -= gap
                }
                out[j] := v
            }
            gap := gap // 2
        }
        return out
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
        root := this.draft.root
        if (!(root is Map))
            return
        this.sceneVersion += 1
        this.restateDirty := false
        rect := (this.scene != "") ? this.scene.Rect : ""          ; a rectangle being drawn survives a new definition
        ghost := (this.scene != "") ? this.scene.Ghost : ""         ; so does the box of a new element being placed
        this.scene := SceneBuilder.Build(root, this.view, this.run, this.triggers, this.warnings, ""
            , this.sceneVersion).WithInteraction(this.draft.selection, rect, "", ghost)
    }

    ; Only the states changed: the scene shares its unchanged items (Scene.WithStates, F-0150). Called by CurrentScene.
    _Restate() {
        this.restateDirty := false
        if (this.scene = "")
            return
        this.sceneVersion += 1
        this.scene := this.scene.WithStates(this.view, this.run, this.triggers, this.sceneVersion, this.warnings)
    }

    ; The view of a canvas of this size and DPI (the window and the headless driver call it). Only the view changes.
    SetCanvas(width, height, dpi := 96) {
        this.view := this.view.Resized(width, height, dpi)
        if (this.scene != "") {
            this.sceneVersion += 1
            this.restateDirty := false
            this.scene := this.scene.WithStates(this.view, this.run, this.triggers, this.sceneVersion, this.warnings)
        }
    }

    ; A new view (zoom, offset, size or DPI, from the mouse of the window or from cmd.test.view): the scene takes it at
    ; once, and the role is told (the status bar shows the view, the window asks for a frame). WI-0090.
    ChangeView(view) {
        this.view := view
        if (this.scene != "") {
            this.sceneVersion += 1
            this.restateDirty := false
            this.scene := this.scene.WithStates(this.view, this.run, this.triggers, this.sceneVersion, this.warnings)
        }
        this._ScheduleViewSave()
        this._Changed("view")
    }

    ; The view is written 2 s after its last change (E0086): the timer of an older change does nothing.
    _ScheduleViewSave() {
        this.viewSeq += 1
        seq := this.viewSeq
        this.Schedule(EditorModel.VIEW_SAVE_MS, () => this._SaveViewIf(seq))
    }

    _SaveViewIf(seq) {
        if (seq = this.viewSeq && this.ended = "")
            this.draft.SaveView(this.view)
    }

    ; The view is written now, before the editor says bye (a short wait, EditorModel.FLUSH_MS). done() is called once.
    FlushView(done) {
        this.viewSeq += 1
        state := Map("fired", false)
        finish := (ok := false) => EditorModel._Once(state, done)
        this.Schedule(EditorModel.FLUSH_MS, () => finish())
        this.draft.SaveView(this.view, finish)
    }

    static _Once(state, done) {
        if (state["fired"])
            return
        state["fired"] := true
        done()
    }

    ; The text of the status bar: the view, the number of elements, and the last refusal of the draft (if any).
    StatusText() {
        text := FlowStatus.Text(this.view, this.ElementCount(), this.draft.selection)
        if (this.draft.message != "")
            text .= FlowStatus.SEPARATOR this.draft.message
        return text
    }

    ; The scene to draw now (Scene, "" before the definition arrived). Events only mark the scene as changed: it is built
    ; here, once for all the events since the last frame (the event load, WI-0089).
    CurrentScene() {
        if (this.restateDirty)
            this._Restate()
        if (!IsObject(this.drag) || this.scene = "")
            return this.scene
        return this._DragScene()
    }

    ; The scene with the drag of the pointer, from the scene without it (Scene.WithDrag is always given the base scene).
    ; Kept while the base scene and the version stay the same (a frame and a hit test ask for it several times).
    _DragScene() {
        c := this.dragCache
        if (IsObject(c) && ObjPtr(c["base"]) = ObjPtr(this.scene) && c["version"] = this.sceneVersion)
            return c["scene"]
        sc := this.scene.WithDrag(this.drag["ids"], this.drag["dx"], this.drag["dy"], this.sceneVersion
            , this.drag["heights"])
        this.dragCache := Map("base", this.scene, "version", this.sceneVersion, "scene", sc)
        return sc
    }

    _Changed(kind) {
        if (this.pendingAt = 0)
            this.pendingAt := this._Now()
        if (kind = "state")
            this.restateDirty := true
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
    ; The number of elements of the flow (0 before the definition arrived). WI-0090: the status bar shows it.
    ElementCount() => (this.draft.root is Map) ? this.draft.root.Get("allElements", Map()).Count : 0

    ; The state as the test commands and the snapshot report it: the draft (rev of the committed revision, the counts of
    ; the draft), the selection, the stacks and the queue of patches (WI-0096).
    State() {
        elements := this.ElementCount()
        connections := 0
        if (this.draft.root is Map)
            connections := this.draft.root.Get("allConnections", Map()).Count
        selection := []
        for id in this.draft.selection
            selection.Push(id)
        return Map("flowId", this.flowId, "name", this.name, "rev", this.draft.rev, "elements", elements
            , "connections", connections, "run", this.run.Clone(), "triggers", this.triggers.Clone()
            , "warnings", this.warnings.Clone(), "messages", this.messages.Clone(), "fading", this.fading.Count
            , "flowState", this.flowState.Clone(), "engine", this.engineState
            , "epoch", this.epoch, "seq", this.lastSeq, "resyncs", this.resyncCount, "lastResync", this.lastResync.Clone()
            , "latency", this.Latency(), "ended", this.ended, "selection", selection, "undo", this.draft.undoSteps.Length
            , "redo", this.draft.redoSteps.Length, "pending", this.draft.queue.Length)
    }
}
