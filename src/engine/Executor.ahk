#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Ids.ahk
#Include ..\core\Log.ahk
#Include ..\elements\base\ElementRegistry.ahk
#Include ..\elements\base\ElementRunner.ahk
#Include ..\elements\base\ExecContext.ahk
#Include ..\elements\base\VarStore.ahk
#Include core\ExecutionPolicy.ahk
#Include core\FlowDefinition.ahk
#Include core\Instance.ahk
#Include core\Scheduler.ahk
#Include core\ThreadState.ahk
#Include WorkerBridge.ahk

; Runs the instances of the engine (WI-10, ARCHITECTURE 2.3, 5.1, 5.2, 6.2). Runs the state machines of
; engine/core and calls the elements through ElementRunner. Knows nothing about IPC: it reports through
; owner.Emit, owner.EmitFlowState and owner.Kick (implemented by Engine).
;
; Dispatching is event driven: a state change calls owner.Kick (a timer runs Tick once). Tick starts every
; ready thread. A run of Tick is limited to TICK_BATCH dispatches, then it schedules itself again, so a flow
; of synchronous elements cannot keep the message loop busy.
;
; Modes (ELEMENT-API-V2 section 2): inline runs here. worker goes to the pool (WorkerBridge, WI-11): the thread
; waits in state ready while every worker is busy, and ends with "exception" ("worker not available") when no
; worker is usable at all. trigger cannot be an action.
;
; Parameters are passed as they are stored in the flow file (object with case-insensitive properties).
; Expressions are not evaluated in Phase 2 (ARCHITECTURE, WI-10 "Nicht Teil"), so Duration "200" arrives as
; text. Action_Sleep converts it with IsNumber.
class Executor {
    static TICK_BATCH := 1000

    __New(owner) {
        this._owner := owner
        this._runs := Map()       ; instanceId -> run (Map, see _NewRun)
        this._counts := Map()     ; "flowId/elementId" -> countRuns (v1 semantics)
        this._lastRun := Map()    ; "flowId/elementId" -> "yyyy-MM-dd HH:mm:ss" of the last start
        this._counts.CaseSense := "Off"
        this._lastRun.CaseSense := "Off"
    }

    ; True if an instance of the flow is running or stopping.
    IsExecuting(flowId) {
        for _, run in this._runs {
            if (run["flowId"] = flowId)
                return true
        }
        return false
    }

    ; Starts an instance of the flow at the given trigger (or the first trigger). Returns the instance ID.
    ; Throws AhfError: bad_payload (no trigger, or a flow without one, invalid policy), busy (policy skip,
    ; or wait, which is not implemented yet).
    StartFlow(rec, triggerId := "") {
        flowId := rec.FlowId
        def := rec.Def
        if (triggerId = "") {
            triggers := def.Triggers()
            if (triggers.Length = 0)
                throw AhfError("flow '" flowId "' has no trigger", ErrCode.BAD_PAYLOAD)
            triggerId := triggers[1]
        } else if (def.ElementKind(triggerId) != "trigger") {
            throw AhfError("'" triggerId "' is not a trigger of flow '" flowId "'", ErrCode.BAD_PAYLOAD)
        }
        try {
            decision := ExecutionPolicy.Decide(Executor._PolicyOf(def), this.IsExecuting(flowId), "parallel")
        } catch as e {
            throw AhfError(e.Message, ErrCode.BAD_PAYLOAD)
        }
        if (decision = "skip")
            throw AhfError("flow '" flowId "' is running and its execution policy is skip", ErrCode.BUSY)
        if (decision = "wait")
            throw AhfError("flow '" flowId "' is running and its execution policy is wait, not supported in WI-10"
                , ErrCode.BUSY)
        if (decision = "stop_and_start")
            this.StopFlow(flowId, "policy stop")

        instId := Ids.Next("inst-")
        inst := Instance(instId, flowId)
        trigger := inst.Start(Ids.Next("thr-"), triggerId)
        if (!IsObject(trigger))
            throw AhfError("instance '" instId "' could not start", ErrCode.INTERNAL)
        run := Executor._NewRun(instId, flowId, inst, def)
        this._runs[instId] := run
        this._owner.Emit("topic:flow:" flowId, "evt.instance.started", Map("flowId", flowId, "instanceId", instId))
        this._owner.EmitFlowState(flowId)
        ; The trigger fires when the engine is asked to start the flow: running, then finished (v1 newInstance).
        this._ElementStarted(run, triggerId)
        this._ElementStopped(run, triggerId, "normal", "")
        this._Advance(run, trigger)
        this._owner.Kick()
        return instId
    }

    ; Stops all instances of the flow (ARCHITECTURE 5.1). Returns the number of instances stopped.
    StopFlow(flowId, reason := "flow.stop") {
        n := 0
        for instId in Executor._Keys(this._runs) {
            run := this._runs.Get(instId, "")
            if (IsObject(run) && run["flowId"] = flowId) {
                this._StopRun(run, reason)
                n += 1
            }
        }
        return n
    }

    StopAll(reason) {
        for instId in Executor._Keys(this._runs) {
            run := this._runs.Get(instId, "")
            if (IsObject(run))
                this._StopRun(run, reason)
        }
    }

    ; Starts every ready thread. Called by Engine on each change and by its safety timer.
    Tick() {
        budget := Executor.TICK_BATCH
        progress := true
        while (progress) {
            progress := false
            for instId in Executor._Keys(this._runs) {
                run := this._runs.Get(instId, "")
                if (!IsObject(run))
                    continue
                for threadId in Executor._Keys(run["inst"].Threads) {
                    thread := run["inst"].Threads.Get(threadId, "")
                    if (!IsObject(thread) || thread.State != "ready")
                        continue
                    ; A worker element waits while the pool is busy; it is dispatched when a worker reports done.
                    if (this._IsWorkerElement(run, thread) && this._owner.workers.Usable()
                        && !this._owner.workers.Free())
                        continue
                    this._Dispatch(run, thread)
                    progress := true
                    budget -= 1
                    if (budget <= 0) {
                        this._owner.Kick()
                        return
                    }
                }
            }
        }
    }

    ; --- execution -----------------------------------------------------------------------------

    _Dispatch(run, thread) {
        thread.Dispatch()
        flowId := run["flowId"]
        elementId := thread.ElementId
        classId := run["flow"].ElementClass(elementId)
        this._ElementStarted(run, elementId)
        ctx := ExecContext(flowId, elementId, run["instanceId"], thread.Id
            , ObjBindMethod(this, "_OnFinish", run["instanceId"], thread.Id)
            , VarStore(run["vars"], VarStore.NewMap()))
        cls := ElementRegistry.Get(classId)
        if (!IsObject(cls)) {
            ctx.Finish("exception", "unknown element class '" classId "'")
            return
        }
        if (cls.Mode = "worker") {
            this._DispatchWorker(run, thread, ctx, cls, classId)
            return
        }
        if (cls.Mode != "inline") {
            ctx.Finish("exception", "element " classId " cannot be an action (mode " cls.Mode ")")
            return
        }
        params := Executor._Params(run["flow"], elementId)
        run["active"][thread.Id] := Map("cls", cls, "ctx", ctx, "params", params)
        ElementRunner.Run(cls, ctx, params, ObjBindMethod(this, "_OnSlow", flowId))
    }

    ; Sends a worker element to the pool. The thread stays running until the worker reports (or the job is
    ; cancelled, see _StopRun). Without a usable worker the run ends with "exception" at once.
    _DispatchWorker(run, thread, ctx, cls, classId) {
        params := Executor._ParamMap(run["flow"], thread.ElementId)
        env := Map("flowId", run["flowId"], "elementId", thread.ElementId, "instanceId", run["instanceId"]
            , "threadId", thread.Id)
        execId := this._owner.workers.Run(classId, params, Executor._CopyMap(run["vars"]), env
            , ObjBindMethod(this, "_OnWorkerDone", ctx))
        if (execId = "") {
            ctx.Finish("exception", "worker not available for " classId)
            return
        }
        run["active"][thread.Id] := Map("cls", cls, "ctx", ctx, "params", Executor._Params(run["flow"], thread.ElementId)
            , "execId", execId)
    }

    ; Called by WorkerBridge when the job ends (bound: ctx first). Exports become thread variables.
    _OnWorkerDone(ctx, result, message, exports) {
        if (!ExecContext.IsResult(result)) {
            message := "worker reported result '" result "'"
            result := "exception"
        }
        for name, value in exports
            ctx.SetVar(name, value)
        ctx.Finish(result, message)
    }

    ; Called by ExecContext.Finish (bound arguments first, then ctx, result, msg).
    _OnFinish(instId, threadId, ctx, result, msg) {
        run := this._runs.Get(instId, "")
        if (!IsObject(run)) {
            Log.Write("f2", "engine", "late finish '" result "' for ended instance " instId, "")
            return
        }
        inst := run["inst"]
        thread := inst.Threads.Get(threadId, "")
        if (!IsObject(thread)) {
            Log.Write("f2", "engine", "late finish '" result "' for removed thread " threadId, run["flowId"])
            return
        }
        if (run["active"].Has(threadId))
            run["active"].Delete(threadId)
        if (thread.Finish(result, msg) = "late") {
            Log.Write("f2", "engine", "late finish '" result "' for thread " threadId, run["flowId"])
            return
        }
        this._ElementStopped(run, thread.ElementId, result, msg)
        this._Advance(run, thread)
        this._owner.Kick()
    }

    ; Moves a finished thread on (Scheduler.Advance) and ends the instance when nothing is left.
    ; Critical: Scheduler.Advance sets a thread "ready" a few lines before it names the next element.
    ; A dispatch tick that interrupts in between (AHK interrupts after 15 ms) would run the thread with
    ; its old element, e.g. a trigger as an action ("cannot be an action"; seen in 2 of about 50 runs
    ; with 200 parallel instances, WI-16).
    _Advance(run, thread) {
        prev := Critical("On")  ; reason: advancing the thread must not be interrupted (see above)
        try {
            outcome := Scheduler.Advance(run["inst"], run["flow"], thread, () => Ids.Next("thr-"))
            if (outcome["unhandled"]) {
                Log.Write("f0", "engine", "unhandled exception in element " thread.ElementId ": " thread.Message
                    , run["flowId"])
            }
            this._CheckEnded(run, outcome["unhandled"] ? "exception" : "finished")
        } finally {
            Critical(prev)
        }
    }

    ; Stops one instance: running elements get Stop and are released at once (the element has no
    ; asynchronous acknowledgement in WI-10, so the 2 s deadline of ARCHITECTURE 5.1 never applies).
    _StopRun(run, reason) {
        inst := run["inst"]
        if (!inst.Stop(reason))
            return
        for threadId in Executor._Keys(inst.Threads) {
            thread := inst.Threads.Get(threadId, "")
            if (!IsObject(thread) || thread.State != "stopping")
                continue
            if (run["active"].Has(threadId)) {
                act := run["active"][threadId]
                run["active"].Delete(threadId)
                if (act.Has("execId"))
                    this._owner.workers.Cancel(act["execId"])
                else
                    ElementRunner.Stop(act["cls"], act["ctx"], act["params"])
            }
            this._ElementStopped(run, thread.ElementId, "stopped", "")
            inst.ReleaseThread(threadId, reason)
        }
        this._CheckEnded(run, reason)
    }

    _CheckEnded(run, reason) {
        if (run["inst"].State = "ended")
            this._EndRun(run, reason)
    }

    _EndRun(run, reason) {
        instId := run["instanceId"]
        if (!this._runs.Has(instId))
            return
        this._runs.Delete(instId)
        this._owner.Emit("topic:flow:" run["flowId"], "evt.instance.ended"
            , Map("flowId", run["flowId"], "instanceId", instId, "reason", reason))
        this._owner.EmitFlowState(run["flowId"])
    }

    ; --- element events ------------------------------------------------------------------------

    _ElementStarted(run, elementId) {
        key := run["flowId"] "/" elementId
        n := this._counts.Get(key, 0) + 1
        this._counts[key] := n
        this._lastRun[key] := FormatTime(A_NowUTC, "yyyy-MM-dd HH:mm:ss")
        this._EmitElement(run["flowId"], elementId, "running", n, "")
    }

    ; result "normal", "yes", "no", "head", "tail", "exception" or "stopped" (stop by the engine).
    _ElementStopped(run, elementId, result, msg) {
        key := run["flowId"] "/" elementId
        n := Max(0, this._counts.Get(key, 0) - 1)
        this._counts[key] := n
        if (n > 0)
            state := "running"
        else
            state := (result = "exception") ? "exception" : "finished"
        this._EmitElement(run["flowId"], elementId, state, n, (result = "exception") ? msg : "")
    }

    _EmitElement(flowId, elementId, state, countRuns, message) {
        key := flowId "/" elementId
        payload := Map("flowId", flowId, "elementId", elementId, "state", state, "countRuns", countRuns
            , "lastRun", this._lastRun.Get(key, ""))
        if (message != "")
            payload["message"] := message
        this._owner.Emit("topic:flow:" flowId, "evt.element.state", payload)
    }

    _OnSlow(flowId, classId, ms) {
        Log.Write("f0", "engine", "element " classId " blocked the engine for " Round(ms) " ms, it must be inline-safe"
            , flowId)
    }

    ; --- helpers -------------------------------------------------------------------------------

    static _NewRun(instId, flowId, inst, def) {
        run := Map("instanceId", instId, "flowId", flowId, "inst", inst, "flow", def
            , "vars", VarStore.NewMap(), "active", Map())
        run["active"].CaseSense := "Off"
        return run
    }

    ; flowSettings.ExecutionPolicy of the flow, "default" when missing (v1 default).
    static _PolicyOf(def) {
        settings := def.Raw.Get("flowSettings", "")
        if (settings is Map)
            return String(settings.Get("ExecutionPolicy", "default"))
        return "default"
    }

    ; The parameters of an element as an object with case-insensitive property names (v1 params
    ; semantics). Objects and null values become "".
    static _Params(def, elementId) {
        p := {}
        for k, v in Executor._ParamMap(def, elementId)
            p.%k% := v
        return p
    }

    ; The same parameters as a Map (sent to workers as JSON). Objects and null values become "".
    static _ParamMap(def, elementId) {
        m := Map()
        el := def.Element(elementId)
        pars := (el is Map) ? el.Get("pars", "") : ""
        if (pars is Map) {
            for k, v in pars {
                if (IsObject(v))
                    v := ""
                m[k] := v
            }
        }
        return m
    }

    ; A copy of a variable Map (imports of a worker are copies, never references).
    static _CopyMap(source) {
        m := Map()
        for k, v in source
            m[k] := v
        return m
    }

    _IsWorkerElement(run, thread) {
        return ElementRegistry.ModeOf(run["flow"].ElementClass(thread.ElementId)) = "worker"
    }

    ; Snapshot of the keys of a Map, so the Map can change while the keys are walked.
    static _Keys(m) {
        keys := []
        for k in m
            keys.Push(k)
        return keys
    }
}
