#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Log.ahk
#Include ..\core\Ids.ahk
#Include ..\core\Args.ahk
#Include ..\core\Time.ahk
#Include ..\core\PipeNames.ahk
#Include ..\core\ipc\Wake.ahk
#Include Hub.ahk
#Include Children.ahk
#Include Heartbeat.ahk
#Include DiagLog.ahk
#Include Shutdown.ahk
#Include SupervisorCommand.ahk

; Role "supervisor" (doc/ARCHITEKTUR 3, 6; work_items/phase2/WI-07). The supervisor is the hub of the
; star topology, starts and watches the role processes, and ends the session in two phases. It does
; not inherit from Role (it has no peer of its own) and contains no business logic.
;
; Command line (all options optional):
;   AutoHotFlow.ahk --role=supervisor [--session=<id>] [--data=<dir>] [--start=<role>[:<flow>],...]
;                   [--deadline=<ms>] [--test-roles] [--command=<text>]
;   --session   instance key: names the hub pipe and the mutex (PipeNames; the pipe name also carries
;               the Windows session id and a tag of the user). Default "main".
;   --start     roles started at once, each one is required (its evt.process.ready is awaited by tests).
;   --deadline  total budget of the shutdown in ms (default 5000, sys.shutdown deadlineMs).
;   --test-roles  registers the test roles (tests/integration/helpers) and passes the option on.
;   --prepare-limit  (only with --test-roles) answer limit of cmd.app.prepareExit in ms, default 600000.
;   --restart-max  (only with --test-roles) restarts per RESTART_WINDOW_MS, default Children.RESTART_MAX (3);
;               lets the tests restart a child many times (handle leaks).
;   --ui=<word>, --headless, --stub-cancel-exit  passed on to every role (WI-13: --ui=stub for the manager stub).
;   --log-level=<0..3>  highest log level that is forwarded to storage (default 2; level 3 stays in the ring of
;               Log only). Valid for the supervisor and passed on to every role (WI-23).
;
; Single instance: a named mutex per session. A second supervisor with the same session sends
; cmd.app.command {argv} to the running one and exits (exit 0 = delivered, 1 = no answer).
;
; Exit codes: 0 clean (every child ended by itself), 1 start failed (AutoHotFlow.ahk), 5 at least one
; child was terminated at the deadline or after a hang.
class Supervisor {
    static DEFAULT_SESSION := "main"
    static DEFAULT_DEADLINE_MS := 5000
    static DEFAULT_DATA_SUBDIR := "AutoHotFlow"
    static MIN_DEADLINE_MS := 100
    static MAX_DEADLINE_MS := 60000
    static TICK_MS := 200
    static ERROR_ALREADY_EXISTS := 183
    static Current := ""

    static TickFn := () => Supervisor.Current._Tick()
    static ErrorFn := (e, mode) => Supervisor._OnError(e, mode)

    ; Entry point of the supervisor role. Returns once the hub runs (the timers keep the process alive).
    static Run(opts) {
        s := Supervisor(opts)
        Supervisor.Current := s
        s.Start()
    }

    __New(opts) {
        this.session := opts.Get("session", Supervisor.DEFAULT_SESSION)
        if (this.session = "")
            throw AhfError("supervisor: --session is empty", ErrCode.BAD_ARGS)
        this.pipe := PipeNames.Hub(this.session)
        this.mutexName := PipeNames.Mutex(this.session)
        this.data := opts.Get("data", A_AppData "\" Supervisor.DEFAULT_DATA_SUBDIR)
        this.testRoles := opts.Has("test-roles")
        ; Only with --test-roles: the answer limit of cmd.app.prepareExit (Shutdown.PREPARE_LIMIT_MS) can be
        ; lowered, so the tests see a timeout in seconds. A product start always uses the constant.
        this.prepareLimitMs := Shutdown.PREPARE_LIMIT_MS
        if (this.testRoles && opts.Has("prepare-limit")) {
            this.prepareLimitMs := this._Integer(opts, "prepare-limit", Shutdown.PREPARE_LIMIT_MS)
            if (this.prepareLimitMs < Supervisor.MIN_DEADLINE_MS || this.prepareLimitMs > Shutdown.PREPARE_LIMIT_MS)
                throw AhfError("supervisor: --prepare-limit must be between " Supervisor.MIN_DEADLINE_MS " and "
                    . Shutdown.PREPARE_LIMIT_MS " ms", ErrCode.BAD_ARGS)
        }
        this.logLevel := Log.ParseLevel(opts.Get("log-level", Log.DEFAULT_LEVEL))
        this.restartMax := Children.RESTART_MAX
        if (this.testRoles && opts.Has("restart-max"))
            this.restartMax := this._Integer(opts, "restart-max", Children.RESTART_MAX)
        this.deadlineMs := this._Integer(opts, "deadline", Supervisor.DEFAULT_DEADLINE_MS)
        if (this.deadlineMs < Supervisor.MIN_DEADLINE_MS || this.deadlineMs > Supervisor.MAX_DEADLINE_MS)
            throw AhfError("supervisor: --deadline must be between " Supervisor.MIN_DEADLINE_MS " and "
                . Supervisor.MAX_DEADLINE_MS " ms", ErrCode.BAD_ARGS)
        this.startList := []
        for entry in StrSplit(String(opts.Get("start", "")), ",") {
            entry := Trim(entry)
            if (entry != "")
                this.startList.Push(entry)
        }
        this.hasCommand := opts.Has("command")
        this.command := String(opts.Get("command", ""))
        this.roleOpts := this._RoleOpts(opts)
        this.mutex := 0
        this.hub := ""
        this.diag := ""
        this.children := ""
        this.heartbeat := ""
        this.shutdown := ""
    }

    Start() {
        Persistent()
        Log.SetLevel(this.logLevel)
        OnError(Supervisor.ErrorFn)
        Ids.Configure("supervisor")
        if (this._ForwardIfRunning())
            return
        config := Map("session", this.session, "pipe", this.pipe, "data", this.data
            , "hubHwnd", Wake.Hwnd, "testRoles", this.testRoles, "script", A_ScriptFullPath
            , "roleOpts", this.roleOpts, "restartMax", this.restartMax)
        this.hub := Hub(this.pipe, this.session)
        this.diag := DiagLog(this.hub)
        Log.Configure(this.diag.SinkFn)      ; to storage as soon as it is connected, else queued (WI-23)
        this.children := Children(config, this.hub)
        this.heartbeat := Heartbeat(this.children, this.hub)
        this.shutdown := Shutdown(this.children, this.hub)
        this.shutdown.prepareLimitMs := this.prepareLimitMs
        this.shutdown.onDone := (code) => this._Finish(code)
        this._Wire()
        this.hub.Start()
        for entry in this.startList
            this.children.Spawn(entry)
        this.heartbeat.Arm(Time.NowMs())
        SetTimer(Supervisor.TickFn, Supervisor.TICK_MS)
        Log.Write("a1", "supervisor", "session " this.session " running, hub " this.pipe)
    }

    ; --- wiring -----------------------------------------------------------------------------

    _Wire() {
        h := this.hub
        h.On("sys.pong", (msg) => this.children.OnPong(msg.from))
        h.On("sys.bye", (msg) => this.children.OnBye(msg.from, msg.payload.Get("clean", false)))
        h.On("cmd.app.", (msg) => this._OnApp(msg))
        h.On("cmd.process.", (msg) => this._OnProcess(msg))
        h.On("evt.diag.error", (msg) => this.diag.AddError(msg.from, msg.payload))
        h.onHello := (link) => this._OnHello(link)
        h.onLinkLost := (link, reason) => this.children.OnLinkLost(link["name"], reason)
    }

    ; A client said sys.hello: the children learn about it; the log queue is delivered once storage is there.
    _OnHello(link) {
        this.children.OnHello(link)
        if (link["name"] = DiagLog.STORAGE)
            this.diag.Flush()
    }

    ; Commands to the supervisor itself. cmd.app.exit starts the exit and answers at once.
    _OnApp(msg) {
        if (msg.type = "cmd.app.exit") {
            deadline := this.deadlineMs
            if (msg.payload.Has("deadlineMs")) {
                d := msg.payload["deadlineMs"]
                if (Type(d) != "Integer" || d < Supervisor.MIN_DEADLINE_MS || d > Supervisor.MAX_DEADLINE_MS)
                    throw AhfError("deadlineMs must be an integer from " Supervisor.MIN_DEADLINE_MS " to "
                        . Supervisor.MAX_DEADLINE_MS, ErrCode.BAD_PAYLOAD)
                deadline := d
            }
            return Map("started", Json.Bool(this.shutdown.BeginExit("user", deadline, msg.from)))
        }
        if (msg.type = "cmd.app.command") {
            argv := msg.payload.Get("argv", "")
            if (Type(argv) != "Array")
                throw AhfError("argv must be an array of strings", ErrCode.BAD_PAYLOAD)
            text := ""
            for word in argv
                text .= (text = "" ? "" : " ") String(word)
            Log.Write("a1", "supervisor", "command from " msg.from ": " text)
            return Map()
        }
        throw AhfError("unknown command " msg.type, ErrCode.UNKNOWN_TYPE)
    }

    _OnProcess(msg) {
        if (msg.type = "cmd.process.list")
            return Map("processes", this.children.Snapshot())
        throw AhfError("unknown command " msg.type, ErrCode.UNKNOWN_TYPE)
    }

    ; --- single instance ---------------------------------------------------------------------

    ; True when another supervisor holds the mutex of this session. The command is then forwarded and
    ; this process must not create a hub.
    _ForwardIfRunning() {
        h := DllCall("CreateMutexW", "ptr", 0, "int", 0, "str", this.mutexName, "ptr")
        err := A_LastError
        if (h = 0)
            throw AhfError("could not create the instance mutex (error " err ")", ErrCode.INTERNAL)
        if (err != Supervisor.ERROR_ALREADY_EXISTS) {
            this.mutex := h          ; kept until the process ends; the OS releases it then
            return false
        }
        DllCall("CloseHandle", "ptr", h)
        argv := this.hasCommand ? [this.command] : []
        Log.Write("a1", "supervisor", "already running for session " this.session ", forwarding the command")
        SupervisorCommand(this.pipe, argv).Start()
        return true
    }

    ; --- timer and end -----------------------------------------------------------------------

    _Tick() {
        now := Time.NowMs()
        ; Read what has arrived before looking for ended processes: a child sends sys.bye and exits, and the
        ; exit must not be seen before its bye (else the exit is reported as not clean).
        try {
            this.hub.Pump()
        } catch as e {
            Log.Write("a0", "supervisor", "hub pump failed: " Type(e) ": " e.Message)
        }
        try {
            this.hub.Tick(now)
        } catch as e {
            Log.Write("a0", "supervisor", "hub tick failed: " Type(e) ": " e.Message)
        }
        try {
            this.children.Tick(now)
        } catch as e {
            Log.Write("a0", "supervisor", "children tick failed: " Type(e) ": " e.Message)
        }
        try {
            this.heartbeat.Tick(now)
        } catch as e {
            Log.Write("a0", "supervisor", "heartbeat tick failed: " Type(e) ": " e.Message)
        }
        try {
            this.shutdown.Tick(now)
        } catch as e {
            Log.Write("a0", "supervisor", "shutdown tick failed: " Type(e) ": " e.Message)
        }
    }

    _Finish(code) {
        SetTimer(Supervisor.TickFn, 0)
        try {
            this.hub.Close()
        } catch as e {
            Log.Write("a0", "supervisor", "hub close failed: " Type(e) ": " e.Message)
        }
        Log.Write("a1", "supervisor", "ends with exit " code)
        ExitApp(code)
    }

    static _OnError(e, mode) {
        Log.Write("a0", "supervisor", "unexpected " Type(e) ": " e.Message " (line " e.Line ", " mode ")")
        try {
            Supervisor.Current.diag.AddError("supervisor", Role.ErrorPayload("supervisor", e, mode), false)
        } catch {
            ; the ring is a convenience; the error is logged above
        }
        return 1
    }

    ; Options the supervisor passes on to every role process (WI-13): --ui=<word> selects the UI role
    ; (manager: --ui=stub), --headless and --stub-cancel-exit are the stub's test options.
    _RoleOpts(opts) {
        text := ""
        if (opts.Has("log-level"))
            text .= " --log-level=" this.logLevel
        if (opts.Has("ui")) {
            ui := String(opts["ui"])
            if (!RegExMatch(ui, "^[a-z]+$"))
                throw AhfError("supervisor: --ui must be a single word, e.g. --ui=stub", ErrCode.BAD_ARGS)
            text .= " --ui=" ui
        }
        if (opts.Has("headless"))
            text .= " --headless"
        if (opts.Has("stub-cancel-exit"))
            text .= " --stub-cancel-exit"
        return text
    }

    _Integer(opts, key, fallback) {
        raw := opts.Get(key, fallback)
        if (!IsInteger(raw))
            throw AhfError("supervisor: --" key " must be an integer", ErrCode.BAD_ARGS)
        return Integer(raw)
    }
}
