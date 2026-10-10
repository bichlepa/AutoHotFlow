#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Log.ahk
#Include ..\core\Role.ahk
#Include ..\elements\base\ElementRegistry.ahk
#Include ..\elements\base\ElementRunner.ahk
#Include WorkerContext.ahk

; Worker role (WI-11, ARCHITECTURE 2.3, PROTOCOL 4.5). One worker process runs one element at a time.
; Blocking calls are allowed here, because this process is the only one that may block. The engine
; never waits for it: cmd.worker.run is answered at once with ok, the result comes later as
; evt.worker.done.
;
; Blocking and pings: AHK v2 has one thread per process. While an element runs, the peer answers
; sys.ping only if the element yields (Sleep, a timer, a message wait). An element that loops in
; DllCall("Sleep") does not yield, so the supervisor sees it as hung after about 6 s and ends the
; process. Decision for WI-11 (see work_items/phase2/WI-11-worker.md, open points): no heartbeat
; tolerance. Blocking elements must yield in slices, or they are ended as hung.
;
; Cancel: cmd.worker.cancel stops the running element through ElementRunner.Stop and sends
; evt.worker.done with result "stopped". A later Finish of the element is ignored. An element that
; does not yield cannot receive the cancel at all (see above).
;
; Exactly one execution at a time. A second cmd.worker.run is answered with "busy". The engine does
; the pool work. timeoutMs of cmd.worker.run is not used here (the engine owns the deadlines).
class Worker extends Role {
    __New(args) {
        super.__New(args)
        this._job := ""                 ; Map of the running job, or "" when idle (see _CmdRun)
        this._startFn := () => this._StartJob()
    }

    RegisterHandlers() {
        this.On("cmd.worker.run", (msg) => this._CmdRun(msg))
        this.On("cmd.worker.cancel", (msg) => this._CmdCancel(msg))
    }

    ; sys.shutdown: a running element is stopped and reported before sys.bye (ARCHITECTURE 6.3).
    OnShutdown(deadlineMs) {
        this._StopCurrent(true)
    }

    ; --- commands ------------------------------------------------------------------------------

    ; Accepts a job. The element starts on the next timer tick, after this answer has been sent.
    _CmdRun(msg) {
        if (this._job != "")
            throw AhfError("worker is busy with '" this._job["execId"] "'", ErrCode.BUSY)
        execId := Worker._Text(msg, "execId")
        classId := Worker._Text(msg, "class")
        params := Worker._Map(msg, "params")
        imports := Worker._Map(msg, "imports")
        env := Worker._Map(msg, "env")
        job := Map("execId", execId, "classId", classId, "params", params, "imports", imports, "env", env
            , "started", false, "cls", "", "ctx", "")
        this._job := job
        SetTimer(this._startFn, -1)
        return Map()
    }

    _CmdCancel(msg) {
        execId := Worker._Text(msg, "execId")
        if (this._job = "" || this._job["execId"] != execId)
            throw AhfError("no running job '" execId "'", ErrCode.NOT_FOUND)
        this._StopCurrent(false)
        return Map()
    }

    ; --- execution -----------------------------------------------------------------------------

    _StartJob() {
        job := this._job
        if (!IsObject(job) || job["started"])
            return
        job["started"] := true
        execId := job["execId"]
        env := job["env"]
        ctx := WorkerContext(env.Get("flowId", ""), env.Get("elementId", ""), env.Get("instanceId", "")
            , env.Get("threadId", ""), job["imports"], ObjBindMethod(this, "_OnFinish", execId))
        job["ctx"] := ctx
        cls := ElementRegistry.Get(job["classId"])
        if (!IsObject(cls)) {
            ctx.Finish("exception", "unknown element class '" job["classId"] "'")
            return
        }
        if (cls.Mode != "worker") {
            ctx.Finish("exception", "element " job["classId"] " is not a worker element (mode " cls.Mode ")")
            return
        }
        job["cls"] := cls
        ElementRunner.Run(cls, ctx, Worker._Params(job["params"]))
    }

    ; Called by the context when the element finishes (bound: execId first). Only the current job counts.
    _OnFinish(execId, ctx, result, msg) {
        job := this._job
        if (!IsObject(job) || job["execId"] != execId) {
            this._Log("f2", "worker", "late finish '" result "' for " execId " ignored")
            return
        }
        this._job := ""
        this._SendDone(execId, result, msg, ctx.exports)
    }

    ; Stops the running job: element Stop (timers cancelled), then evt.worker.done "stopped".
    ; deferSend: send the event on the next tick (cancel answer first), or at once (shutdown).
    _StopCurrent(sendNow) {
        job := this._job
        if (!IsObject(job))
            return
        this._job := ""
        ctx := job["ctx"]
        if (job["started"] && IsObject(job["cls"]) && IsObject(ctx))
            ElementRunner.Stop(job["cls"], ctx, Worker._Params(job["params"]))
        execId := job["execId"]
        exports := IsObject(ctx) ? ctx.exports : Map()
        if (sendNow)
            this._SendDone(execId, "stopped", "", exports)
        else
            SetTimer(() => this._SendDone(execId, "stopped", "", exports), -1)
    }

    _SendDone(execId, result, msg, exports) {
        this.peer.Send("engine", "evt.worker.done", Map("execId", execId, "result", result
            , "message", String(msg), "exports", Worker._Plain(exports)))
    }

    ; --- helpers -------------------------------------------------------------------------------

    ; A required text field. Missing, empty or non-scalar values are bad_payload.
    static _Text(msg, key) {
        v := msg.payload.Get(key, "")
        if (IsObject(v) || v = "")
            throw AhfError("payload field '" key "' is missing", ErrCode.BAD_PAYLOAD)
        return String(v)
    }

    ; An optional object field (Map), empty Map when missing.
    static _Map(msg, key) {
        v := msg.payload.Get(key, "")
        if (v = "")
            return Map()
        if (!(v is Map))
            throw AhfError("payload field '" key "' must be an object", ErrCode.BAD_PAYLOAD)
        return v
    }

    ; Element parameters as an object with case-insensitive properties (same rule as the engine).
    static _Params(source) {
        p := {}
        for k, v in source {
            if (IsObject(v))
                v := ""
            p.%k% := v
        }
        return p
    }

    ; Exports as a plain Map for the JSON encoder (keys in the spelling of the element).
    static _Plain(exports) {
        out := Map()
        for k, v in exports
            out[k] := v
        return out
    }
}

