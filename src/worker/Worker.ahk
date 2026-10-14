#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Log.ahk
#Include ..\core\Role.ahk
#Include ..\core\Time.ahk
#Include ..\elements\base\ElementRegistry.ahk
#Include ..\elements\base\ElementRunner.ahk
#Include WorkerContext.ahk

; Worker role (WI-11, ARCHITECTURE 2.3, PROTOCOL 4.5). One worker process runs one element at a time.
; Blocking calls are allowed here, because this process is the only one that may block. The engine
; never waits for it: cmd.worker.run is answered at once with ok, the result comes later as
; evt.worker.done.
;
; Blocking and pings: AHK v2 has one thread per process. Between script lines AHK checks for
; window messages, so an element that waits in short slices (Sleep, or a loop of DllCall("Sleep", 100))
; still answers sys.ping and cancel. A single long blocking call (download, COM call, long DllCall) does not.
; Since WI-27 (decision E3, ARCHITECTURE 6.4) that is allowed: the worker reports to the supervisor when a job
; begins and ends (sys.busy {busy}). The supervisor neither pings a busy worker nor judges its pongs, so a long
; blocking call does not make it "hung". The decision of WI-11 ("no heartbeat tolerance") is replaced by this.
; What stays: a busy worker whose process dies is seen at once (process handle). One that blocks for ever ends
; only by a cancel that is not confirmed in 2 s, or by the job deadline of the element: the engine then asks the
; supervisor to kill it (cmd.process.kill). The worker never decides that for itself.
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

    ; Role part of the snapshot (doc/PROTOCOL.md 4.9): the current job (class and execId, no parameters), or "".
    DiagInfo() {
        job := this._job
        if (!IsObject(job))
            return Map("job", "")
        return Map("job", Map("execId", job["execId"], "class", job["classId"]
            , "sinceMs", Integer(Time.NowMs() - job["startedMs"])))
    }

    ; After a reconnect to the hub the supervisor does not know whether a job is running: a sys.busy sent while the
    ; link was down is dropped (Peer.Send), either direction. So the current state is always announced (F-30).
    OnReady() {
        this.SetLogTarget("storage")    ; F-28: without a target the entries of the worker (and of its elements) were never written
        this._ReportBusy(this._job != "")
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
        evaluated := Worker._List(msg, "evaluated")
        job := Map("execId", execId, "classId", classId, "params", params, "imports", imports, "env", env
            , "evaluated", evaluated
            , "started", false, "cls", "", "ctx", "", "startedMs", Time.NowMs())  ; arch-ok: wire-bool internal job record, never sent
        this._job := job
        this._ReportBusy(true)          ; before the element starts: it may block for long (see the head of this file)
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
        ; The variable functions of the element ask the engine through the peer (WI-50, PROTOCOL 4.5).
        ctx := WorkerContext(env.Get("flowId", ""), env.Get("elementId", ""), env.Get("instanceId", "")
            , env.Get("threadId", ""), job["imports"], ObjBindMethod(this, "_OnFinish", execId), job["evaluated"]
            , execId, ObjBindMethod(this.peer, "Request"))
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
        if (IsObject(ctx))
            ctx.stopped := true         ; no ctx.Request callback runs any more (WI-50)
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
        if (this._job = "")             ; a newer job (not possible while the engine waits for this event) keeps the flag
            this._ReportBusy(false)
        this.peer.Send("engine", "evt.worker.done", Map("execId", execId, "result", result
            , "message", String(msg), "exports", Worker._Plain(exports)))
    }

    ; Tells the supervisor that a job begins or ends (PROTOCOL 4.1, sys.busy). No answer.
    _ReportBusy(busy) {
        this.peer.Send("supervisor", "sys.busy", Map("busy", Json.Bool(busy)))
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

    ; An optional list field (Array), empty Array when missing. Each entry of "evaluated" (E26) must be an object with
    ; an id; anything else is bad_payload.
    static _List(msg, key) {
        v := msg.payload.Get(key, "")
        if (v = "")
            return []
        if (!(v is Array))
            throw AhfError("payload field '" key "' must be an array", ErrCode.BAD_PAYLOAD)
        for entry in v {
            if (!(entry is Map) || !entry.Has("id"))
                throw AhfError("payload field '" key "' must hold objects with an id", ErrCode.BAD_PAYLOAD)
        }
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

