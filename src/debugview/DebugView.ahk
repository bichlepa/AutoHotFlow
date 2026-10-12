#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Log.ahk
#Include ..\core\Time.ahk
#Include ..\core\Role.ahk
#Include DebugGui.ahk

; Role "debug": the debug window (WI-28, doc/ARCHITEKTUR 3, doc/PROTOKOLL 4.9). It shows the internals of the running
; system: the process table, the snapshot of every role, the live log (level and source filter), the stream of engine and
; process events (with a pause), the values that code sends with Debug.Dump, and a button that writes a diagnostic
; report. It reads and shows only; it changes nothing in the other roles (not a flow debugger, E1).
;
;   AutoHotFlow.ahk --role=debug --session=<id> --hub=<pipe> --data=<dir> [--headless]
;   started by --start=debug or by a second instance:  AutoHotFlow.ahk --command=debug  (cmd.app.command)
;
; Like the manager stub: never modal, no MsgBox, no file access. The model (this class) holds all state; DebugGui is a
; view that is drawn from it at most 10 times per second and only after a change. --headless runs without a window and
; adds the test command cmd.test.debug (PROTOKOLL 4.9). Closing the window ends only this role (CloseWindow).
;
; Every request has a timeout and a callback. Received events are only stored (a ring each); nothing is logged per
; event, so the log that this window shows cannot feed itself.
class DebugView extends Role {
    static TOPICS := ["process", "log", "engine", "debug"]
    static LOG_MAX := 2000
    static EVENT_MAX := 1000
    static DUMP_MAX := 200
    static LIST_MS := 3000
    static SNAPSHOT_MS := 3000
    static ENGINE_MS := 5000
    static REPORT_MS := 20000
    static AUTO_REFRESH_MS := 2000
    static RENDER_MS := 100
    static LIST_DEBOUNCE_MS := 100

    __New(args) {
        super.__New(args)
        this.headless := args.Has("headless")
        this.gui := ""
        this.processes := Map()        ; name -> Map(name, role, state, pid, restarts), from cmd.process.list
        this.processNames := []        ; names in table order
        this.snapshots := Map()        ; name -> Map(text, at)  (text: formatted JSON, or an error text)
        this.logEntries := []          ; Maps: ts, level, source, text
        this.logLevel := 3             ; highest level digit shown
        this.logSource := ""           ; shown when the source contains this text (case-insensitive)
        this.events := []              ; Maps: n, ts, type, payload, text ("" until shown)
        this.eventN := 0
        this.paused := false
        this.pausedAtN := 0
        this.dumps := []               ; Maps: ts, from, title, json
        this.lastExport := ""
        this.autoRefresh := false
        this.flowTopics := Map()
        this.rev := Map("proc", 0, "snap", 0, "log", 0, "event", 0, "dump", 0, "status", 0)
        this.dirty := false
        this.listPending := false
        this.listFn := () => this._RequestList()
        this.renderFn := () => this._Render()
        this.autoFn := () => this.RefreshSnapshots()
    }

    ; --- lifecycle -----------------------------------------------------------------------------

    Start() {
        super.Start()
        if (!this.headless) {
            this.gui := DebugGui(this)
            SetTimer(this.renderFn, DebugView.RENDER_MS)
        }
    }

    RegisterHandlers() {
        this.On("evt.", (msg) => this._OnEvent(msg))
        if (this.headless)
            this.On("cmd.test.debug", (msg) => this._OnTestCommand(msg))
        ; The subscriptions are kept by the peer and sent again after every handshake (PROTOKOLL 3).
        for topic in DebugView.TOPICS
            this.peer.Subscribe(topic)
    }

    OnReady() {
        this.SetLogTarget("storage")
        this._RequestList()
        this._RequestEngine()
    }

    OnShutdown(deadlineMs) {
        SetTimer(this.renderFn, 0)
        SetTimer(this.autoFn, 0)
        if (IsObject(this.gui)) {
            this.gui.Close()
            this.gui := ""
        }
    }

    ; Role part of the snapshot (PROTOKOLL 4.9).
    DiagInfo() {
        names := []
        for name, _ in this.snapshots
            names.Push(name)
        dumpTitles := []
        for d in this.dumps
            dumpTitles.Push(d["title"])
        return Map("topics", this.peer.Topics(), "processes", this.processNames.Clone(), "snapshots", names
            , "logEntries", this.logEntries.Length, "engineEvents", this.events.Length, "dumps", dumpTitles
            , "paused", Json.Bool(this.paused))
    }

    ; The window was closed by the user: only this role ends, with a clean goodbye (the supervisor then reports a
    ; normal exit, not a crash). Called from the GUI.
    CloseWindow() {
        this.gui := ""
        SetTimer(this.renderFn, 0)
        SetTimer(Role.ByeFn, -1)
    }

    ; --- events ----------------------------------------------------------------------------------

    _OnEvent(msg) {
        t := msg.type
        if (t = "evt.log.entry") {
            this._AddLog(msg.payload)
            return
        }
        if (t = "evt.debug.dump") {
            this._AddDump(msg)
            return
        }
        if (t = "evt.debug.show") {
            if (IsObject(this.gui))
                this.gui.Raise()
            return
        }
        if (SubStr(t, 1, 12) = "evt.process.") {
            this._AddEvent(msg)
            this._AskForList()
            return
        }
        this._AddEvent(msg)
        if (t = "evt.engine.ready" || t = "evt.flow.list.changed" || t = "evt.engine.restarted")
            this._RequestEngine()
    }

    _AddLog(p) {
        this.logEntries.Push(Map("ts", p.Get("ts", ""), "level", p.Get("level", ""), "source", p.Get("source", "")
            , "text", p.Get("text", "")))
        if (this.logEntries.Length > DebugView.LOG_MAX + 100)
            this.logEntries.RemoveAt(1, 100)
        this._Changed("log")
    }

    _AddEvent(msg) {
        this.eventN += 1
        this.events.Push(Map("n", this.eventN, "ts", FormatTime(A_Now, "HH:mm:ss") "." Format("{:03}", A_MSec)
            , "type", msg.type, "payload", msg.payload, "text", ""))
        if (this.events.Length > DebugView.EVENT_MAX + 100)
            this.events.RemoveAt(1, 100)
        this._Changed("event")
    }

    _AddDump(msg) {
        p := msg.payload
        this.dumps.Push(Map("ts", p.Get("ts", ""), "from", msg.from, "title", String(p.Get("title", ""))
            , "json", String(p.Get("json", ""))))
        if (this.dumps.Length > DebugView.DUMP_MAX)
            this.dumps.RemoveAt(1)
        this._Changed("dump")
    }

    _Changed(section) {
        this.rev[section] += 1
        this.dirty := true
    }

    ; --- process table and engine flows ---------------------------------------------------------------

    ; Several process events in a row ask for the table once.
    _AskForList() {
        if (this.listPending)
            return
        this.listPending := true
        SetTimer(this.listFn, -DebugView.LIST_DEBOUNCE_MS)
    }

    _RequestList() {
        this.listPending := false
        try {
            this.peer.Request("supervisor", "cmd.process.list", Map(), (ans) => this._OnList(ans), DebugView.LIST_MS)
        } catch as e {
            this._Status("process list not requested: " e.Message)
        }
    }

    _OnList(ans) {
        if (!ans.payload.Get("ok", false))
            return
        procs := Map()
        names := []
        for p in ans.payload.Get("processes", []) {
            procs[p["name"]] := p
            names.Push(p["name"])
        }
        this.processes := procs
        this.processNames := names
        this._Changed("proc")
    }

    ; The flow topics follow the engine's flow list (like the manager stub): ask for the snapshot, subscribe to new flows.
    _RequestEngine() {
        try {
            this.peer.Request("engine", "cmd.engine.snapshot", Map(), (ans) => this._OnEngine(ans), DebugView.ENGINE_MS)
        } catch as e {
            this._Status("engine snapshot not requested: " e.Message)
        }
    }

    _OnEngine(ans) {
        if (!ans.payload.Get("ok", false))
            return                                  ; no engine (yet): the next engine event asks again
        for f in ans.payload.Get("flows", []) {
            id := f["flowId"]
            if (!this.flowTopics.Has(id)) {
                this.flowTopics[id] := true
                this.peer.Subscribe("flow:" id)
            }
        }
    }

    ; --- snapshots -------------------------------------------------------------------------------------

    ; Asks every ready process (and the supervisor) for its snapshot. onDone(count) is called once when all answers or
    ; deadlines are in; count = number of snapshots stored.
    RefreshSnapshots(onDone := "") {
        names := ["supervisor"]
        for name, p in this.processes
            if (p["state"] = "ready")
                names.Push(name)
        st := Map("open", names.Length, "stored", 0, "onDone", onDone)
        for name in names {
            try {
                this.peer.Request(name, "cmd.diag.snapshot", Map(), ObjBindMethod(this, "_OnSnapshot", st, name), DebugView.SNAPSHOT_MS)
            } catch as e {
                this._StoreSnapshot(name, "not requested: " e.Message)
                st["open"] -= 1
            }
        }
        if (st["open"] <= 0)
            this._SnapshotsDone(st)
        return names.Length
    }

    _OnSnapshot(st, name, ans) {
        p := ans.payload
        if (p.Get("ok", false) && p.Get("snapshot", "") is Map) {
            this._StoreSnapshot(name, Json.Stringify(p["snapshot"], 2))
            st["stored"] += 1
        } else {
            err := p.Get("error", "")
            this._StoreSnapshot(name, "no snapshot: " ((err is Map) ? err.Get("code", "") ": " err.Get("message", "") : "no answer"))
        }
        st["open"] -= 1
        if (st["open"] <= 0)
            this._SnapshotsDone(st)
    }

    _SnapshotsDone(st) {
        fn := st["onDone"]
        st["onDone"] := ""
        if (IsObject(fn))
            fn(st["stored"])
    }

    _StoreSnapshot(name, text) {
        this.snapshots[name] := Map("text", text, "at", FormatTime(A_Now, "HH:mm:ss"))
        this._Changed("snap")
    }

    ; "alle 2 s" checkbox of the window.
    SetAutoRefresh(on) {
        this.autoRefresh := on ? true : false
        SetTimer(this.autoFn, this.autoRefresh ? DebugView.AUTO_REFRESH_MS : 0)
        if (this.autoRefresh)
            this.RefreshSnapshots()
    }

    ; --- report ------------------------------------------------------------------------------------------

    ; "Bericht exportieren": a manual report through the supervisor. onDone(payload) when the answer is there.
    Export(onDone := "") {
        this._Status("report requested ...")
        try {
            this.peer.Request("supervisor", "cmd.diag.report", Map("reason", "manual"), ObjBindMethod(this, "_OnExport", onDone)
                , DebugView.REPORT_MS)
        } catch as e {
            this._Status("report not requested: " e.Message)
        }
    }

    _OnExport(onDone, ans) {
        p := ans.payload
        if (p.Get("ok", false)) {
            this._Status("report written: " p.Get("dir", p.Get("path", "")) (p["missing"].Length ? "  (" p["missing"].Length " role(s) without snapshot)" : ""))
        } else {
            err := p.Get("error", "")
            this._Status("report failed: " ((err is Map) ? err.Get("code", "") ": " err.Get("message", "") : "no answer"))
        }
        if (IsObject(onDone))
            onDone(p)
    }

    _Status(text) {
        this.lastExport := text
        this._Changed("status")
    }

    ; --- views on the model ------------------------------------------------------------------------------

    ; The log entries that pass the filter, the newest `limit` of them (oldest first).
    VisibleLog(limit := 500) {
        out := []
        i := this.logEntries.Length
        while (i >= 1 && out.Length < limit) {
            e := this.logEntries[i]
            i -= 1
            digit := Integer(SubStr(e["level"], 2, 1) = "" ? 0 : SubStr(e["level"], 2, 1))
            if (digit > this.logLevel)
                continue
            if (this.logSource != "" && !InStr(e["source"], this.logSource))
                continue
            out.InsertAt(1, e)
        }
        return out
    }

    SetLogFilter(levelDigit, source) {
        this.logLevel := (IsInteger(levelDigit) && levelDigit >= 0 && levelDigit <= 3) ? Integer(levelDigit) : 3
        this.logSource := String(source)
        this._Changed("log")
    }

    ; The events shown now: all, or up to the last one that was there when "Pause" was pressed.
    VisibleEvents(limit := 300) {
        out := []
        i := this.events.Length
        while (i >= 1 && out.Length < limit) {
            e := this.events[i]
            i -= 1
            if (this.paused && e["n"] > this.pausedAtN)
                continue
            out.InsertAt(1, e)
        }
        return out
    }

    ; The text of an event for the list (compact JSON of the payload, cached in the entry).
    EventText(e) {
        if (e["text"] = "") {
            try {
                text := Json.Stringify(e["payload"])
            } catch {
                text := "(payload cannot be shown)"
            }
            e["text"] := (StrLen(text) > 300) ? SubStr(text, 1, 300) "..." : text
        }
        return e["text"]
    }

    SetPaused(on) {
        this.paused := on ? true : false
        this.pausedAtN := this.eventN
        this._Changed("event")
    }

    ; --- window ------------------------------------------------------------------------------------------

    ; Draws at most 10 times per second and only after a change.
    _Render() {
        if (!this.dirty || !IsObject(this.gui))
            return
        this.dirty := false
        this.gui.Render()
    }

    ; --- test command (headless only) -----------------------------------------------------------------

    ; cmd.test.debug {action}: state | refresh | export | pause | resume | filter {level, source} | snapshot {name} | close.
    _OnTestCommand(msg) {
        p := msg.payload
        action := p.Get("action", "")
        if (action = "state")
            return this._State()
        if (action = "pause" || action = "resume") {
            this.SetPaused(action = "pause")
            return this._State()
        }
        if (action = "filter") {
            this.SetLogFilter(p.Get("level", 3), p.Get("source", ""))
            return this._State()
        }
        if (action = "close") {
            ; the same path as the user closing the window: only this role ends, with a clean goodbye
            this.CloseWindow()
            return Map()
        }
        if (action = "snapshot") {
            name := p.Get("name", "")
            if (!this.snapshots.Has(name))
                throw AhfError("no snapshot of '" name "'", ErrCode.NOT_FOUND)
            return Map("text", this.snapshots[name]["text"])
        }
        if (action = "refresh") {
            this.RefreshSnapshots((count) => this._ReplyState(msg, Map("refreshed", count)))
            return Deferred.Marker()
        }
        if (action = "export") {
            this.Export((payload) => this._ReplyState(msg, Map("export", DebugView._WireReport(payload))))
            return Deferred.Marker()
        }
        throw AhfError("cmd.test.debug: unknown action '" action "'", ErrCode.BAD_PAYLOAD)
    }

    ; The answer of cmd.diag.report as it is passed on in a test answer: Json.Parse read "ok" as 1/0, so the truth
    ; field is turned back into Json.True/Json.False (PROTOKOLL 2, a copy of the fields the test looks at).
    static _WireReport(p) {
        out := Map("ok", Json.Bool(p.Get("ok", false)))
        for key in ["path", "dir", "roles", "missing", "error"]
            if (p.Has(key))
                out[key] := p[key]
        return out
    }

    _ReplyState(request, extra) {
        state := this._State()
        for key, value in extra
            state[key] := value
        this.peer.Reply(request, state)
    }

    _State() {
        snapNames := []
        for name, _ in this.snapshots
            snapNames.Push(name)
        titles := []
        for d in this.dumps
            titles.Push(d["title"])
        return Map("processes", this.processNames.Clone(), "snapshots", snapNames, "logEntries", this.logEntries.Length
            , "logVisible", this.VisibleLog(DebugView.LOG_MAX).Length, "engineEvents", this.events.Length
            , "eventsVisible", this.VisibleEvents(DebugView.EVENT_MAX).Length, "dumps", titles
            , "paused", Json.Bool(this.paused), "lastExport", this.lastExport, "topics", this.peer.Topics())
    }
}
