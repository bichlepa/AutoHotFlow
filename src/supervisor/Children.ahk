#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Log.ahk
#Include ..\core\Time.ahk
#Include ..\core\Role.ahk
#Include ..\core\RoleRegistry.ahk
#Include ChildLauncher.ahk

; The role processes started by the supervisor (doc/ARCHITEKTUR.md 3, 5.3, 6.2).
; One record per child, keyed by its name ("echo" or "echo:a", as the role sees itself).
;
;   children := Children(config, hub)     ; config Map: session, pipe, data, hubHwnd, testRoles, script
;   children.Spawn("echo:a")              ; starts AutoHotkey with --role=echo --flow=a ...
;   children.Tick(now)                    ; called by the supervisor's timer: process exits, restarts
;
; States (ARCHITEKTUR 5.3): starting -> ready (sys.hello) -> stopping (sys.shutdown sent) -> exited;
; hung (no pong, or startup timeout), crashed (the process ended without being asked to).
; Events on topic "process": started, restarted, ready, hung, crashed, exited (PROTOCOL 3).
;
; Process handles: the handle CreateProcessW returns (ChildLauncher, all access) is used for the exit wait
; (WaitForSingleObject(h, 0) on every tick), the exit code and TerminateProcess (hard end after the deadline).
; Output (WI-23): stdout and stderr of a child are one anonymous pipe. Every tick reads what is there and
; writes each line as a log entry (level a0, source = role name, text "[<name>] <line>"); the last
; OUTPUT_RING_MAX lines of every child stay in memory after the process has ended (Output(name), for the
; crash report). When a process ends, the rest of its output is read first, then the handles are closed.
; Restart policy: only roles in AUTO_RESTART restart by themselves, at most RESTART_MAX times within
; RESTART_WINDOW_MS. manager and editor never restart automatically. The test role "crasher" joins the
; list only with --test-roles (TEST_AUTO_RESTART), so the policy can be tested without a real engine.
class Children {
    static STARTUP_MS := 10000
    static RESTART_MAX := 3
    static RESTART_WINDOW_MS := 60000
    static RESTART_DELAY_MS := 300
    static KILL_AFTER_MS := 2000
    static AUTO_RESTART := Map("storage", 1, "engine", 1)
    static TEST_AUTO_RESTART := Map("crasher", 1)
    ; SYNCHRONIZE (0x00100000) | PROCESS_QUERY_LIMITED_INFORMATION (0x1000) | PROCESS_TERMINATE (0x1)
    ; (no longer used by the supervisor: CreateProcessW returns a full-access handle; the unit tests open handles with it)
    static OPEN_ACCESS := 0x00101001
    static WAIT_OBJECT_0 := 0
    static OUTPUT_RING_MAX := 100
    ; Per child and tick: at most 64 KB are read and at most 200 lines are logged. The rest of the lines goes
    ; into the ring only, with one log line that says how many; so a chatty child cannot flood storage.
    ; The pipe holds 256 KB (ChildLauncher.PIPE_BUFFER), a tick is 200 ms: a child may write about 1.3 MB/s.
    static READ_MAX := 65536
    static LINES_PER_TICK := 200
    ; Exit codes with a meaning, for the log line of a crash.
    static EXIT_TEXT := Map(1, "failed to start or fatal error", 2, "bad arguments, unknown role or 32-bit interpreter"
        , 3, "role not implemented", 4, "hub lost", 6, "too many unexpected errors")

    shuttingDown := false
    ; Set once a child was terminated by the supervisor (hang or deadline). Decides exit code 5.
    killedSome := false

    __New(config, hub) {
        this.config := config
        this.hub := hub
        this._recs := Map()
        this.restartMax := config.Get("restartMax", Children.RESTART_MAX)
        this._autoRoles := Map()
        for role, _ in Children.AUTO_RESTART
            this._autoRoles[role] := true
        if (config["testRoles"])
            for role, _ in Children.TEST_AUTO_RESTART
                this._autoRoles[role] := true
    }

    Has(name) => this._recs.Has(name)

    ; Starts a role process. entry is "role" or "role:flowId". Throws AhfError for an unknown role or a duplicate name.
    Spawn(entry) {
        roleName := Role.BaseName(entry)
        if (RoleRegistry.Lookup(roleName) = "")
            throw AhfError("unknown role '" roleName "'", ErrCode.BAD_ARGS)
        if (this._recs.Has(entry))
            throw AhfError("child '" entry "' already exists", ErrCode.CONFLICT)
        flow := ""
        p := InStr(entry, ":")
        if (p)
            flow := SubStr(entry, p + 1)
        rec := Map("name", entry, "role", roleName, "flow", flow, "state", "starting", "pid", 0, "handle", 0
            , "gone", true, "exitCode", "", "startedAt", 0, "readyAt", 0, "lastPingAt", 0, "pingN", 0
            , "lastPongAt", 0, "bye", false, "byeClean", false, "restartTimes", [], "restartAt", 0
            , "killAt", 0, "restartable", this._autoRoles.Has(roleName)
            , "reader", "", "output", [])
        this._recs[entry] := rec
        this._Launch(rec, false, Time.NowMs())
    }

    ; Process ids of the records (for the tests and the shutdown report).
    Pid(name) => this._recs.Has(name) ? this._recs[name]["pid"] : 0

    ; The last lines the child wrote to stdout/stderr (Array of strings, oldest first), kept after its end.
    Output(name) => this._recs.Has(name) ? this._recs[name]["output"].Clone() : []

    State(name) => this._recs.Has(name) ? this._recs[name]["state"] : ""

    Names() {
        names := []
        for name, _ in this._recs
            names.Push(name)
        return names
    }

    ; Milliseconds since the child was started, the last pong, or the last ping (for Heartbeat).
    StartedFor(name, now) => now - this._recs[name]["startedAt"]
    SinceLastPong(name, now) => now - this._recs[name]["lastPongAt"]
    SinceLastPing(name, now) => now - this._recs[name]["lastPingAt"]

    ; The supervisor itself stood still (Heartbeat.Tick): start again with fresh timestamps for every child
    ; that is judged by time. A child that is already hung keeps its kill time.
    ResetLiveness(now) {
        for _, rec in this._recs {
            if (rec["gone"])
                continue
            if (rec["state"] = "starting") {
                rec["startedAt"] := now
            } else if (rec["state"] = "ready" || rec["state"] = "stopping") {
                rec["lastPongAt"] := now
                rec["lastPingAt"] := now
            }
        }
    }

    MarkPing(name, now, n) {
        rec := this._recs[name]
        rec["lastPingAt"] := now
        rec["pingN"] := n
    }

    ; True once the hung child is due for TerminateProcess (after KILL_AFTER_MS).
    KillDue(name, now) => this._recs[name]["killAt"] > 0 && now >= this._recs[name]["killAt"] && !this._recs[name]["gone"]

    ; A snapshot for cmd.process.list.
    Snapshot() {
        list := []
        for name, rec in this._recs
            list.Push(Map("name", name, "role", rec["role"], "state", rec["state"], "pid", rec["pid"]
                , "restarts", rec["restartTimes"].Length))
        return list
    }

    ; True when the process is no longer running (exited, or never started).
    IsGone(name) => this._recs.Has(name) ? this._recs[name]["gone"] : true

    AllGone() {
        for _, rec in this._recs
            if (!rec["gone"])
                return false
        return true
    }

    ; --- events from the hub ------------------------------------------------------------------

    ; sys.hello of a child: the role is ready. Clients that are not children are ignored here.
    OnHello(link) {
        name := link["name"]
        if (!this._recs.Has(name))
            return
        rec := this._recs[name]
        if (rec["state"] != "starting")
            return
        now := Time.NowMs()
        rec["state"] := "ready"
        rec["readyAt"] := now
        rec["lastPongAt"] := now
        this.hub.Publish("process", "evt.process.ready", Map("name", name, "pid", link["pid"]))
    }

    OnPong(name) {
        if (this._recs.Has(name))
            this._recs[name]["lastPongAt"] := Time.NowMs()
    }

    OnBye(name, clean) {
        if (!this._recs.Has(name))
            return
        rec := this._recs[name]
        rec["bye"] := true
        rec["byeClean"] := clean ? true : false
    }

    ; A client connection ended. A queue overflow means the child cannot keep up: it counts as hung.
    OnLinkLost(name, reason) {
        if (reason = "queue_overflow" && this._recs.Has(name))
            this.MarkHung(name, "send queue overflow")
    }

    ; --- decisions made by Heartbeat and Shutdown ---------------------------------------------

    ; The child stops answering: it is hung. It gets sys.shutdown now and is terminated after KILL_AFTER_MS.
    MarkHung(name, reason) {
        if (!this._recs.Has(name))
            return
        rec := this._recs[name]
        if (rec["state"] = "hung" || rec["gone"])
            return
        rec["state"] := "hung"
        rec["killAt"] := Time.NowMs() + Children.KILL_AFTER_MS
        Log.Write("a0", "children", name " hung: " reason)
        this.hub.Publish("process", "evt.process.hung", Map("name", name, "reason", reason))
        this.hub.Send(name, "sys.shutdown", Map("reason", "crash", "deadlineMs", Children.KILL_AFTER_MS))
    }

    ; Hard end of a process. The exit is seen on a later tick like any other exit.
    Terminate(name) {
        if (!this._recs.Has(name))
            return
        rec := this._recs[name]
        if (rec["gone"] || rec["handle"] = 0)
            return
        Log.Write("a0", "children", "terminating " name " (pid " rec["pid"] ")")
        this.killedSome := true
        DllCall("TerminateProcess", "ptr", rec["handle"], "uint", 1)
    }

    KillAlive() {
        for name, rec in this._recs
            if (!rec["gone"])
                this.Terminate(name)
    }

    ; Sends sys.shutdown to one child, if it is connected. Returns false when it cannot be reached.
    SendShutdown(name, reason, deadlineMs) {
        if (!this._recs.Has(name))
            return false
        rec := this._recs[name]
        if (rec["gone"])
            return false
        if (rec["state"] = "ready")
            rec["state"] := "stopping"
        return this.hub.Send(name, "sys.shutdown", Map("reason", reason, "deadlineMs", deadlineMs))
    }

    AnyKilled() => this.killedSome

    ; Stops automatic restarts. Called when the shutdown starts.
    BeginShutdown() {
        this.shuttingDown := true
    }

    ; Living children grouped by shutdown rank (ARCHITEKTUR 6.3): UI first, storage last.
    ; Returns an Array of Arrays of names, ordered by rank.
    ShutdownGroups() {
        ranks := Map()
        for name, rec in this._recs {
            if (rec["gone"])
                continue
            r := this._RankOf(rec["role"])
            if (!ranks.Has(r))
                ranks[r] := []
            ranks[r].Push(name)
        }
        groups := []
        for r in [0, 1, 2, 3, 4]
            if (ranks.Has(r))
                groups.Push(ranks[r])
        return groups
    }

    ; True when every named child has said sys.bye or has already ended.
    GroupDone(names) {
        for name in names {
            rec := this._recs[name]
            if (!rec["bye"] && !rec["gone"])
                return false
        }
        return true
    }

    ; --- timer -------------------------------------------------------------------------------

    ; Looks for ended processes, and restarts those whose restart time has come.
    Tick(now) {
        for name, rec in this._recs.Clone() {
            if (rec["gone"]) {
                if (rec["restartAt"] > 0 && now >= rec["restartAt"])
                    this._Restart(rec, now)
                continue
            }
            if (rec["handle"] = 0) {
                this._OnGone(rec, now)
                continue
            }
            this._ReadOutput(rec)
            if (DllCall("WaitForSingleObject", "ptr", rec["handle"], "uint", 0, "uint") = Children.WAIT_OBJECT_0)
                this._OnGone(rec, now)
        }
    }

    ; --- internals ---------------------------------------------------------------------------

    _Launch(rec, isRestart, now) {
        cfg := this.config
        cmd := '"' A_AhkPath '" /ErrorStdOut=UTF-8 "' cfg["script"] '"'
            . ' --role=' rec["role"] ' --session=' cfg["session"] ' --hub=' cfg["pipe"]
            . ' --data="' cfg["data"] '" --hubHwnd=' cfg["hubHwnd"]
        if (rec["flow"] != "")
            cmd .= ' --flow=' rec["flow"]
        if (cfg["testRoles"])
            cmd .= ' --test-roles'
        if (isRestart)
            cmd .= ' --restarted=' rec["restartTimes"].Length   ; the role knows it is a restart (engine: evt.engine.restarted)
        cmd .= cfg["roleOpts"]   ; --ui, --headless, --stub-cancel-exit (WI-13), "" when not given
        try {
            info := ChildLauncher.Start(cmd)
        } catch as e {
            throw AhfError("could not start " rec["name"] ": " e.Message, ErrCode.INTERNAL)
        }
        pid := info["pid"]
        rec["pid"] := pid
        rec["handle"] := info["process"]
        rec["reader"] := info["reader"]
        rec["gone"] := false
        rec["state"] := "starting"
        rec["startedAt"] := now
        rec["exitCode"] := ""
        rec["bye"] := false
        rec["byeClean"] := false
        rec["restartAt"] := 0
        rec["killAt"] := 0
        if (isRestart)
            this.hub.Publish("process", "evt.process.restarted", Map("name", rec["name"]
                , "attempt", rec["restartTimes"].Length))
        this.hub.Publish("process", "evt.process.started", Map("name", rec["name"], "role", rec["role"], "pid", pid))
        Log.Write("a1", "children", "started " rec["name"] " (pid " pid ")")
    }

    ; The process has ended. Decides between exited (asked to stop) and crashed, and about a restart.
    _OnGone(rec, now) {
        exitCode := ""
        if (rec["handle"] != 0) {
            code := 0
            if (DllCall("GetExitCodeProcess", "ptr", rec["handle"], "uint*", &code))
                exitCode := code
            DllCall("CloseHandle", "ptr", rec["handle"])
            rec["handle"] := 0
        }
        this._CloseOutput(rec)
        rec["gone"] := true
        rec["exitCode"] := exitCode
        name := rec["name"]
        ; A hung child that is killed is a crash, also during a shutdown. Everything else that ends
        ; during a shutdown (or after sys.shutdown was sent) is a normal exit.
        if (rec["state"] != "hung" && (this.shuttingDown || rec["state"] = "stopping")) {
            rec["state"] := "exited"
            this.hub.Publish("process", "evt.process.exited", Map("name", name, "pid", rec["pid"]
                , "clean", Json.Bool(rec["bye"] && rec["byeClean"]), "exitCode", exitCode))
            return
        }
        reason := (rec["state"] = "hung") ? "hung" : "exited"
        rec["state"] := "crashed"
        restart := this._ScheduleRestart(rec, now)
        this.hub.Publish("process", "evt.process.crashed", Map("name", name, "pid", rec["pid"], "reason", reason
            , "exitCode", exitCode, "restart", Json.Bool(restart)))
        Log.Write("a0", "children", name " ended unexpectedly (" reason ", exit " exitCode
            . (Children.EXIT_TEXT.Has(exitCode) ? ": " Children.EXIT_TEXT[exitCode] : "") ")")
    }

    ; --- output of the children --------------------------------------------------------------

    _ReadOutput(rec) {
        reader := rec["reader"]
        if (!IsObject(reader))
            return
        try {
            this._Emit(rec, reader.ReadLines(Children.READ_MAX))
        } catch as e {
            Log.Write("a0", "children", "reading the output of " rec["name"] " failed: " Type(e) ": " e.Message)
        }
    }

    ; The process has ended: the rest of its output is still in the pipe. Read it, then close the pipe.
    _CloseOutput(rec) {
        reader := rec["reader"]
        if (!IsObject(reader))
            return
        try {
            this._Emit(rec, reader.Drain())
        } catch as e {
            Log.Write("a0", "children", "reading the output of " rec["name"] " failed: " Type(e) ": " e.Message)
        }
        reader.Close()
        rec["reader"] := ""
    }

    ; Logs the lines (up to LINES_PER_TICK) and keeps all of them in the ring of the child.
    _Emit(rec, lines) {
        ring := rec["output"]
        for i, line in lines {
            ring.Push(line)
            if (i <= Children.LINES_PER_TICK)
                Log.Write("a0", rec["role"], "[" rec["name"] "] " line)
        }
        while (ring.Length > Children.OUTPUT_RING_MAX)
            ring.RemoveAt(1)
        if (lines.Length > Children.LINES_PER_TICK)
            Log.Write("a0", "children", (lines.Length - Children.LINES_PER_TICK) " lines of output of " rec["name"]
                . " were not logged (the last " Children.OUTPUT_RING_MAX " are kept in memory)")
    }

    ; Returns true when a restart is scheduled. Keeps the restart times of the last RESTART_WINDOW_MS.
    _ScheduleRestart(rec, now) {
        if (!rec["restartable"] || this.shuttingDown)
            return false
        recent := 0
        for t in rec["restartTimes"]
            if (now - t < Children.RESTART_WINDOW_MS)
                recent += 1
        if (recent >= this.restartMax) {
            Log.Write("a0", "children", rec["name"] " not restarted: " recent " restarts within "
                . Children.RESTART_WINDOW_MS " ms")
            return false
        }
        rec["restartAt"] := now + Children.RESTART_DELAY_MS
        return true
    }

    _Restart(rec, now) {
        rec["restartTimes"].Push(now)
        this._Launch(rec, true, now)
    }

    _RankOf(role) {
        if (role = "manager" || role = "editor")
            return 0
        if (role = "engine")
            return 1
        if (role = "triggerhost")
            return 2
        if (role = "storage")
            return 4
        return 3
    }
}
