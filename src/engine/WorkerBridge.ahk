#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Ids.ahk
#Include ..\core\Log.ahk
#Include ..\core\Time.ahk

; Engine side of the worker pool (WI-0011, WI-0027, PROTOCOL 4.5, ARCHITECTURE 2.3, 6.2 and 6.4). The pool is elastic:
; the engine owns the slots and the jobs, the supervisor owns the processes and starts or kills a worker only when
; the engine asks (cmd.process.spawn, cmd.process.kill). Nothing here waits: every request is answered by a callback,
; a job is sent with cmd.worker.run, its answer and evt.worker.done come back as messages, and every job ends
; through its onDone callback.
;
; Slots: "starting" (spawn answered, no evt.process.ready yet), "idle" (may take a job), "busy" (has a job, or an
; orphan that is still running after a cancel). There is no "down": a worker that failed or was killed leaves the list.
; Slots plus spawn requests on their way are never more than the size N (--workers).
;
; Demand: the Executor tells Want(n) how many threads wait for a worker; the pool asks for that many new workers
; (minus those already starting), up to N. W (--warm-workers) workers are asked for at the start and again after a
; loss. An idle slot beyond W that nobody used for idleMs (--worker-idle-ms) is killed.
;
; Loss: a crashed worker ends its job with the exception "worker crashed". Failures (a crash, a worker that ended
; before its spawn answer, a refused cmd.worker.run, a refused spawn) are counted. A start that never gets ready is
; judged by the supervisor (startup timeout, state "hung", the process is ended) and reaches the bridge as
; evt.process.crashed, so it is counted as a crash; STORM_MAX of them within STORM_WINDOW_MS stop
; the asking for workers until the oldest one has left the window (the pool is "blocked"). Normal growing and
; shrinking does not count. With the pool blocked and no worker alive, Usable() is false and jobs end with
; "worker not available".
;
; Cancel: Cancel forgets the job at once (the engine treats the element as stopped, PROTOCOL 4.3) and keeps the
; slot busy until the worker reports evt.worker.done. Without it within ORPHAN_MS the worker is blocked: the slot
; is removed and the supervisor is asked to kill the process. A job deadline (jobTimeoutMs of Run) ends the job with
; "worker timeout" and is handled like a cancel.
;
; Start: Start() first asks the supervisor for the process list and kills every worker (orphans of the engine
; before this one), then the pool is ready. Before that Usable() is true and Want() does nothing.
;
; onDone(result, message, exports) is called once per job, from the message loop.
class WorkerBridge {
    static ACK_TIMEOUT_MS := 5000
    static ORPHAN_MS := 2000
    static MAX_SIZE := 8
    static DEFAULT_SIZE := 4
    static DEFAULT_WARM := 1
    static DEFAULT_IDLE_MS := 60000
    static MIN_IDLE_MS := 100
    static MAX_IDLE_MS := 3600000
    static STORM_MAX := 5
    static STORM_WINDOW_MS := 60000
    static SPAWN_TIMEOUT_MS := 5000
    static LIST_TIMEOUT_MS := 5000
    static KILL_TIMEOUT_MS := 5000

    __New(owner, size, warm := 0, idleMs := 60000) {
        this._owner := owner
        this._size := size
        this._warm := Min(warm, size)
        this._idleMs := idleMs
        this._slots := []                      ; Maps: name, state, execId, idleSince (monotonic ms)
        this._jobs := Map()                    ; execId -> Map("onDone", fn, "slot", name, "deadline", timer fn or "")
        this._jobs.CaseSense := "Off"
        this._spawning := 0                    ; cmd.process.spawn requests on their way
        this._failures := []                   ; times (ms) of the abnormal ends in the storm window
        this._earlyReady := Map()              ; names whose evt.process.ready came before their spawn answer
        this._earlyGone := Map()               ; names whose crash or exit came before their spawn answer (F-0093)
        this._started := false                 ; Start() was called
        this._ready := false                   ; the orphans are gone, the pool may grow
        this._stopped := false                 ; the engine shuts down
        this._blockedLogged := false
        this._maintFn := ObjBindMethod(this, "_Maintain")
    }

    ; N, the most workers at once. 0: no pool.
    Size => this._size

    ; The pool for the snapshot (doc/PROTOCOL.md 4.9): size, warm workers, the slots with their state, starts on
    ; their way and the abnormal ends in the storm window.
    DiagInfo() {
        slots := []
        for slot in this._slots
            slots.Push(Map("name", slot["name"], "state", slot["state"], "execId", slot["execId"]))
        return Map("size", this._size, "warm", this._warm, "slots", slots, "spawning", this._spawning
            , "failures", this._FailureCount())
    }

    ; The number of slots that exist now (starting, idle, busy).
    Count => this._slots.Length

    ; Number of slots in a state.
    CountState(state) {
        n := 0
        for slot in this._slots {
            if (slot["state"] = state)
                n += 1
        }
        return n
    }

    ; True if a slot can take a job now.
    Free() {
        for slot in this._slots {
            if (slot["state"] = "idle")
                return true
        }
        return false
    }

    ; True if a job can run now or soon: a worker exists or is on its way, or the pool may start one. False for no
    ; pool, a stopped pool, and a blocked pool without any worker: then the job ends with "worker not available".
    Usable() {
        if (this._size = 0 || this._stopped)
            return false
        if (!this._ready)
            return true
        if (this._slots.Length > 0 || this._spawning > 0)
            return true
        return !this._Blocked()
    }

    ; --- life cycle ----------------------------------------------------------------------------

    ; Called when the engine is connected: kills the workers of an earlier engine, then lets the pool start.
    Start() {
        if (this._size = 0 || this._started || this._stopped)
            return
        this._started := true
        try {
            this._owner.peer.Request("supervisor", "cmd.process.list", Map(), ObjBindMethod(this, "_OnProcessList")
                , WorkerBridge.LIST_TIMEOUT_MS)
        } catch as e {
            Log.Write("a0", "engine", "worker pool: process list not requested: " Type(e) ": " e.Message)
            this._BecomeReady()
        }
    }

    ; The engine shuts down: no more workers are asked for or killed (the supervisor ends them in rank 3).
    Stop() {
        this._stopped := true
        SetTimer(this._maintFn, 0)
    }

    _OnProcessList(res) {
        if (res.payload.Get("ok", false)) {
            for proc in res.payload.Get("processes", []) {
                name := proc.Get("name", "")
                state := proc.Get("state", "")
                if (!RegExMatch(name, "^worker:\d+$") || state = "exited" || state = "crashed")
                    continue
                if (!IsObject(this._SlotNamed(name))) {
                    Log.Write("a1", "engine", "worker pool: ending " name " (state " state "), it belongs to an earlier engine")
                    this._Kill(name, "orphan of a previous engine")
                }
            }
        } else {
            Log.Write("a0", "engine", "worker pool: process list failed (" WorkerBridge._ErrorText(res) "), orphans may remain")
        }
        this._BecomeReady()
    }

    _BecomeReady() {
        this._ready := true
        this._Maintain()
        this._owner.Kick()
    }

    ; --- jobs ----------------------------------------------------------------------------------

    ; Starts a job on an idle slot. Returns the execId, or "" when no slot is idle.
    ; params and imports are Maps, env is a Map with flowId, elementId, instanceId and threadId.
    ; jobTimeoutMs > 0: the job ends with "worker timeout" after that long (class property JobTimeoutMs).
    ; evaluated: the parameters evaluated by the engine (E0026, WI-0042), an Array of Maps {id, value} or {id, error} in the
    ; order of Parameters(); sent as the field "evaluated" (PROTOCOL 4.5).
    ; ctx: the engine context of the element (ExecContext); the variable requests of the job use it (JobOf, WI-0050).
    Run(classId, params, imports, env, onDone, jobTimeoutMs := 0, evaluated := "", ctx := "") {
        slot := this._IdleSlot()
        if (!IsObject(slot))
            return ""
        execId := Ids.Next("exec-")
        slot["state"] := "busy"
        slot["execId"] := execId
        jobRec := Map("onDone", onDone, "slot", slot["name"], "deadline", "", "ctx", ctx)
        this._jobs[execId] := jobRec
        if (jobTimeoutMs > 0) {
            jobRec["deadline"] := ObjBindMethod(this, "_JobExpired", execId)
            SetTimer(jobRec["deadline"], -jobTimeoutMs)
        }
        payload := Map("execId", execId, "class", classId, "params", params, "imports", imports, "env", env
            , "evaluated", (evaluated is Array) ? evaluated : [], "timeoutMs", WorkerBridge.ACK_TIMEOUT_MS)
        try {
            this._owner.peer.Request(slot["name"], "cmd.worker.run", payload
                , ObjBindMethod(this, "_OnRunAnswer", execId), WorkerBridge.ACK_TIMEOUT_MS)
        } catch as e {
            this._Lose(slot, "run not sent: " Type(e))
            this._Finish(execId, "exception", "worker not available: " slot["name"] " (" Type(e) ")")
        }
        return execId
    }

    ; The most recently used idle slot (so the others can reach their idle end). "" if none.
    _IdleSlot() {
        best := ""
        for slot in this._slots {
            if (slot["state"] = "idle" && (!IsObject(best) || slot["idleSince"] > best["idleSince"]))
                best := slot
        }
        return best
    }

    ; The running job execId for a variable request (WI-0050, VarRequests): Map("ctx", engine context of the element,
    ; "slot", name of the worker that runs it), or "" when the job is not running: finished, cancelled (Cancel forgets
    ; the job before cmd.worker.cancel leaves), ended by its deadline or by the loss of its worker.
    JobOf(execId) {
        jobRec := this._jobs.Get(execId, "")
        return IsObject(jobRec) ? Map("ctx", jobRec["ctx"], "slot", jobRec["slot"]) : ""
    }

    ; Stops a job (the element is stopped by the worker). Returns false if the job is unknown.
    Cancel(execId) {
        jobRec := this._TakeJob(execId)
        if (!IsObject(jobRec))
            return false
        this._CancelOnWorker(execId, jobRec["slot"])
        return true
    }

    ; Asks the worker to stop the element and waits ORPHAN_MS for its evt.worker.done.
    _CancelOnWorker(execId, slotName) {
        try {
            this._owner.peer.Request(slotName, "cmd.worker.cancel", Map("execId", execId)
                , ObjBindMethod(this, "_OnCancelAnswer", execId), WorkerBridge.ACK_TIMEOUT_MS)
        } catch as e {
            Log.Write("a1", "engine", "cancel of " execId " not sent: " Type(e) ": " e.Message)
        }
        SetTimer(ObjBindMethod(this, "_OrphanExpired", execId), -WorkerBridge.ORPHAN_MS)
    }

    ; evt.worker.done from a worker.
    OnDone(msg) {
        execId := msg.payload.Get("execId", "")
        result := msg.payload.Get("result", "exception")
        msgText := msg.payload.Get("message", "")
        exports := msg.payload.Get("exports", Map())
        if (!(exports is Map))
            exports := Map()
        slot := this._SlotRunning(execId)
        if (IsObject(slot)) {
            slot["execId"] := ""
            if (slot["state"] = "busy")
                this._SetIdle(slot)
        }
        jobRec := this._TakeJob(execId)
        if (IsObject(jobRec))
            this._Call(jobRec, result, msgText, exports, execId)
        this._owner.Kick()
    }

    ; --- processes -----------------------------------------------------------------------------

    ; evt.process.* from the supervisor (topic "process"). Only the workers of this pool are looked at.
    OnProcessEvent(msg) {
        name := msg.payload.Get("name", "")
        if (!RegExMatch(name, "^worker:\d+$"))
            return
        slot := this._SlotNamed(name)
        if (msg.type = "evt.process.ready") {
            if (!IsObject(slot)) {
                if (this._spawning > 0)             ; the spawn answer follows (or the worker is not ours)
                    this._earlyReady[name] := true
            } else if (slot["state"] = "starting") {
                this._SetIdle(slot)
                this._owner.Kick()
            }
        } else if (msg.type = "evt.process.crashed" || msg.type = "evt.process.exited") {
            if (this._earlyReady.Has(name))
                this._earlyReady.Delete(name)
            if (!IsObject(slot)) {
                ; Not ours, or one we ended ourselves, or one that ended before its spawn answer arrived (F-0093):
                ; then the answer must not create a slot for it.
                if (this._spawning > 0)
                    this._earlyGone[name] := msg.type
                return
            }
            execId := slot["execId"]
            this._RemoveSlot(slot)
            if (execId != "")
                this._Finish(execId, "exception", "worker crashed (" name ")")
            if (!this._stopped) {
                this._Failure(name " ended unexpectedly (" msg.type ")")
                this._Maintain()
            }
            this._owner.Kick()
        }
    }

    ; --- demand --------------------------------------------------------------------------------

    ; The Executor has `waiting` threads that wait for a worker and no slot is idle: ask for workers.
    Want(waiting) {
        if (!this._ready || this._stopped || waiting <= 0)
            return
        this._SpawnUpTo(waiting - this.CountState("starting") - this._spawning, "demand")
    }

    ; Asks for up to n workers without exceeding N or the storm limit.
    _SpawnUpTo(n, why) {
        loop n {
            if (this._slots.Length + this._spawning >= this._size)
                return
            if (this._Blocked()) {
                this._LogBlockedOnce()
                return
            }
            this._RequestSpawn(why)
        }
    }

    _RequestSpawn(why) {
        this._spawning += 1
        try {
            this._owner.peer.Request("supervisor", "cmd.process.spawn", Map("role", "worker")
                , ObjBindMethod(this, "_OnSpawn", why), WorkerBridge.SPAWN_TIMEOUT_MS)
        } catch as e {
            this._spawning -= 1
            this._ForgetEarlyEvents()
            this._Failure("worker not requested: " Type(e) ": " e.Message)
        }
    }

    _OnSpawn(why, res) {
        this._spawning -= 1
        try {
            this._HandleSpawnAnswer(why, res)
        } finally {
            this._ForgetEarlyEvents()
        }
    }

    _HandleSpawnAnswer(why, res) {
        if (this._stopped)
            return
        if (!res.payload.Get("ok", false)) {
            this._Failure("worker not started: " WorkerBridge._ErrorText(res))
            if (why = "demand")
                this._owner.Kick()                  ; try again (the failure counter ends it)
            return
        }
        name := res.payload.Get("name", "")
        if (this._earlyGone.Has(name)) {
            ; The worker ended before the answer arrived: no slot, a failure like any other unexpected end.
            this._earlyGone.Delete(name)
            if (this._earlyReady.Has(name))
                this._earlyReady.Delete(name)
            this._Failure(name " ended before its start was answered")
            this._Maintain()
            this._owner.Kick()
            return
        }
        slot := Map("name", name, "state", "starting", "execId", "", "idleSince", 0)
        this._slots.Push(slot)
        if (this._earlyReady.Has(name)) {
            this._earlyReady.Delete(name)
            this._SetIdle(slot)
        }
        this._owner.Kick()
    }

    ; Early events (ready or ended before the spawn answer) are only kept while a spawn answer is on its way; a failed
    ; spawn has no name to match them with (F-0093).
    _ForgetEarlyEvents() {
        if (this._spawning = 0) {
            this._earlyReady.Clear()
            this._earlyGone.Clear()
        }
    }

    ; --- maintenance (warm workers, idle end) ----------------------------------------------------

    _Maintain() {
        SetTimer(this._maintFn, 0)
        if (!this._ready || this._stopped || this._size = 0)
            return
        total := this._slots.Length + this._spawning
        if (total < this._warm)
            this._SpawnUpTo(this._warm - total, "warm")
        now := Time.NowMs()
        for slot in this._slots.Clone() {
            if (slot["state"] != "idle" || this._slots.Length <= this._warm)
                continue
            if (slot["idleSince"] + this._idleMs <= now) {
                this._RemoveSlot(slot)
                Log.Write("a1", "engine", "worker pool: " slot["name"] " idle for " this._idleMs " ms, ending it")
                this._Kill(slot["name"], "idle")
            }
        }
        this._ScheduleMaint()
    }

    ; One timer for the earliest idle end among the slots beyond W. Called whenever a slot becomes idle.
    _ScheduleMaint() {
        SetTimer(this._maintFn, 0)
        if (this._slots.Length <= this._warm)
            return
        next := 0
        for slot in this._slots {
            if (slot["state"] != "idle")
                continue
            due := slot["idleSince"] + this._idleMs
            if (next = 0 || due < next)
                next := due
        }
        if (next > 0)
            SetTimer(this._maintFn, -Max(1, Integer(next - Time.NowMs()) + 1))
    }

    _SetIdle(slot) {
        slot["state"] := "idle"
        slot["idleSince"] := Time.NowMs()
        this._ScheduleMaint()
    }

    ; --- answers and timers --------------------------------------------------------------------

    _OnRunAnswer(execId, res) {
        if (res.payload.Get("ok", false))
            return
        code := "internal"
        err := res.payload.Get("error", "")
        if (err is Map)
            code := err.Get("code", code)
        jobRec := this._jobs.Get(execId, "")
        if (!IsObject(jobRec))
            return
        slot := this._SlotNamed(jobRec["slot"])
        if (IsObject(slot))
            this._Lose(slot, "run not accepted: " code)
        if (code = ErrCode.PEER_GONE) {
            ; The hub answers peer_gone as soon as the worker's connection ends, usually a tick before the supervisor
            ; reports the end of the process. The worker is lost, not refusing: same text as evt.process.crashed, so the
            ; order of the two messages does not matter (F-0042, WI-0035).
            this._Finish(execId, "exception", "worker crashed (" jobRec["slot"] ")")
        } else {
            this._Finish(execId, "exception", "worker not available: " jobRec["slot"] " (" code ")")
        }
        this._owner.Kick()
    }

    _OnCancelAnswer(execId, res) {
        if (!res.payload.Get("ok", false))
            Log.Write("a1", "engine", "cancel of " execId " not confirmed: " WorkerBridge._ErrorText(res))
    }

    ; No evt.worker.done after the cancel: the worker is blocked. Remove it and have the supervisor kill it.
    _OrphanExpired(execId) {
        slot := this._SlotRunning(execId)
        if (!IsObject(slot))
            return
        Log.Write("a0", "engine", "worker " slot["name"] " did not confirm the cancel of " execId ", ending it")
        this._RemoveSlot(slot)
        this._Kill(slot["name"], "cancel not confirmed")
        if (!this._stopped)
            this._Maintain()
        this._owner.Kick()
    }

    ; The job deadline of the element passed: the thread ends now, the worker is cancelled like any other.
    _JobExpired(execId) {
        jobRec := this._jobs.Get(execId, "")
        if (!IsObject(jobRec))
            return
        slotName := jobRec["slot"]
        Log.Write("a0", "engine", "job " execId " on " slotName " passed its deadline")
        if (this._Finish(execId, "exception", "worker timeout"))
            this._CancelOnWorker(execId, slotName)
    }

    ; Ends a job that the engine decides on (answer error, crash, deadline). No exports.
    _Finish(execId, result, message) {
        jobRec := this._TakeJob(execId)
        if (!IsObject(jobRec))
            return false
        this._Call(jobRec, result, message, Map(), execId)
        return true
    }

    ; Takes the job out of the table and stops its deadline timer. Returns its record, or "" if it is gone.
    ; The Delete is the check and the removal in one step: of two callers that race (the answer and the
    ; deadline timer, F-0012) only one gets the record. A Get followed by a Delete lets both get it, and the
    ; job then ends twice.
    _TakeJob(execId) {
        try {
            jobRec := this._jobs.Delete(execId)
        } catch {
            return ""
        }
        if (IsObject(jobRec["deadline"]))
            SetTimer(jobRec["deadline"], 0)
        return jobRec
    }

    _Call(job, result, message, exports, execId) {
        try {
            job["onDone"](result, message, exports)
        } catch as e {
            Log.Write("a0", "engine", "worker result of " execId " not applied: " Type(e) ": " e.Message)
        }
    }

    ; --- failures and the supervisor ---------------------------------------------------------------

    ; A worker that cannot be trusted any more (refused job, send error): out of the pool, killed, counted.
    _Lose(slot, why) {
        this._RemoveSlot(slot)
        this._Kill(slot["name"], why)
        this._Failure(slot["name"] ": " why)
        if (!this._stopped)
            this._Maintain()
    }

    _Failure(text) {
        now := Time.NowMs()
        this._failures.Push(now)
        Log.Write("a0", "engine", "worker pool: " text " (" this._FailureCount() " failure(s) in "
            . WorkerBridge.STORM_WINDOW_MS " ms)")
    }

    _FailureCount() {
        now := Time.NowMs()
        while (this._failures.Length > 0 && now - this._failures[1] >= WorkerBridge.STORM_WINDOW_MS)
            this._failures.RemoveAt(1)
        return this._failures.Length
    }

    _Blocked() {
        blocked := this._FailureCount() >= WorkerBridge.STORM_MAX
        if (!blocked)
            this._blockedLogged := false
        return blocked
    }

    _LogBlockedOnce() {
        if (this._blockedLogged)
            return
        this._blockedLogged := true
        Log.Write("a0", "engine", "worker pool blocked: " WorkerBridge.STORM_MAX " failures within "
            . WorkerBridge.STORM_WINDOW_MS " ms, no new workers until the oldest has passed")
    }

    ; Asks the supervisor to kill a worker. The answer is only logged.
    _Kill(name, reason) {
        if (this._stopped)
            return
        try {
            this._owner.peer.Request("supervisor", "cmd.process.kill", Map("name", name, "reason", reason)
                , ObjBindMethod(this, "_OnKillAnswer", name), WorkerBridge.KILL_TIMEOUT_MS)
        } catch as e {
            Log.Write("a0", "engine", "worker pool: kill of " name " not sent: " Type(e) ": " e.Message)
        }
    }

    _OnKillAnswer(name, res) {
        if (!res.payload.Get("ok", false))
            Log.Write("a0", "engine", "worker pool: kill of " name " failed: " WorkerBridge._ErrorText(res))
    }

    ; --- slots ---------------------------------------------------------------------------------

    static _ErrorText(res) {
        err := res.payload.Get("error", "")
        if (err is Map)
            return err.Get("code", "") ": " err.Get("message", "")
        return "no error details"
    }

    _RemoveSlot(slot) {
        for i, s in this._slots {
            if (s["name"] = slot["name"]) {
                this._slots.RemoveAt(i)
                return
            }
        }
    }

    _SlotRunning(execId) {
        if (execId = "")
            return ""
        for slot in this._slots {
            if (slot["execId"] = execId)
                return slot
        }
        return ""
    }

    _SlotNamed(name) {
        for slot in this._slots {
            if (slot["name"] = name)
                return slot
        }
        return ""
    }
}
