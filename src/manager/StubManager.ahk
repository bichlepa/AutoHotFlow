#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Log.ahk
#Include ..\core\Time.ahk
#Include ..\core\ipc\Deferred.ahk
#Include ..\core\Role.ahk
#Include StubGui.ahk

; Role "manager" in stub mode (WI-0013, doc/ARCHITECTURE 2.1 and 4.1, doc/PROTOCOL 4.3, 5, 5a).
; A minimal stand-in for the real manager. It shows what the engine reports and sends commands on request.
; It holds UI state only (flow list, element states, the last sequence number). The truth about the
; execution stays in the engine.
;
;   AutoHotFlow.ahk --role=manager --session=<id> --hub=<pipe> --data=<dir> --ui=stub [--headless] [--stub-cancel-exit]
;   --ui=stub           required. Without it the role ends with exit 3 (the real manager is not written yet).
;   --headless          no window. Adds cmd.test.command (driver for the tests), see doc/PROTOCOL.md 4.8.
;   --stub-cancel-exit  answers cmd.app.prepareExit with cancel 1 (tests the cancelled exit).
;
; Every engine event and every process event is written as one line through storage:
;   Log/Log_manager.txt, "... ~manager~manager~ ui-event {"type":..,"recvMs":..,"payload":{..}}"
; recvMs is the wall clock in ms (UTC, GetSystemTimePreciseAsFileTime) of the arrival at the stub.
; The stub does no file I/O itself (CONVENTIONS 3). Its own log lines come back on topic log: they are
; counted, never written again (that would be an endless loop).
;
; Resync (PROTOCOL 5, 5a): cmd.engine.snapshot after evt.engine.ready, after evt.flow.list.changed, after
; evt.process.restarted of the engine, after a new epoch, and after a gap in seq. A snapshot answer older
; than the newest event already seen is asked again ("stale"). Every request has a timeout and a callback.
class StubManager extends Role {
    static SNAPSHOT_MS := 5000
    static COMMAND_MS := 5000
    static EXIT_MS := 5000
    static RENDER_MS := 50
    ; Label of the exit button (the stub has no Lang() yet). The tray menu is the role tray's (E0075).
    static EXIT_LABEL := "Beenden"
    ; The only requests cmd.test.command may forward to the engine (test driver, headless only).
    static TEST_TYPES := Map("cmd.flow.start", 1, "cmd.flow.stop", 1, "cmd.flow.toggle", 1, "cmd.engine.snapshot", 1)

    ; Wall clock in ms since 1970 (UTC), comparable with the Python clock time.time() * 1000.
    static WallMs() {
        ft := Buffer(8, 0)
        DllCall("GetSystemTimePreciseAsFileTime", "Ptr", ft)
        return Integer(NumGet(ft, 0, "Int64") / 10000 - 11644473600000)
    }

    __New(args) {
        super.__New(args)
        this.headless := args.Has("headless")
        this.cancelExit := args.Has("stub-cancel-exit")
        this.epoch := 0
        this.lastSeq := 0
        this.flowRecs := Map()        ; flowId -> Map(name, enabled, executing, rev)
        this.flowIds := []            ; flow ids in the order of the last snapshot
        this.elementRecs := Map()     ; flowId -> Map(elementId -> Map(state, countRuns, lastRun, message))
        this.flowTopics := Map()      ; flowIds whose topic flow:<id> is subscribed
        this.logEchoCount := 0
        this.resyncCount := 0
        this.eventCount := 0
        this.view := ""               ; StubGui, only without --headless
        this.dirty := false           ; something changed since the last render
        this.selectedFlow := ""
        this.lastCommandMs := -1
        this.lastResult := ""
        this.renderFn := () => this._Render()
        this.uiQueue := []            ; ui-event lines not yet sent to storage
        this.uiScheduled := false
        this.uiFlushFn := () => this._FlushUi()
    }

    ; --- lifecycle -----------------------------------------------------------------------------

    Start() {
        if (this.args.Get("ui", "") != "stub") {
            Role.Console("a0", "manager", "no UI selected: start with --ui=stub (the real manager is not written yet)")
            ExitApp(Role.EXIT_NOT_IMPLEMENTED)
        }
        super.Start()
        if (!this.headless) {
            this.view := StubGui(this)
            SetTimer(this.renderFn, StubManager.RENDER_MS)
        }
    }

    RegisterHandlers() {
        this.On("evt.", (msg) => this._OnEvent(msg))
        this.On("cmd.app.prepareExit", (msg) => this._OnPrepareExit(msg))
        this.On("cmd.manager.show", (msg) => this._OnShow(msg))
        if (this.headless)
            this.On("cmd.test.command", (msg) => this._OnTestCommand(msg))
        ; Subscriptions are kept by the peer and sent again after every handshake (PROTOCOL 3).
        this.peer.Subscribe("engine")
        this.peer.Subscribe("process")
        this.peer.Subscribe("log")
    }

    OnReady() {
        this.SetLogTarget("storage")
        this._Ui("stub.ready", Map("headless", this.headless ? 1 : 0))
        this._RequestSnapshot("ready")
    }

    ; Role part of the snapshot (doc/PROTOCOL.md 4.9): subscriptions, sequence state and counters.
    DiagInfo() {
        return Map("topics", this.peer.Topics(), "epoch", this.epoch, "lastSeq", this.lastSeq
            , "flows", this.flowRecs.Count, "events", this.eventCount, "resyncs", this.resyncCount)
    }

    OnShutdown(deadlineMs) {
        this._Ui("stub.shutdown", Map("deadlineMs", deadlineMs))
        this._FlushUi()
        SetTimer(this.uiFlushFn, 0)
        SetTimer(this.renderFn, 0)
        if (IsObject(this.view)) {
            this.view.Close()
            this.view := ""
        }
    }

    ; --- events --------------------------------------------------------------------------------

    _OnEvent(msg) {
        t := msg.type
        if (SubStr(t, 1, 8) = "evt.log.") {
            this.logEchoCount += 1
            return
        }
        this.eventCount += 1
        this._Ui(t, msg.payload)
        p := msg.payload
        check := this._CheckSequence(p)
        if (check = "duplicate")
            return
        this.dirty := true
        reason := ""
        if (check = "epoch" || check = "gap")
            reason := check
        if (t = "evt.engine.ready" || t = "evt.flow.list.changed")
            reason := t
        if (t = "evt.process.restarted" && p.Get("name", "") = "engine")
            reason := t
        if (reason != "")
            this._RequestSnapshot(reason)
        if (t = "evt.flow.state")
            this._ApplyFlowState(p)
        else if (t = "evt.element.state")
            this._ApplyElementState(p)
    }

    ; Checks epoch and seq of an engine event (PROTOCOL 4.3). Returns "" (in order), "epoch" (new engine
    ; process), "gap" (events were missed), "duplicate" (already seen), or "" for events without seq.
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
        if (!this.flowRecs.Has(id)) {
            this._RequestSnapshot("flow.state of unknown flow " id)
            return
        }
        rec := this.flowRecs[id]
        rec["enabled"] := p.Get("enabled", 0)
        rec["executing"] := p.Get("executing", 0)
    }

    _ApplyElementState(p) {
        flowId := p.Get("flowId", "")
        elementId := p.Get("elementId", "")
        if (!this.elementRecs.Has(flowId))
            this.elementRecs[flowId] := Map()
        this.elementRecs[flowId][elementId] := Map("state", p.Get("state", ""), "countRuns", p.Get("countRuns", 0)
            , "lastRun", p.Get("lastRun", ""), "message", p.Get("message", ""))
    }

    ; --- resync --------------------------------------------------------------------------------

    _RequestSnapshot(reason) {
        this.resyncCount += 1
        try {
            this.peer.Request("engine", "cmd.engine.snapshot", Map(), (ans) => this._OnSnapshot(reason, ans)
                , StubManager.SNAPSHOT_MS)
        } catch as e {
            this._Ui("stub.error", Map("text", "snapshot request failed: " Type(e) ": " e.Message))
        }
    }

    ; Callback of cmd.engine.snapshot. Called exactly once (answer or timeout). A failure (for example
    ; not_found while the engine is down) changes nothing: the next engine event asks again.
    _OnSnapshot(reason, ans) {
        p := ans.payload
        if (!p.Get("ok", 0)) {
            code := ""
            if (p.Has("error") && IsObject(p["error"]))
                code := p["error"].Get("code", "")
            this._Ui("stub.snapshot", Map("reason", reason, "ok", Json.False, "code", code))
            return
        }
        ep := p.Get("epoch", 0)
        sq := p.Get("seq", 0)
        if (ep = this.epoch && sq < this.lastSeq) {
            ; Events newer than this answer were already applied: the answer would undo them. Ask again.
            this._RequestSnapshot("stale")
            return
        }
        this.epoch := ep
        this.lastSeq := sq
        recs := Map()
        idList := []
        for f in p.Get("flows", []) {
            id := f["flowId"]
            recs[id] := Map("name", f.Get("name", ""), "enabled", f.Get("enabled", 0)
                , "executing", f.Get("executing", 0), "rev", f.Get("rev", 0))
            idList.Push(id)
        }
        this.flowRecs := recs
        this.flowIds := idList
        for id, _ in this.elementRecs.Clone()
            if (!recs.Has(id))
                this.elementRecs.Delete(id)
        for id in idList {
            if (!this.flowTopics.Has(id)) {
                this.flowTopics[id] := true
                this.peer.Subscribe("flow:" id)
            }
        }
        this._Ui("stub.snapshot", Map("reason", reason, "ok", Json.True, "epoch", ep, "seq", sq, "flows", idList.Length))
        this.dirty := true
    }

    ; --- commands from the test driver (headless only) --------------------------------------

    ; cmd.test.command {type, payload}: forwards one allowed request to the engine and answers with its
    ; answer in "answer". Deferred: the answer comes when the engine has answered (or its timeout ended).
    _OnTestCommand(msg) {
        t := msg.payload.Get("type", "")
        if (!StubManager.TEST_TYPES.Has(t))
            throw AhfError("cmd.test.command: type '" t "' is not allowed", ErrCode.BAD_PAYLOAD)
        inner := msg.payload.Get("payload", Map())
        if (!IsObject(inner))
            throw AhfError("cmd.test.command: payload must be an object", ErrCode.BAD_PAYLOAD)
        this._Ui("stub.command", Map("type", t))
        this.peer.Request("engine", t, inner, (ans) => this._OnTestAnswer(msg, t, ans), StubManager.COMMAND_MS)
        return Deferred.Marker()
    }

    _OnTestAnswer(request, t, ans) {
        this._Ui("stub.commandAnswer", Map("type", t, "ok", Json.Bool(ans.payload.Get("ok", 0))))
        this.peer.Reply(request, Map("ok", true, "answer", StubManager._WireAnswer(ans.payload)))
    }

    ; The answer of the engine as it is passed on to the test client: Json.Parse read true/false as 1/0, so the
    ; truth fields of the protocol are turned back into Json.True/Json.False (a copy, at any depth).
    static _WireAnswer(node) {
        static boolFields := "|ok|cancel|started|clean|restart|enabled|executing|exists|existed|waiting|byMeta|delete|"
        if (node is Map) {
            out := Map()
            out.CaseSense := node.CaseSense
            for key, value in node
                out[key] := (InStr(boolFields, "|" key "|") && IsNumber(value)) ? Json.Bool(value) : StubManager._WireAnswer(value)
            return out
        }
        if (node is Array) {
            out := []
            for item in node
                out.Push(StubManager._WireAnswer(item))
            return out
        }
        return node
    }

    ; --- window actions (called by StubGui; every request has a callback and a timeout) ----------

    SelectFlow(flowId) {
        this.selectedFlow := flowId
        this.dirty := true
    }

    UserStart(flowId) {
        this._UserCommand("cmd.flow.start", flowId)
    }

    UserStop(flowId) {
        this._UserCommand("cmd.flow.stop", flowId)
    }

    UserExit() {
        t0 := Time.NowMs()
        try {
            this.peer.Request("supervisor", "cmd.app.exit", Map(), (ans) => this._OnUserExit(t0, ans)
                , StubManager.EXIT_MS)
        } catch as e {
            this.lastResult := "Beenden nicht gesendet: " e.Message
            this.dirty := true
        }
    }

    _UserCommand(type, flowId) {
        if (flowId = "") {
            this.lastResult := "kein Flow gewaehlt"
            this.dirty := true
            return
        }
        t0 := Time.NowMs()
        try {
            this.peer.Request("engine", type, Map("flowId", flowId), (ans) => this._OnUserCommand(type, flowId, t0, ans)
                , StubManager.COMMAND_MS)
        } catch as e {
            this.lastResult := type " nicht gesendet: " e.Message
            this.dirty := true
        }
    }

    _OnUserCommand(type, flowId, t0, ans) {
        this.lastCommandMs := Integer(Time.NowMs() - t0)
        this.lastResult := type " " flowId ": " StubManager._Outcome(ans.payload)
        this.dirty := true
    }

    _OnUserExit(t0, ans) {
        this.lastCommandMs := Integer(Time.NowMs() - t0)
        this.lastResult := "cmd.app.exit: " StubManager._Outcome(ans.payload)
        this.dirty := true
    }

    ; "ok" or the error code of an answer payload.
    static _Outcome(payload) {
        if (payload.Get("ok", 0))
            return "ok"
        code := "?"
        if (payload.Has("error") && IsObject(payload["error"]))
            code := payload["error"].Get("code", "?")
        return "Fehler " code
    }

    ; Model for the window: plain values only, built from the state above.
    ViewModel() {
        flows := []
        for id in this.flowIds {
            rec := this.flowRecs[id]
            flows.Push(Map("flowId", id, "name", rec["name"], "enabled", rec["enabled"]
                , "executing", rec["executing"], "rev", rec["rev"]))
        }
        elements := []
        if (this.elementRecs.Has(this.selectedFlow)) {
            for elementId, rec in this.elementRecs[this.selectedFlow]
                elements.Push(Map("elementId", elementId, "state", rec["state"], "countRuns", rec["countRuns"]
                    , "lastRun", rec["lastRun"], "message", rec["message"]))
        }
        return Map("flows", flows, "elements", elements, "selectedFlow", this.selectedFlow
            , "conn", this.peer.status, "epoch", this.epoch, "seq", this.lastSeq, "events", this.eventCount
            , "resyncs", this.resyncCount, "latencyMs", this.lastCommandMs, "lastResult", this.lastResult)
    }

    ; Timer, 20 Hz. Draws only when something changed; a burst of events becomes one redraw.
    _Render() {
        if (!this.dirty || !IsObject(this.view))
            return
        this.dirty := false
        this.view.Render(this.ViewModel())
    }

    ; --- exit ----------------------------------------------------------------------------------

    _OnPrepareExit(msg) {
        this._Ui("stub.prepareExit", Map("cancel", Json.Bool(this.cancelExit)))
        return Map("ok", true, "cancel", Json.Bool(this.cancelExit))
    }

    ; cmd.manager.show (F-0074, PROTOCOL 4.8): a second start of the product. Shows the window and brings it to the front.
    ; Without a window (--headless) only the ui-event line is written.
    _OnShow(msg) {
        this._Ui("stub.show", Map("headless", this.headless ? 1 : 0))
        if (IsObject(this.view))
            this.view.Raise()
        return Map("ok", true)
    }

    ; --- log -----------------------------------------------------------------------------------

    ; One line per event, written through storage (Role log sink). The line is JSON after "ui-event ".
    ; The line is only queued here and sent by a timer, never inside the frame handler that received
    ; the event: sending from the handler lost events under parallel load (WI-0013 findings, HOW-TO).
    _Ui(type, payload) {
        line := Json.Stringify(Map("type", type, "recvMs", StubManager.WallMs(), "payload", payload))
        this.uiQueue.Push(line)
        if (!this.uiScheduled) {
            this.uiScheduled := true
            SetTimer(this.uiFlushFn, -1)
        }
    }

    _FlushUi() {
        this.uiScheduled := false
        lines := this.uiQueue
        this.uiQueue := []
        for line in lines
            Log.Write("a1", "manager", "ui-event " line)
    }
}
