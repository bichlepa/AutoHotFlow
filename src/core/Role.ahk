#Requires AutoHotkey v2.0
#Include Errors.ahk
#Include Log.ahk
#Include Time.ahk
#Include Args.ahk
#Include ipc\Peer.ahk

; Base class of every role process (doc/ARCHITEKTUR.md 3 and 6, doc/PROTOCOL.md 4.1 and 5).
; A role is started by src/AutoHotFlow.ahk with the command line of work_items/phase2/README.md:
;   --role=<name> --session=<id> --hub=<pipe> --data=<dir> [--flow=<flowId>] [--hubHwnd=<n>] [--log-level=<0..3>]
;
; Subclasses override the hooks and register their own message handlers:
;
;   class MyRole extends Role {
;       RegisterHandlers() => this.On("cmd.my.", (msg) => Map("ok", true))   ; before Connect
;       OnReady() { ... }                  ; after every successful handshake
;       OnShutdown(deadlineMs) { ... }     ; sys.shutdown: clean up, sys.bye follows
;       OnPeerLost() { ... }               ; hub connection lost (retry in progress)
;       OnUnexpectedError(e, mode) { ... } ; default: log and keep running, return 1
;   }
;
; Standard handlers: sys.ping/sys.pong live in Peer. sys.shutdown is handled here: OnShutdown,
; then sys.bye {clean:true} to the supervisor, then Peer.Close and ExitApp(0), in the next timer tick.
; Orphan guard: when the hub connection is lost and not restored within ORPHAN_MS, the role
; ends with EXIT_HUB_LOST. The peer's own retry budget (reconnectTotalMs) is the backstop.
;
; Process-wide state: exactly one role per process. Role.Current is the running role; the static
; callbacks (OnError, Log sink, peer callbacks, timers) reach it through that.
; Callbacks are function properties, not static methods (doc/HOW-TO.md, "Statische Methode ist kein Callback").
class Role {
    static EXIT_OK := 0
    static EXIT_BAD_ARGS := 2
    static EXIT_NOT_IMPLEMENTED := 3
    static EXIT_HUB_LOST := 4
    static EXIT_TOO_MANY_ERRORS := 6
    static ORPHAN_MS := 3000
    static GUARD_MS := 200
    static LOG_QUEUE_MAX := 500
    ; More than ERROR_LIMIT unhandled errors within ERROR_WINDOW_MS end the role with EXIT_TOO_MANY_ERRORS (WI-23).
    ; 20 in a minute is generous: a healthy role has none, one broken element or timer may throw a few times in a
    ; row, but 21 means the state is broken and a restart (engine, storage: Children restart rule) is better than
    ; a zombie. The window keeps rare errors over a long life from adding up.
    static ERROR_LIMIT := 20
    static ERROR_WINDOW_MS := 60000
    static MAX_STACK_CHARS := 4000
    static Current := ""

    ; Console sink for the entry point and the last messages of a role. Writes to stderr only,
    ; no file (the one exception to KONVENTIONEN section 3, see doc/HOW-TO.md). Call it as
    ; Role.Console(...); ConsoleFn is only the function value for Log.Configure, because a
    ; function stored in a property receives the class as first argument when called as Role.ConsoleFn(...).
    ; A role started by the supervisor has stdout and stderr in an anonymous pipe (WI-23, ChildLauncher): what
    ; it writes here is read by the supervisor and ends up in the log. Without a usable stderr (a role started
    ; by hand without a console) FileAppend throws; the console is best effort and must never keep a role from
    ; ending (orphan guard, WI-15, F-05).
    static Console(level, source, text) {
        try {
            FileAppend(level " " source ": " text "`n", "**", "UTF-8-RAW")
        } catch {
            ; best effort: no usable stderr (see above)
        }
    }
    static ConsoleFn := (level, source, text, flowId := "") => Role.Console(level, source, text)
    static LogSinkFn := (level, source, text, flowId := "") => Role._LogSink(level, source, text, flowId)
    static ErrorFn := (e, mode) => Role._OnUnexpected(e, mode)
    static ShutdownFn := (msg) => Role.Current._OnShutdown(msg)
    static PeerReadyFn := () => Role.Current._OnPeerReady()
    static PeerClosedFn := () => Role.Current._OnPeerClosed()
    static GuardFn := () => Role.Current._Guard()
    static ByeFn := () => Role.Current._FinishShutdown()

    __New(args) {
        this.args := args
        this.roleName := args.Get("role", "supervisor")
        this.flowId := args.Get("flow", "")
        this.name := (this.flowId = "") ? this.roleName : this.roleName ":" this.flowId
        this.session := args.Get("session", "")
        this.hubPipe := args.Get("hub", "")
        this.dataDir := args.Get("data", "")
        this.hubHwnd := Integer(args.Get("hubHwnd", 0))
        this.logLevel := Log.ParseLevel(args.Get("log-level", Log.DEFAULT_LEVEL))   ; throws: the entry exits with 2
        this.peer := ""
        this.closing := false
        this.lostSince := 0
        this.logQueue := []
        this.logDropped := 0
        this.logTarget := ""
        this.errorTimes := []
    }

    ; Creates the peer, registers the standard and the role handlers, and starts the connection.
    ; Returns at once. Throws only for errors before the connection starts (the entry exits with 1).
    Start() {
        if (this.hubPipe = "")
            throw AhfError("Role: --hub is empty", ErrCode.BAD_ARGS)
        Role.Current := this
        Persistent()
        Log.Configure(Role.LogSinkFn)
        Log.SetLevel(this.logLevel)
        OnError(Role.ErrorFn)
        this.peer := Peer(this.name, this.hubPipe, Map("hubHwnd", this.hubHwnd))
        this.peer.On("sys.shutdown", Role.ShutdownFn)
        this.peer.OnReady := Role.PeerReadyFn
        this.peer.OnClosed := Role.PeerClosedFn
        this.RegisterHandlers()
        SetTimer(Role.GuardFn, Role.GUARD_MS)
        this.peer.Connect()
    }

    ; --- hooks for subclasses ------------------------------------------------------------------

    RegisterHandlers() {
    }

    OnReady() {
    }

    OnShutdown(deadlineMs) {
    }

    OnPeerLost() {
    }

    ; Default policy for an error nobody caught: log it and keep the role running. The return
    ; value 1 tells AHK that the error is handled (no dialog). A subclass may end the role instead.
    ; Before this hook runs, the error is counted and sent to the supervisor as evt.diag.error; more than
    ; ERROR_LIMIT within ERROR_WINDOW_MS end the role with EXIT_TOO_MANY_ERRORS after the hook returned.
    OnUnexpectedError(e, mode) {
        this._Log("a0", "role", this.name " unexpected " Type(e) ": " e.Message " (line " e.Line ", " mode ")")
        return 1
    }

    ; --- message handlers ----------------------------------------------------------------------

    ; Registers a handler on the peer (call from RegisterHandlers).
    On(typePrefix, handler) {
        this.peer.On(typePrefix, handler)
    }

    ; --- log -----------------------------------------------------------------------------------

    ; Sets the process that receives evt.log.append (normally "storage"). Before a target is set,
    ; entries wait in the queue (max LOG_QUEUE_MAX, the oldest are dropped and counted).
    SetLogTarget(address) {
        this.logTarget := address
        this._FlushLog()
    }

    LogStats() {
        last := (this.logQueue.Length > 0) ? this.logQueue[this.logQueue.Length]["text"] : ""
        return Map("queued", this.logQueue.Length, "dropped", this.logDropped, "last", last)
    }

    _Log(level, source, text) {
        Log.Write(level, source, text)
    }

    static _LogSink(level, source, text, flowId := "") {
        r := Role.Current
        if (IsObject(r))
            r._Enqueue(level, source, text, flowId)
    }

    _Enqueue(level, source, text, flowId) {
        entry := Map("ts", FormatTime(A_NowUTC, "yyyy-MM-dd HH:mm:ss"), "level", level
            , "source", source, "text", text)
        if (flowId != "")
            entry["flowId"] := flowId
        if (this.logTarget != "" && IsObject(this.peer) && this.peer.status = "ready") {
            this.peer.Send(this.logTarget, "evt.log.append", entry)
            return
        }
        this.logQueue.Push(entry)
        while (this.logQueue.Length > Role.LOG_QUEUE_MAX) {
            this.logQueue.RemoveAt(1)
            this.logDropped += 1
        }
    }

    _FlushLog() {
        if (this.logTarget = "" || !IsObject(this.peer) || this.peer.status != "ready")
            return
        pending := this.logQueue
        this.logQueue := []
        for entry in pending
            this.peer.Send(this.logTarget, "evt.log.append", entry)
    }

    ; --- lifecycle callbacks from the peer -----------------------------------------------------

    _OnPeerReady() {
        this.lostSince := 0
        try {
            this.OnReady()
        } catch as e {
            this._Log("a0", "role", this.name " OnReady failed: " Type(e) ": " e.Message)
        }
        this._FlushLog()
    }

    _OnPeerClosed() {
        if (this.closing)
            return
        this._Exit(Role.EXIT_HUB_LOST, "peer closed (" this.peer.closeReason ")")
    }

    ; Runs every GUARD_MS. Measures how long the hub connection has been lost.
    _Guard() {
        if (this.closing)
            return
        if (this.peer.status != "reconnecting") {
            this.lostSince := 0
            return
        }
        now := Time.NowMs()
        if (this.lostSince = 0) {
            this.lostSince := now
            this._Log("a1", "role", this.name " hub connection lost, waiting up to " Role.ORPHAN_MS " ms")
            try {
                this.OnPeerLost()
            } catch as e {
                this._Log("a0", "role", this.name " OnPeerLost failed: " Type(e) ": " e.Message)
            }
            return
        }
        if (now - this.lostSince >= Role.ORPHAN_MS)
            this._Exit(Role.EXIT_HUB_LOST, "hub not reachable for " Role.ORPHAN_MS " ms")
    }

    _OnShutdown(msg) {
        if (this.closing)
            return
        deadlineMs := msg.payload.Get("deadlineMs", 5000)
        this._Log("a1", "role", this.name " shutdown requested, deadline " deadlineMs " ms")
        try {
            this.OnShutdown(deadlineMs)
        } catch as e {
            this._Log("a0", "role", this.name " OnShutdown failed: " Type(e) ": " e.Message)
        }
        ; Not here: Peer.Close is called from inside the frame handler. The timer runs after it.
        SetTimer(Role.ByeFn, -1)
    }

    _FinishShutdown() {
        if (this.closing)
            return
        this.closing := true
        this.peer.Send("supervisor", "sys.bye", Map("clean", Json.True))
        this.peer.Close()
        ExitApp(Role.EXIT_OK)
    }

    _Exit(code, reason) {
        if (this.closing)
            return
        this.closing := true
        Role.Console("a0", "role", this.name " ends with exit " code ": " reason)
        if (IsObject(this.peer))
            this.peer.Close()
        ExitApp(code)
    }

    static _OnUnexpected(e, mode) {
        r := Role.Current
        if (!IsObject(r)) {
            Role.Console("a0", "role", "unexpected " Type(e) ": " e.Message)
            return 1
        }
        r._ReportError(e, mode)
        result := 1
        try {
            result := r.OnUnexpectedError(e, mode)
        } catch as e2 {
            Role.Console("a0", "role", "OnUnexpectedError failed: " Type(e2) ": " e2.Message)
        }
        if (r._TooManyErrors())
            r._Exit(Role.EXIT_TOO_MANY_ERRORS, "too many unexpected errors (more than " Role.ERROR_LIMIT " within "
                . Role.ERROR_WINDOW_MS " ms)")
        return result
    }

    ; Counts the error and tells the supervisor (evt.diag.error). Never throws: this runs inside OnError.
    _ReportError(e, mode) {
        try {
            this.errorTimes.Push(Time.NowMs())
            if (IsObject(this.peer))
                this.peer.Send("supervisor", "evt.diag.error", Role.ErrorPayload(this.name, e, mode))
        } catch as e2 {
            Role.Console("a0", "role", "could not report an unexpected error: " Type(e2) ": " e2.Message)
        }
    }

    ; True when more than ERROR_LIMIT errors were counted within the last ERROR_WINDOW_MS.
    _TooManyErrors() {
        now := Time.NowMs()
        while (this.errorTimes.Length && now - this.errorTimes[1] > Role.ERROR_WINDOW_MS)
            this.errorTimes.RemoveAt(1)
        return this.errorTimes.Length > Role.ERROR_LIMIT
    }

    ; The payload of evt.diag.error (PROTOKOLL 4.1c) for an error object. Missing properties become "".
    static ErrorPayload(name, e, mode) {
        p := Map("name", name, "errorType", Type(e), "mode", String(mode))
        for prop in ["Message", "File", "Line", "Stack"] {
            value := ""
            try {
                value := e.%prop%
            } catch {
                ; an error object without this property (a thrown string): empty
            }
            p[StrLower(prop)] := (prop = "Line") ? (IsInteger(value) ? Integer(value) : 0) : String(value)
        }
        if (StrLen(p["stack"]) > Role.MAX_STACK_CHARS)
            p["stack"] := SubStr(p["stack"], 1, Role.MAX_STACK_CHARS) "..."
        return p
    }

    ; "editor:Flow 1" -> "editor"
    static BaseName(name) {
        p := InStr(name, ":")
        return p ? SubStr(name, 1, p - 1) : name
    }
}
