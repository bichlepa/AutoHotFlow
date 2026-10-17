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
;   "log"         the log window: data is "open", "close", "tail" (the answer of the tail), "entry" or "filter" (WI-0080)
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
    ; The log (WI-0080): entries kept in the model (the oldest go), and the time to wait for the answer of the tail.
    static LOG_KEEP := 1000
    static LOG_TAIL_MS := 5000
    ; WI-0074: after the user enabled a flow, its trigger messages are reported for this long (ms).
    static WATCH_MS := 30000
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
        this.selectedFlow := ""         ; the focused flow ("" = none)
        this.selectedSet := Map()       ; flowId -> true: the flows of a multi-selection (Ctrl click); empty = only selectedFlow
        this.catSelected := false       ; a category header is selected ...
        this.selectedCat := ""          ; ... with this name ("" = Uncategorized)
        this.watchPkg := Map()          ; flowId -> wall clock ms until which a trigger message is reported (WI-0074)
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
        ; The log (WI-0080): kept only while the log window is open (topic log is subscribed only then).
        this.logOpen := false
        this.logGen := 0                ; counts the openings: an answer of an older opening is ignored
        this.logEntries := []          ; Array of Map(n, ts, level, source, flowId, text), oldest first
        this.logCount := 0             ; n of the newest entry (numbers are never reused while the log is open)
        this.logSeen := 0              ; evt.log.entry received while the log is open
        this.logTailPending := false   ; the answer of cmd.storage.log.tail is still out
        this.logTailOk := false
        this.logLive := []             ; entries that came before the tail answer
        this.logLevel := "3"           ; the highest digit shown
        this.logGroup := "all"         ; "all", or the level letter: "a" app, "f" flow (E0081: no thread group)
        this.logFlowId := ""           ; "" = all flows
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
                , "enabled", f.Get("enabled", 0), "executing", f.Get("executing", 0), "instances", f.Get("instances", 0)
                , "rev", f.Get("rev", 0)
                , "independentActive", f.Get("independentActive", 0), "stateError", f.Get("stateError", "")
                , "triggers", f.Get("triggers", []), "limit", "")
            ; A flow stopped by its runaway guard keeps the mark until it is enabled again (the snapshot does not carry it).
            if (this.flows.Has(id) && this.flows[id]["limit"] != "" && !recs[id]["enabled"])
                recs[id]["limit"] := this.flows[id]["limit"]
            ids.Push(id)
        }
        this.flows := recs
        this.flowIds := ids
        this.categories := ManagerModel._CopyCategories(p.Get("categories", []))
        settings := p.Get("settings", Map())
        this.settings := IsObject(settings) ? settings : Map()
        this._PruneSelection()
        if (this.selectedFlow != "" && !recs.Has(this.selectedFlow))
            this.Select("")
        for id in ids {
            if (!this.subscribed.Has(id)) {
                this.subscribed[id] := true
                this.peer.Subscribe("flow:" id)
            }
        }
    }

    ; The messages of the triggers of a flow that are not empty (an arming error, for example a missing package).
    static _TriggerMessages(rec) {
        out := []
        for t in rec["triggers"] {
            if (t.Get("message", "") != "")
                out.Push(t["message"])
        }
        return out
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
            case "evt.flow.limit":
                id := p.Get("flowId", "")
                if (this.flows.Has(id)) {
                    this.flows[id]["limit"] := "executionsPerMinute"
                    this._Notify("flow", this.flows[id])
                }
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
        rec["instances"] := p.Get("instances", 0)
        rec["independentActive"] := p.Get("independentActive", 0)
        rec["stateError"] := p.Get("stateError", "")      ; absent: the state is known again
        if (rec["enabled"])
            rec["limit"] := ""                            ; enabled again: the limit mark goes
        this._Notify("flow", rec)
    }

    _ApplyTriggerState(p) {
        id := p.Get("flowId", "")
        if (!this.flows.Has(id))
            return
        rec := this.flows[id]
        elementId := p.Get("elementId", "")
        found := false
        for t in rec["triggers"] {
            if (t["elementId"] = elementId) {
                t["enabled"] := p.Get("enabled", 0)
                t["armed"] := p.Get("armed", 0)
                t["message"] := p.Get("message", "")
                found := true
                break
            }
        }
        if (!found)
            rec["triggers"].Push(Map("elementId", elementId, "enabled", p.Get("enabled", 0), "armed", p.Get("armed", 0)
                , "message", p.Get("message", "")))
        this._Notify("flow", rec)
        ; After the user enabled the flow: a trigger that cannot be armed (a missing package, WI-0074, REQ-MIG-070) is told.
        msg := p.Get("message", "")
        if (msg != "" && this.watchPkg.Has(id) && Time.NowMs() <= this.watchPkg[id]) {
            this.watchPkg.Delete(id)
            this.Note("manager.notice", Map("flowId", id, "elementId", elementId, "message", msg))
            this._Notify("trigger", Map("flowId", id, "elementId", elementId, "message", msg))
        }
    }

    ; The user enabled the flow: for ManagerModel.WATCH_MS a trigger message of the flow is reported as the event "trigger".
    ; The trigger host arms the triggers after the answer, so the message comes after it.
    WatchPackages(flowId) {
        this.watchPkg[flowId] := Time.NowMs() + ManagerModel.WATCH_MS
    }

    UnwatchPackages(flowId) {
        if (this.watchPkg.Has(flowId))
            this.watchPkg.Delete(flowId)
    }

    ; --- the log (WI-0080, PROTOCOL 4.8) -----------------------------------------------------------

    ; Opens the log: subscribes to topic log, asks storage for the tail and sets the flow filter (flowId "" = all flows).
    ; An open log only changes its filter. The entries that arrive before the tail answer are kept (see _OnLogTail).
    OpenLog(flowId := "") {
        this.logFlowId := flowId
        if (this.logOpen) {
            this._Notify("log", "filter")
            return
        }
        this.logOpen := true
        this.logGen += 1
        this.logEntries := []
        this.logLive := []
        this.logSeen := 0
        this.logTailOk := false
        this.logTailPending := true
        this.Note("manager.log", Map("action", "open", "flowId", flowId))
        this.peer.Subscribe("log")
        gen := this.logGen
        try {
            this.peer.Request("storage", "cmd.storage.log.tail", Map("limit", ManagerModel.LOG_KEEP)
                , (ans) => this._OnLogTail(gen, ans), ManagerModel.LOG_TAIL_MS)
        } catch as e {
            this.logTailPending := false
            this.Note("manager.error", Map("text", "log tail request failed: " Type(e) ": " e.Message))
        }
        this._Notify("log", "open")
    }

    ; Closes the log: the topic is unsubscribed and the entries are dropped (the next opening loads them again).
    CloseLog() {
        if (!this.logOpen)
            return
        this.logOpen := false
        this.logGen += 1
        this.logTailPending := false
        this.logEntries := []
        this.logLive := []
        this.peer.Unsubscribe("log")
        this.Note("manager.log", Map("action", "close"))
        this._Notify("log", "close")
    }

    ; Answer of cmd.storage.log.tail. An answer of an older opening is ignored. The tail is the older part: a live entry that
    ; equals one of its newest entries (ts, source, text) is not added a second time (a line written while the window opened).
    _OnLogTail(gen, ans) {
        if (gen != this.logGen || !this.logOpen)
            return
        this.logTailPending := false
        p := ans.payload
        tail := []
        this.logTailOk := p.Get("ok", 0) ? true : false
        if (this.logTailOk)
            tail := p.Get("entries", [])
        else
            this.Note("manager.log", Map("action", "tail", "ok", Json.False, "code", ManagerModel.Outcome(p)))
        known := Map()
        start := Max(1, tail.Length - 99)
        loop tail.Length - start + 1 {
            e := tail[start + A_Index - 1]
            known[ManagerModel._LogKey(e)] := true
        }
        for e in tail
            this._AddLogEntry(e)
        for e in this.logLive {
            if (!known.Has(ManagerModel._LogKey(e)))
                this._AddLogEntry(e)
        }
        this.logLive := []
        this.Note("manager.log", Map("action", "tail", "ok", Json.Bool(this.logTailOk), "entries", tail.Length))
        this._Notify("log", "tail")
    }

    ; An entry of topic log (evt.log.entry). Kept while the log is open; the view draws the changes in batches.
    OnLogEntry(p) {
        if (!this.logOpen)
            return
        this.logSeen += 1
        if (this.logTailPending) {
            if (this.logLive.Length < ManagerModel.LOG_KEEP)   ; more than that before the answer: the rest is dropped
                this.logLive.Push(p)
            return
        }
        this._AddLogEntry(p)
        this._Notify("log", "entry")
    }

    _AddLogEntry(e) {
        this.logCount += 1
        this.logEntries.Push(Map("n", this.logCount, "ts", e.Get("ts", ""), "level", e.Get("level", "")
            , "source", e.Get("source", ""), "flowId", e.Get("flowId", ""), "text", e.Get("text", "")))
        if (this.logEntries.Length > ManagerModel.LOG_KEEP)
            this.logEntries.RemoveAt(1, this.logEntries.Length - ManagerModel.LOG_KEEP)
    }

    static _LogKey(e) => e.Get("ts", "") "|" e.Get("source", "") "|" e.Get("text", "")

    ; Sets the filter: changes is a Map with the keys level (0 to 3), group (all, a, f) and flowId (any text, "" = all).
    ; A value outside its range is bad_payload.
    LogFilter(changes) {
        if (changes.Has("level")) {
            level := String(changes["level"])
            if (!RegExMatch(level, "^[0-3]$"))
                throw AhfError("log level must be 0 to 3 (got '" level "')", ErrCode.BAD_PAYLOAD)
            this.logLevel := level
        }
        if (changes.Has("group")) {
            group := String(changes["group"])
            if (!RegExMatch(group, "^(all|a|f)$"))
                throw AhfError("log group must be all, a or f (got '" group "')", ErrCode.BAD_PAYLOAD)
            this.logGroup := group
        }
        if (changes.Has("flowId"))
            this.logFlowId := String(changes["flowId"])
        this.Note("manager.log", Map("action", "filter", "level", this.logLevel, "group", this.logGroup, "flowId", this.logFlowId))
        this._Notify("log", "filter")
    }

    ; The entries that pass the filter, oldest first. An entry without a stored level (a line of v1) passes only at level 3.
    LogVisible() {
        out := []
        top := Integer(this.logLevel)
        for e in this.logEntries {
            level := e["level"]
            if (level = "") {
                if (top < 3 || this.logGroup != "all")
                    continue
            } else {
                if (Integer(SubStr(level, 2)) > top)
                    continue
                if (this.logGroup != "all" && SubStr(level, 1, 1) != this.logGroup)
                    continue
            }
            if (this.logFlowId != "" && e["flowId"] != this.logFlowId)
                continue
            out.Push(e)
        }
        return out
    }

    ; The log part of the state (test driver and PROTOCOL 4.8).
    LogState() {
        return Map("open", Json.Bool(this.logOpen), "entries", this.logEntries.Length, "seen", this.logSeen
            , "level", this.logLevel, "group", this.logGroup, "flowId", this.logFlowId
            , "visible", this.LogVisible().Length, "tailOk", Json.Bool(this.logTailOk))
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
        up := this.engineState != ManagerModel.ENGINE_DOWN
        flows := this.SelectedFlows().Length > 0
        one := this.selectedFlow != "" && this.flows.Has(this.selectedFlow)
        return Map("NewCategory", up, "NewFlow", up, "ChangeCategory", flows && up, "Duplicate", one && up
            , "Delete", (flows || this.catSelected) && up, "Edit", false   ; arch-ok: wire-bool UI state of the buttons, not a protocol field
            , "Enable", flows && up, "Run", flows && up
            , "Settings", false, "ImportExport", false, "About", false, "Help", false, "ShowLog", true, "Exit", true)
    }

    ; The label of the Run button for the focused flow: "Stop" while it runs, "Run" otherwise.
    RunIsStop() {
        return this.selectedFlow != "" && this.flows.Has(this.selectedFlow) && this.flows[this.selectedFlow]["executing"]
    }

    ; The label of the Enable button: "Disable" when the focused flow is enabled.
    EnableIsDisable() {
        return this.selectedFlow != "" && this.flows.Has(this.selectedFlow) && this.flows[this.selectedFlow]["enabled"]
    }

    ; Plain values of the whole state (the driver and the snapshot of the role).
    State() {
        flows := []
        for id in this.flowIds {
            rec := this.flows[id]
            flows.Push(Map("flowId", id, "name", rec["name"], "category", rec["category"]
                , "enabled", Json.Bool(rec["enabled"]), "executing", Json.Bool(rec["executing"]), "instances", rec["instances"]
                , "rev", rec["rev"]
                , "independentActive", rec["independentActive"], "stateError", rec["stateError"], "limit", rec["limit"]
                , "triggerMessages", ManagerModel._TriggerMessages(rec)))
        }
        cats := []
        for c in this.categories
            cats.Push(Map("name", c["name"], "flows", c["flows"]))
        buttons := Map()
        for name, on in this.ButtonStates()
            buttons[name] := Json.Bool(on)
        return Map("engine", this.engineState, "epoch", this.epoch, "seq", this.lastSeq, "flows", flows
            , "categories", cats, "settings", this.settings, "selectedFlow", this.selectedFlow
            , "selectedFlows", this.SelectedFlows(), "categorySelected", Json.Bool(this.catSelected)
            , "selectedCategory", this.selectedCat, "enableIsDisable", Json.Bool(this.EnableIsDisable())
            , "buttons", buttons
            , "events", this.eventCount, "resyncs", this.resyncCount, "snapshots", this.snapshotCount
            , "lastAnswer", this.lastAnswer = "" ? Map() : this.lastAnswer, "log", this.LogState())
    }

    ; --- operations ----------------------------------------------------------------------------

    ; Selects one flow (or none with ""), and drops a category selection and a multi-selection.
    Select(flowId) {
        if (flowId != "" && !this.flows.Has(flowId))
            flowId := ""
        if (flowId = this.selectedFlow && !this.catSelected && this.selectedSet.Count = 0)
            return
        this.selectedSet := Map()
        this.catSelected := false
        this.selectedCat := ""
        this.selectedFlow := flowId
        this._Notify("selection", flowId)
    }

    ; Ctrl click: adds the flow to the multi-selection or removes it. The first Ctrl click keeps the selected flow.
    SelectToggle(flowId) {
        if (!this.flows.Has(flowId))
            return
        if (this.selectedSet.Count = 0 && this.selectedFlow != "" && !this.catSelected)
            this.selectedSet[this.selectedFlow] := true
        if (this.selectedSet.Has(flowId))
            this.selectedSet.Delete(flowId)
        else
            this.selectedSet[flowId] := true
        this.selectedFlow := flowId
        this.catSelected := false
        this.selectedCat := ""
        this._Notify("selection", flowId)
    }

    ; Selects a category header (name "" = Uncategorized); the flows are not selected.
    SelectCategory(name) {
        this.selectedSet := Map()
        this.selectedFlow := ""
        this.catSelected := true
        this.selectedCat := name
        this._Notify("selection", "")
    }

    ; The flows the operations act on: the multi-selection, or the focused flow. In the order of the list.
    SelectedFlows() {
        out := []
        if (this.selectedSet.Count > 0) {
            for id in this.OrderedFlowIds()
                if (this.selectedSet.Has(id))
                    out.Push(id)
        } else if (this.selectedFlow != "" && this.flows.Has(this.selectedFlow)) {
            out.Push(this.selectedFlow)
        }
        return out
    }

    ; Drops the selected flows that a snapshot no longer has.
    _PruneSelection() {
        for id in this.selectedSet.Clone() {
            if (!this.flows.Has(id))
                this.selectedSet.Delete(id)
        }
    }

    ; The names of the categories in their order (without the uncategorized group).
    CategoryNames() {
        out := []
        for c in this.categories {
            if (c["name"] != "")
                out.Push(c["name"])
        }
        return out
    }

    ; Map name -> Array of flow IDs in their order, for every category and the uncategorized group ("").
    CategoryOrderMap() {
        out := Map()
        for id in this.OrderedFlowIds() {
            cat := this.flows[id]["category"]
            if (!out.Has(cat))
                out[cat] := []
            out[cat].Push(id)
        }
        return out
    }

    ; The names of the flows, without the flow flowId (for the name checks).
    FlowNames(exceptId := "") {
        out := []
        for id in this.flowIds {
            if (id != exceptId)
                out.Push(this.flows[id]["name"])
        }
        return out
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
