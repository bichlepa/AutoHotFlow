#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Log.ahk
#Include ..\core\Time.ahk
#Include ..\core\Role.ahk
#Include ..\core\Json.ahk
#Include ChildLauncher.ahk

; The role processes started by the supervisor (doc/ARCHITECTURE.md 3, 5.3, 6.2).
; One record per child, keyed by its name ("echo" or "echo:a", as the role sees itself).
;
;   children := Children(config, hub)     ; config Map: session, pipe, data, hubHwnd, testRoles, entryDir
;   children.Spawn("echo:a")              ; starts AutoHotkey with --role=echo --flow=a ...
;   children.Tick(now)                    ; called by the supervisor's timer: process exits, restarts
;
; States (ARCHITECTURE 5.3): starting -> ready (sys.hello) -> stopping (sys.shutdown sent) -> exited;
; hung (no pong, or startup timeout), crashed (the process ended without being asked to).
; Events on topic "process": started, restarted, ready, hung, crashed, exited (PROTOCOL 3).
;
; Process handles: the handle CreateProcessW returns (ChildLauncher, all access) is used for the exit wait
; (WaitForSingleObject(h, 0) on every tick), the exit code and TerminateProcess (hard end after the deadline).
; Judging an exit (WI-0030, F-0023): an ended process is judged (exited/crashed, clean) only after the hub has read its
; connection to the end (Hub.HasLink is false: the link goes when the end of the pipe is read, so everything the
; child wrote before, sys.bye included, has been handled), or EXIT_GRACE_MS after the end was seen (a child that
; never connected, or a connection that does not end). Pumping the hub first in the tick is not enough: a pump that
; another thread runs at that moment (the tick interrupted it) makes the tick's own pump return at once.
; Output (WI-0023): stdout and stderr of a child are one anonymous pipe. Every tick reads what is there and
; writes each line as a log entry (level a0, source = role name, text "[<name>] <line>"); the last
; OUTPUT_RING_MAX lines of every child stay in memory after the process has ended (Output(name), for the
; crash report). When a process ends, the rest of its output is read first, then the handles are closed.
; Workers (WI-0027, ARCHITECTURE 6.4): the engine asks for them (SpawnWorker) and ends them (KillWorker); they are never
; restarted here. A worker that reports sys.busy is not pinged and not judged by pongs (OnBusy, IsBusy). Records of
; ended workers are kept for diagnosis, but only the last GONE_WORKERS_KEEP of them.
; Restart policy: only roles in AUTO_RESTART restart by themselves, at most RESTART_MAX times within
; RESTART_WINDOW_MS. manager and editor never restart automatically. The test role "crasher" joins the
; list only with --test-roles (TEST_AUTO_RESTART), so the policy can be tested without a real engine.
class Children {
    static STARTUP_MS := 10000
    static RESTART_MAX := 3
    static RESTART_WINDOW_MS := 60000
    static RESTART_DELAY_MS := 300
    static KILL_AFTER_MS := 2000
    ; Longest wait between the end of a process and its judgement while its connection is still open (see the head).
    ; The normal wait is one or two ticks: the pipe of an ended process reports its end at the next read. 500 ms keep
    ; the reports evt.process.exited/crashed (and a restart) short when the connection does not end for some reason.
    static EXIT_GRACE_MS := 500
    static AUTO_RESTART := Map("storage", 1, "engine", 1)
    static TEST_AUTO_RESTART := Map("crasher", 1)
    ; SYNCHRONIZE (0x00100000) | PROCESS_QUERY_LIMITED_INFORMATION (0x1000) | PROCESS_TERMINATE (0x1)
    ; (no longer used by the supervisor: CreateProcessW returns a full-access handle; the unit tests open handles with it)
    static OPEN_ACCESS := 0x00101001
    static WAIT_OBJECT_0 := 0
    static OUTPUT_RING_MAX := 100
    ; Most workers alive at the same time (a safeguard against a faulty engine; the pool size N is the engine's).
    static WORKER_LIMIT := 16
    static GONE_WORKERS_KEEP := 8
    ; Per child and tick: at most 64 KB are read and at most 200 lines are logged. The rest of the lines goes
    ; into the ring only, with one log line that says how many; so a chatty child cannot flood storage.
    ; The pipe holds 256 KB (ChildLauncher.PIPE_BUFFER), a tick is 200 ms: a child may write about 1.3 MB/s.
    static READ_MAX := 65536
    static LINES_PER_TICK := 200
    ; Exit codes with a meaning, for the log line of a crash.
    static EXIT_TEXT := Map(1, "failed to start or fatal error", 2, "bad arguments, unknown role or 32-bit interpreter"
        , 3, "role not implemented", 4, "hub lost", 6, "too many unexpected errors")

    shuttingDown := false
    ; Function property (kind, name): the supervisor wants to know about incidents (crashed, restart-limit, hung)
    ; to write a report (WI-0028). Called after the event was published; a failure of it is logged and ignored.
    onIncident := ""
    ; Set once a child was terminated by the supervisor (hang or deadline). Decides exit code 5.
    killedSome := false

    __New(config, hub) {
        this.config := config
        this.hub := hub
        this._recs := Map()
        this.restartMax := config.Get("restartMax", Children.RESTART_MAX)
        this.workerLimit := config.Get("workerLimit", Children.WORKER_LIMIT)
        this._nextWorker := 1
        this._autoRoles := Map()
        for roleName, _ in Children.AUTO_RESTART
            this._autoRoles[roleName] := true
        if (config["testRoles"])
            for roleName, _ in Children.TEST_AUTO_RESTART
                this._autoRoles[roleName] := true
    }

    Has(name) => this._recs.Has(name)

    ; Starts a role process. entry is "role" or "role:flowId". Throws AhfError for an unknown role or a duplicate name.
    Spawn(entry) {
        roleName := Role.BaseName(entry)
        script := this.EntryScript(roleName)
        if (script = "")
            throw AhfError("unknown role '" roleName "'", ErrCode.BAD_ARGS)
        if (this._recs.Has(entry))
            throw AhfError("child '" entry "' already exists", ErrCode.CONFLICT)
        flow := ""
        p := InStr(entry, ":")
        if (p)
            flow := SubStr(entry, p + 1)
        rec := Map("name", entry, "role", roleName, "script", script, "flow", flow, "state", "starting", "pid", 0, "handle", 0
            , "gone", true, "exitCode", "", "startedAt", 0, "readyAt", 0, "lastPingAt", 0, "pingN", 0
            , "lastPongAt", 0, "bye", false, "byeClean", false, "restartTimes", [], "restartAt", 0
            , "killAt", 0, "restartable", this._autoRoles.Has(roleName), "exitSeenAt", 0
            , "reader", "", "output", [], "busy", false, "killReason", "")  ; arch-ok: wire-bool internal record, never sent
        this._recs[entry] := rec
        this._Launch(rec, false, Time.NowMs())
    }

    ; The entry script of a role (WI-0047-PREP, E0041): <entryDir>\<role>.ahk, with --test-roles also
    ; <entryDir>\test\<role>.ahk. "" when there is none (an unknown role). The role name is checked as a file name.
    ; FileExist is a status query of the program's own script folder, not data I/O.
    EntryScript(roleName) {
        if (!RegExMatch(roleName, "^\w+$"))
            return ""
        dir := this.config.Get("entryDir", "")
        if (dir = "")
            return ""
        path := dir "\" roleName ".ahk"
        if (FileExist(path))
            return path
        if (this.config["testRoles"]) {
            path := dir "\test\" roleName ".ahk"
            if (FileExist(path))
                return path
        }
        return ""
    }

    ; Starts a role that is not running: a new child, or the record of an ended one again (the debug window that the
    ; user closed and opens again, WI-0028). Returns true when a process was started, false when it runs already.
    ; Throws what Spawn throws. The restart count of an ended record is kept (it is the history of the name).
    Open(entry) {
        if (!this._recs.Has(entry)) {
            this.Spawn(entry)
            return true
        }
        rec := this._recs[entry]
        if (!rec["gone"])
            return false
        this._Launch(rec, false, Time.NowMs())
        return true
    }

    ; Starts the next worker on request of the engine (cmd.process.spawn). Returns its name "worker:<n>". The number
    ; is never used twice in a session. Throws AhfError: shutting_down, busy (WORKER_LIMIT alive), internal.
    SpawnWorker() {
        if (this.shuttingDown)
            throw AhfError("the supervisor is shutting down", ErrCode.SHUTTING_DOWN)
        if (this.LiveWorkers() >= this.workerLimit)
            throw AhfError("already " this.workerLimit " workers alive", ErrCode.BUSY)
        this._PruneGoneWorkers()
        name := "worker:" this._nextWorker
        while (this._recs.Has(name)) {
            this._nextWorker += 1
            name := "worker:" this._nextWorker
        }
        this._nextWorker += 1
        this.Spawn(name)
        return name
    }

    ; Hard end of a worker on request of the engine (cmd.process.kill). The end is reported as a planned exit
    ; (evt.process.exited, reason "killed"), is not a crash, does not count for the exit code and never restarts.
    ; An unknown name throws not_found; a worker that has ended already is not an error.
    KillWorker(name, reason) {
        if (!this._recs.Has(name))
            throw AhfError("no such worker '" name "'", ErrCode.NOT_FOUND)
        rec := this._recs[name]
        if (rec["gone"] || rec["handle"] = 0)
            return
        ; Ended already, only not judged yet (F-0042, WI-0035): its end is its own (a crash), not a planned exit. The
        ; request of the engine can arrive in the few milliseconds between the death and the next tick.
        if (this._HasEnded(rec)) {
            Log.Write("a1", "children", name " has ended already, its end is judged as its own (kill request: " reason ")")
            return
        }
        Log.Write("a1", "children", "killing " name " on request: " reason)
        if (rec["state"] != "hung") {
            rec["state"] := "stopping"
            rec["killReason"] := "killed"
        }
        this.Terminate(name, false)
    }

    ; Number of workers whose process is still running.
    LiveWorkers() {
        n := 0
        for _, rec in this._recs
            if (rec["role"] = "worker" && !rec["gone"])
                n += 1
        return n
    }

    ; Keeps the records of the last GONE_WORKERS_KEEP ended workers; older ones go (the list stays short in a long session).
    _PruneGoneWorkers() {
        gone := []
        for name, rec in this._recs
            if (rec["role"] = "worker" && rec["gone"] && IsInteger(rec["flow"]))
                gone.Push(Integer(rec["flow"]))
        if (gone.Length <= Children.GONE_WORKERS_KEEP)
            return
        gone := Children._SortedNumbers(gone)
        loop gone.Length - Children.GONE_WORKERS_KEEP
            this._recs.Delete("worker:" gone[A_Index])
    }

    static _SortedNumbers(list) {
        text := ""
        for n in list
            text .= (text = "" ? "" : "`n") Format("{:012d}", n)
        text := Sort(text)
        out := []
        for line in StrSplit(text, "`n")
            out.Push(Integer(line))
        return out
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

    ; The supervisor itself stood still for ms (Supervisor, Stall; WI-0033, F-0015): the liveness of the children begins again
    ; at "now" (ResetLiveness), and every other deadline of a record moves by ms, so its rest of the time stays: the kill
    ; time of a hung child, the time of a planned restart, the end of the wait for the connection of an ended process.
    ; The restart history (RESTART_WINDOW_MS) is a rate over real time and stays as it is.
    OnStall(now, ms) {
        this.ResetLiveness(now)
        for _, rec in this._recs {
            if (rec["gone"]) {
                if (rec["restartAt"] > 0)
                    rec["restartAt"] += ms
                continue
            }
            if (rec["killAt"] > 0)
                rec["killAt"] += ms
            if (rec.Get("exitSeenAt", 0) > 0)
                rec["exitSeenAt"] += ms
        }
    }

    ; Every child that is judged by time starts again with fresh timestamps. (A hung child keeps its kill time here.)
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

    ; The process table for the supervisor's snapshot (doc/PROTOCOL.md 4.9): every record, also of ended
    ; children, with the restart count, the exit code and the last lines of their output.
    Describe() {
        list := []
        for name, rec in this._recs {
            list.Push(Map("name", name, "role", rec["role"], "state", rec["state"], "pid", rec["pid"]
                , "exitCode", rec["exitCode"], "restarts", rec["restartTimes"].Length
                , "startedAt", rec.Get("startedUtc", ""), "busy", Json.Bool(rec.Get("busy", false))
                , "killReason", rec.Get("killReason", ""), "output", rec["output"].Clone()))
        }
        return list
    }

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

    ; True while the child reports sys.busy true (a worker with a job): it is not pinged and not judged by pongs.
    IsBusy(name) => this._recs.Has(name) ? this._recs[name].Get("busy", false) : false

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
        if (rec["pid"] = 0)         ; hello before Launch has stored the pid (see _Launch)
            rec["pid"] := link["pid"]
        rec["readyAt"] := now
        rec["lastPongAt"] := now
        this.hub.Publish("process", "evt.process.ready", Map("name", name, "pid", link["pid"]))
    }

    OnPong(name) {
        if (this._recs.Has(name))
            this._recs[name]["lastPongAt"] := Time.NowMs()
    }

    ; sys.busy of a worker. When the job ends, the pong times start again at "now": the worker was not asked while busy.
    OnBusy(name, busy, now := "") {
        if (!this._recs.Has(name) || this._recs[name]["role"] != "worker")
            return
        rec := this._recs[name]
        was := rec.Get("busy", false)
        rec["busy"] := busy ? true : false
        if (was && !busy) {
            if (now = "")
                now := Time.NowMs()
            rec["lastPongAt"] := now
            rec["lastPingAt"] := now
        }
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
        ; An ended process whose exit waits for its connection (EXIT_GRACE_MS) is not hung: it is judged as an exit.
        if (rec["state"] = "hung" || rec["gone"] || rec.Get("exitSeenAt", 0) > 0)
            return
        rec["state"] := "hung"
        rec["killAt"] := Time.NowMs() + Children.KILL_AFTER_MS
        Log.Write("a0", "children", name " hung: " reason)
        this.hub.Publish("process", "evt.process.hung", Map("name", name, "reason", reason))
        this.hub.Send(name, "sys.shutdown", Map("reason", "crash", "deadlineMs", Children.KILL_AFTER_MS))
        this._Incident("hung", name)
    }

    ; Hard end of a process. The exit is seen on a later tick like any other exit.
    ; countKilled false: a hard end the supervisor was asked for does not make exit code 5 (KillWorker).
    Terminate(name, countKilled := true) {
        if (!this._recs.Has(name))
            return
        rec := this._recs[name]
        if (rec["gone"] || rec["handle"] = 0)
            return
        ; Ended already, only not judged yet (EXIT_GRACE_MS): nothing to terminate, and it must not count as killed.
        if (DllCall("WaitForSingleObject", "ptr", rec["handle"], "uint", 0, "uint") = Children.WAIT_OBJECT_0)
            return
        if (countKilled) {
            Log.Write("a0", "children", "terminating " name " (pid " rec["pid"] ")")
            this.killedSome := true
        }
        DllCall("TerminateProcess", "ptr", rec["handle"], "uint", 1)
    }

    ; True when the process has ended, whether or not its end has been judged (handle signalled).
    _HasEnded(rec) {
        return DllCall("WaitForSingleObject", "ptr", rec["handle"], "uint", 0, "uint") = Children.WAIT_OBJECT_0
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

    ; Stops automatic restarts. Called when the shutdown starts. A restart that is planned already (a crash within the last
    ; RESTART_DELAY_MS) is cancelled too (F-0037, WI-0034): it would start a process in the middle of the shutdown, in no group
    ; of the order, that is only ended at the deadline.
    BeginShutdown() {
        this.shuttingDown := true
        for name, rec in this._recs {
            if (rec["gone"] && rec["restartAt"] > 0) {
                rec["restartAt"] := 0
                Log.Write("a1", "children", "planned restart of " name " cancelled: the session ends")
            }
        }
    }

    ; Living children grouped by shutdown rank (ARCHITECTURE 6.3): UI first, storage last.
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

    ; True when every named child has said sys.bye or has already ended. A child that has never connected (state
    ; "starting") does not hold its group (F-0039): it cannot be told to shut down and has sent nothing that a later group
    ; (storage) must still write. Its late sys.hello is handled by Shutdown.OnHello; at the deadline it is ended.
    GroupDone(names) {
        for name in names {
            rec := this._recs[name]
            if (rec["state"] = "starting")
                continue
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
            if (DllCall("WaitForSingleObject", "ptr", rec["handle"], "uint", 0, "uint") = Children.WAIT_OBJECT_0) {
                ; The engine has ended: its workers end now, not when the end has been judged (WI-0033, E0010).
                if (rec["role"] = "engine" && rec.Get("exitSeenAt", 0) = 0)
                    this._EndWorkersOfGoneEngine()
                if (this._ExitReadable(rec, now))
                    this._OnGone(rec, now)
            }
        }
    }

    ; E0010 (WI-0033): when the engine process has ended, every living worker is ended at once. The pool belongs to the
    ; engine and nobody takes the result of a job any more (a worker with an open dialog would stay for the whole
    ; session). Not while the session ends: the shutdown order of the ranks applies then. The end is a planned one
    ; like KillWorker: evt.process.exited with reason "engine gone", no crash, not counted for exit code 5, no restart.
    ; A new engine builds its pool new; its WorkerBridge.Start still ends what it finds (second safeguard).
    _EndWorkersOfGoneEngine() {
        if (this.shuttingDown)
            return
        for name, rec in this._recs {
            if (rec["role"] != "worker" || rec["gone"] || rec["handle"] = 0)
                continue
            if (this._HasEnded(rec))        ; died on its own before: its end is a crash, not "engine gone" (F-0042, WI-0035)
                continue
            Log.Write("a1", "children", "ending " name ": the engine is gone")
            if (rec["state"] != "hung") {
                rec["state"] := "stopping"
                rec["killReason"] := "engine gone"
            }
            this.Terminate(name, false)
        }
    }

    ; The process has ended. True when its exit may be judged now: the hub has read its connection to the end (no
    ; link), or EXIT_GRACE_MS have passed since the end was first seen (see the head of this file).
    _ExitReadable(rec, now) {
        if (rec.Get("exitSeenAt", 0) = 0)
            rec["exitSeenAt"] := now
        if (!this.hub.HasLink(rec["name"]))
            return true
        if (now - rec["exitSeenAt"] < Children.EXIT_GRACE_MS)
            return false
        Log.Write("a1", "children", rec["name"] " ended, but its connection was not read to the end within "
            . Children.EXIT_GRACE_MS " ms; judged now")
        return true
    }

    ; --- internals ---------------------------------------------------------------------------

    _Launch(rec, isRestart, now) {
        cfg := this.config
        cmd := '"' A_AhkPath '" /ErrorStdOut=UTF-8 "' rec["script"] '"'
            . ' --role=' rec["role"] ' --session=' cfg["session"] ' --hub=' cfg["pipe"]
            . ' --data="' cfg["data"] '" --hubHwnd=' cfg["hubHwnd"]
        if (rec["flow"] != "")
            cmd .= ' --flow=' rec["flow"]
        if (cfg["testRoles"])
            cmd .= ' --test-roles'
        if (isRestart)
            cmd .= ' --restarted=' rec["restartTimes"].Length   ; the role knows it is a restart (engine: evt.engine.restarted)
        cmd .= cfg["roleOpts"]   ; --ui, --headless, --stub-cancel-exit (WI-0013), "" when not given
        ; The state is reset BEFORE the process starts. AHK may interrupt this thread between CreateProcessW and the
        ; assignment of the pid (the hub handles messages meanwhile, and other requests such as cmd.process.spawn can
        ; take long). The child can say sys.hello in that time: OnHello then sets "ready" first, and a reset after
        ; Start would turn it back into "starting" for ever (WI-0027: seen as a manager that never became ready).
        rec["state"] := "starting"
        rec["startedAt"] := now
        rec["startedUtc"] := FormatTime(A_NowUTC, "yyyy-MM-dd HH:mm:ss")
        rec["exitCode"] := ""
        rec["bye"] := false
        rec["byeClean"] := false
        rec["restartAt"] := 0
        rec["killAt"] := 0
        rec["exitSeenAt"] := 0
        rec["busy"] := false
        rec["killReason"] := ""
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
        if (isRestart)
            this.hub.Publish("process", "evt.process.restarted", Map("name", rec["name"]
                , "attempt", rec["restartTimes"].Length))
        this.hub.Publish("process", "evt.process.started", Map("name", rec["name"], "role", rec["role"], "pid", pid))
        Log.Write("a1", "children", "started " rec["name"] " (pid " pid ")")
    }

    ; The process has ended. Decides between exited (asked to stop, or gone with a clean goodbye) and crashed, and about a restart.
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
        ; A child that said sys.bye {clean} and ended with exit 0 left by its own wish (the debug window that the user
        ; closed, WI-0028): a normal exit, not a crash.
        voluntary := (rec["bye"] && rec["byeClean"] && exitCode == 0)
        if (rec["state"] != "hung" && (this.shuttingDown || rec["state"] = "stopping" || voluntary)) {
            rec["state"] := "exited"
            payload := Map("name", name, "pid", rec["pid"], "clean", Json.Bool(rec["bye"] && rec["byeClean"])
                , "exitCode", exitCode)
            if (rec.Get("killReason", "") != "")
                payload["reason"] := rec["killReason"]
            this.hub.Publish("process", "evt.process.exited", payload)
            return
        }
        reason := (rec["state"] = "hung") ? "hung" : "exited"
        rec["state"] := "crashed"
        restart := this._ScheduleRestart(rec, now)
        this.hub.Publish("process", "evt.process.crashed", Map("name", name, "pid", rec["pid"], "reason", reason
            , "exitCode", exitCode, "restart", Json.Bool(restart)))
        Log.Write("a0", "children", name " ended unexpectedly (" reason ", exit " exitCode
            . (Children.EXIT_TEXT.Has(exitCode) ? ": " Children.EXIT_TEXT[exitCode] : "") ")")
        this._Incident("crashed", name)
    }

    ; Tells the supervisor about an incident (see onIncident). Never throws.
    _Incident(kind, name) {
        fn := this.onIncident
        if (!IsObject(fn))
            return
        try {
            fn(kind, name)
        } catch as e {
            Log.Write("a0", "children", "incident handler failed: " Type(e) ": " e.Message)
        }
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
            this._Incident("restart-limit", rec["name"])
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
        if (role = "manager" || role = "editor" || role = "debug")
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
