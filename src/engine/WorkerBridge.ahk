#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Ids.ahk
#Include ..\core\Log.ahk

; Engine side of the worker pool (WI-11, PROTOCOL 4.5, ARCHITECTURE 2.3 and 6.2). Knows the slots
; worker:1 .. worker:n and the jobs in flight. It never waits: a job is sent with cmd.worker.run, its
; answer and evt.worker.done come back as messages, and every job ends through its onDone callback.
;
; Slot states: "idle" (may take a job), "busy" (has a job, or an orphan that is still running after a
; cancel), "down" (the last request failed or the process crashed/exited; it becomes "idle" again on
; evt.process.ready). Slots are never restarted here: the supervisor restarts only storage and engine.
;
; Jobs: Run returns the execId or "" when no slot is idle. Cancel forgets the job at once (the engine
; treats the element as stopped, PROTOCOL 4.3) and keeps the slot busy until the worker reports
; evt.worker.done, or ORPHAN_MS passes, then the slot is "down". A crashed worker ends its job with
; the exception "worker crashed".
;
; onDone(result, message, exports) is called once per job, from the message loop.
class WorkerBridge {
    static ACK_TIMEOUT_MS := 5000
    static ORPHAN_MS := 2000
    static MAX_SIZE := 8

    __New(owner, size) {
        this._owner := owner
        this._slots := []
        this._jobs := Map()                    ; execId -> Map("onDone", fn, "slot", name)
        this._jobs.CaseSense := "Off"
        loop size {
            this._slots.Push(Map("name", "worker:" A_Index, "state", "idle", "execId", ""))
        }
    }

    Size => this._slots.Length

    ; True if a slot can take a job now.
    Free() {
        for slot in this._slots {
            if (slot["state"] = "idle")
                return true
        }
        return false
    }

    ; True if some slot is not down. With no slot, or only down ones, a job cannot run at all.
    Usable() {
        for slot in this._slots {
            if (slot["state"] != "down")
                return true
        }
        return false
    }

    ; Starts a job on an idle slot. Returns the execId, or "" when no slot is idle.
    ; params and imports are Maps, env is a Map with flowId, elementId, instanceId and threadId.
    Run(classId, params, imports, env, onDone) {
        slot := ""
        for s in this._slots {
            if (s["state"] = "idle") {
                slot := s
                break
            }
        }
        if (!IsObject(slot))
            return ""
        execId := Ids.Next("exec-")
        slot["state"] := "busy"
        slot["execId"] := execId
        this._jobs[execId] := Map("onDone", onDone, "slot", slot["name"])
        payload := Map("execId", execId, "class", classId, "params", params, "imports", imports, "env", env
            , "timeoutMs", WorkerBridge.ACK_TIMEOUT_MS)
        try {
            this._owner.peer.Request(slot["name"], "cmd.worker.run", payload
                , ObjBindMethod(this, "_OnRunAnswer", execId), WorkerBridge.ACK_TIMEOUT_MS)
        } catch as e {
            slot["state"] := "down"
            this._Finish(execId, "exception", "worker not available: " slot["name"] " (" Type(e) ")")
        }
        return execId
    }

    ; Stops a job (the element is stopped by the worker). Returns false if the job is unknown.
    Cancel(execId) {
        job := this._jobs.Get(execId, "")
        if (!IsObject(job))
            return false
        this._jobs.Delete(execId)
        this._owner.peer.Request(job["slot"], "cmd.worker.cancel", Map("execId", execId)
            , ObjBindMethod(this, "_OnCancelAnswer", execId), WorkerBridge.ACK_TIMEOUT_MS)
        SetTimer(ObjBindMethod(this, "_OrphanExpired", execId), -WorkerBridge.ORPHAN_MS)
        return true
    }

    ; evt.worker.done from a worker.
    OnDone(msg) {
        execId := msg.payload.Get("execId", "")
        result := msg.payload.Get("result", "exception")
        message := msg.payload.Get("message", "")
        exports := msg.payload.Get("exports", Map())
        if (!(exports is Map))
            exports := Map()
        slot := this._SlotRunning(execId)
        if (IsObject(slot)) {
            slot["execId"] := ""
            if (slot["state"] = "busy")
                slot["state"] := "idle"
        }
        job := this._jobs.Get(execId, "")
        if (IsObject(job)) {
            this._jobs.Delete(execId)
            this._Call(job, result, message, exports, execId)
        }
        this._owner.Kick()
    }

    ; sys process events from the supervisor (topic "process"). Only worker slots are looked at.
    OnProcessEvent(msg) {
        name := msg.payload.Get("name", "")
        slot := this._SlotNamed(name)
        if (!IsObject(slot))
            return
        if (msg.type = "evt.process.ready") {
            if (slot["state"] = "down" && slot["execId"] = "")
                slot["state"] := "idle"
            this._owner.Kick()
        } else if (msg.type = "evt.process.crashed" || msg.type = "evt.process.exited") {
            slot["state"] := "down"
            execId := slot["execId"]
            if (execId != "") {
                slot["execId"] := ""
                this._Finish(execId, "exception", "worker crashed (" name ")")
            }
            this._owner.Kick()
        }
    }

    ; --- answers and timers --------------------------------------------------------------------

    _OnRunAnswer(execId, res) {
        if (res.payload.Get("ok", false))
            return
        code := "internal"
        err := res.payload.Get("error", "")
        if (err is Map)
            code := err.Get("code", code)
        job := this._jobs.Get(execId, "")
        if (!IsObject(job))
            return
        slot := this._SlotNamed(job["slot"])
        if (IsObject(slot)) {
            slot["state"] := "down"
            slot["execId"] := ""
        }
        this._Finish(execId, "exception", "worker not available: " job["slot"] " (" code ")")
        this._owner.Kick()
    }

    _OnCancelAnswer(execId, res) {
        if (!res.payload.Get("ok", false))
            Log.Write("a1", "engine", "cancel of " execId " not confirmed: " WorkerBridge._ErrorText(res))
    }

    _OrphanExpired(execId) {
        slot := this._SlotRunning(execId)
        if (!IsObject(slot))
            return
        slot["state"] := "down"
        slot["execId"] := ""
        Log.Write("a0", "engine", "worker " execId " did not confirm the cancel, slot is down")
        this._owner.Kick()
    }

    ; Ends a job that the engine decides on (answer error, crash). No exports.
    _Finish(execId, result, message) {
        job := this._jobs.Get(execId, "")
        if (!IsObject(job))
            return false
        this._jobs.Delete(execId)
        this._Call(job, result, message, Map(), execId)
        return true
    }

    _Call(job, result, message, exports, execId) {
        try {
            job["onDone"](result, message, exports)
        } catch as e {
            Log.Write("a0", "engine", "worker result of " execId " not applied: " Type(e) ": " e.Message)
        }
    }

    ; --- slots ---------------------------------------------------------------------------------

    static _ErrorText(res) {
        err := res.payload.Get("error", "")
        if (err is Map)
            return err.Get("code", "") ": " err.Get("message", "")
        return "no error details"
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
