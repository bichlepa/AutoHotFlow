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
; Policy "wait" (ARCHITECTURE 5.1, E2, M-11): a start while the flow is executing creates the instance in state
; waiting and queues it (FIFO per flow, evt.instance.queued). When no started instance of the flow is left, the next
; waiting one is started. This happens in Tick (_PromoteWaiting), not in the call that ended the previous instance,
; so a long queue of short flows does not nest calls, and Tick's guard keeps it serial. Stop ends waiting and
; running instances; waiting ones first, so a stop never starts an instance on its way.
;
; Revisions (ARCHITECTURE 4.2, E1): a run keeps only the flow ID. Every step reads the newest committed definition
; from owner.flows (DefOf), so an edit takes effect at the next step. A running element keeps the class and the
; parameters it was started with (they are stored in run["active"]). A flow that is gone from the table stops its
; instances at the next step (reason "flow.deleted"); Engine calls FlowDeleted when it removes a flow.
;
; Parameters are passed as they are stored in the flow file (object with case-insensitive properties).
; Expressions are not evaluated in Phase 2 (ARCHITECTURE, WI-10 "Nicht Teil"), so Duration "200" arrives as
; text. Action_Sleep converts it with IsNumber.
class Executor {
    static TICK_BATCH := 1000
    static DIAG_INSTANCES := 100

    __New(owner) {
        this._owner := owner
        this._runs := Map()       ; instanceId -> run (Map, see _NewRun)
        this._counts := Map()     ; "flowId/elementId" -> countRuns (v1 semantics)
        this._lastRun := Map()    ; "flowId/elementId" -> "yyyy-MM-dd HH:mm:ss" of the last start
        this._waiting := Map()    ; flowId -> Array of instance IDs in the order they were queued (policy wait)
        this._waiting.CaseSense := "Off"
        this._wantPromote := Map() ; flowId -> true: an instance ended, a waiting one may start (see Tick)
        this._wantPromote.CaseSense := "Off"
        this._ticking := false    ; a Tick is running (see Tick)
        this._tickAgain := false  ; a Tick was asked for while one was running
        this._counts.CaseSense := "Off"
        this._lastRun.CaseSense := "Off"
    }

    ; True if an instance of the flow is running, stopping or waiting.
    IsExecuting(flowId) {
        for _, run in this._runs {
            if (run["flowId"] = flowId)
                return true
        }
        return false
    }

    ; Instances with their threads for the snapshot (doc/PROTOCOL.md 4.9): ids, states, the element of each thread.
    ; No variables and no parameters. At most DIAG_INSTANCES instances (the rest is only counted by the caller).
    DiagInstances() {
        list := []
        for instId, run in this._runs {
            if (list.Length >= Executor.DIAG_INSTANCES)
                break
            threads := []
            for threadId, thread in run["inst"].Threads
                threads.Push(Map("threadId", threadId, "elementId", thread.ElementId, "state", thread.State
                    , "result", String(thread.Result)))
            list.Push(Map("instanceId", instId, "flowId", run["flowId"], "state", run["inst"].State, "threads", threads))
        }
        return list
    }

    ; True if the instance exists and waits for its turn (policy wait).
    IsWaiting(instId) {
        run := this._runs.Get(instId, "")
        return IsObject(run) && run["inst"].State = "waiting"
    }

    ; Starts an instance of the flow at the given trigger (or the first trigger). Returns the instance ID.
    ; With the policy wait and a running instance the new one is only queued: IsWaiting(id) is true then.
    ; Throws AhfError: bad_payload (no trigger, or a flow without one, invalid policy), busy (policy skip).
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
        if (decision = "stop_and_start")
            this.StopFlow(flowId, "policy stop")

        instId := Ids.Next("inst-")
        inst := Instance(instId, flowId)
        run := Executor._NewRun(instId, flowId, inst, triggerId)
        this._runs[instId] := run
        if (decision = "wait") {
            inst.Wait()
            if (!this._waiting.Has(flowId))
                this._waiting[flowId] := []
            this._waiting[flowId].Push(instId)
            this._owner.Emit("topic:flow:" flowId, "evt.instance.queued"
                , Map("flowId", flowId, "instanceId", instId, "position", this._waiting[flowId].Length))
            return instId
        }
        this._Launch(run, true)
        this._owner.Kick()
        return instId
    }

    ; Starts a new or waiting instance: creates the trigger thread, reports the start and moves the trigger
    ; thread on. The trigger fires when the engine is asked to start the flow: running, then finished (v1
    ; newInstance). A waiting instance reads the newest revision now; if the flow or its trigger is gone by
    ; then, the instance ends without having started. emitState: false when the flow was executing all along.
    _Launch(run, emitState) {
        flowId := run["flowId"]
        instId := run["instanceId"]
        inst := run["inst"]
        triggerId := run["triggerId"]
        def := this._DefOf(run)
        if (!IsObject(def) || def.ElementKind(triggerId) != "trigger") {
            reason := IsObject(def) ? "trigger removed" : "flow.deleted"
            Log.Write("f1", "engine", "instance " instId " not started: " (IsObject(def)
                ? "trigger '" triggerId "' no longer exists" : "flow is not loaded any more"), flowId)
            inst.Stop(reason)
            this._EndRun(run, reason)
            return
        }
        trigger := inst.Start(Ids.Next("thr-"), triggerId)
        if (!IsObject(trigger))
            throw AhfError("instance '" instId "' could not start", ErrCode.INTERNAL)
        this._owner.Emit("topic:flow:" flowId, "evt.instance.started", Map("flowId", flowId, "instanceId", instId))
        if (emitState)
            this._owner.EmitFlowState(flowId)
        this._ElementStarted(run, triggerId)
        this._ElementStopped(run, triggerId, "normal", "")
        this._Advance(run, trigger)
    }

    ; Stops one instance by ID (running or waiting). Returns false if it does not exist.
    StopInstance(instId, reason := "stop") {
        run := this._runs.Get(instId, "")
        if (!IsObject(run))
            return false
        this._StopRun(run, reason)
        return true
    }

    ; Stops all instances of the flow (ARCHITECTURE 5.1). Returns the number of instances stopped.
    ; Waiting instances are stopped first, so no stop starts an instance that was waiting.
    StopFlow(flowId, reason := "flow.stop") {
        n := 0
        for waitingPass in [true, false] {
            for instId in Executor._Keys(this._runs) {
                run := this._runs.Get(instId, "")
                if (IsObject(run) && run["flowId"] = flowId && (run["inst"].State = "waiting") = waitingPass) {
                    this._StopRun(run, reason)
                    n += 1
                }
            }
        }
        return n
    }

    ; The flow is deleted: stops all its instances (ARCHITECTURE 4.2). Returns the number of instances stopped.
    ; A stop does not wait for acknowledgements (see _StopRun), so deleting never has to give up like v1 does.
    FlowDeleted(flowId) {
        return this.StopFlow(flowId, "flow.deleted")
    }

    StopAll(reason) {
        for waitingPass in [true, false] {
            for instId in Executor._Keys(this._runs) {
                run := this._runs.Get(instId, "")
                if (IsObject(run) && (run["inst"].State = "waiting") = waitingPass)
                    this._StopRun(run, reason)
            }
        }
    }

    ; Starts every ready thread. Called by Engine on each change and by its safety timer.
    ;
    ; Not re-entrant: AHK interrupts a timer thread that runs longer than ~15 ms for another one (the kick
    ; timer and the safety timer both call Tick, and an element may call it through Kick). Two ticks that
    ; overlap could both see the same thread as ready and start its element twice. A Tick that is asked for
    ; while one runs only leaves a note; the running one loops once more (like PipeConnection.Pump).
    Tick() {
        prev := Critical("On")  ; reason: testing and setting the flag is one step
        if (this._ticking) {
            this._tickAgain := true
            Critical(prev)
            return
        }
        this._ticking := true
        Critical(prev)
        try {
            loop {
                this._TickOnce()
                prev := Critical("On")  ; reason: leaving and the note of a later Tick must not cross
                if (!this._tickAgain) {
                    this._ticking := false
                    Critical(prev)
                    break
                }
                this._tickAgain := false
                Critical(prev)
            }
        } catch as e {
            prev := Critical("On")  ; reason: the flag must be released even when a tick fails
            this._ticking := false
            this._tickAgain := false
            Critical(prev)
            throw e
        }
    }

    _TickOnce() {
        budget := Executor.TICK_BATCH
        progress := true
        waiting := 0
        while (progress) {
            progress := false
            waiting := 0
            for flowId in Executor._Keys(this._wantPromote) {
                this._wantPromote.Delete(flowId)
                if (this._PromoteWaiting(flowId)) {
                    progress := true
                    budget -= 1
                }
            }
            for instId in Executor._Keys(this._runs) {
                run := this._runs.Get(instId, "")
                if (!IsObject(run))
                    continue
                def := this._DefOf(run)
                if (!IsObject(def)) {
                    this._StopRun(run, "flow.deleted")
                    continue
                }
                for threadId in Executor._Keys(run["inst"].Threads) {
                    thread := run["inst"].Threads.Get(threadId, "")
                    if (!IsObject(thread) || thread.State != "ready")
                        continue
                    ; The definition may have been replaced by a step run from inside this loop.
                    def := this._DefOf(run)
                    if (!IsObject(def))
                        break
                    ; A worker element waits while the pool is busy; it is dispatched when a worker reports done.
                    if (Executor._IsWorkerElement(def, thread) && this._owner.workers.Usable()
                        && !this._owner.workers.Free()) {
                        waiting += 1
                        continue
                    }
                    this._Dispatch(run, thread, def)
                    progress := true
                    budget -= 1
                    if (budget <= 0) {
                        this._owner.Kick()
                        return
                    }
                }
            }
        }
        ; Threads that wait for a worker: the pool grows to meet the demand (WI-27, ARCHITECTURE 6.4).
        if (waiting > 0)
            this._owner.workers.Want(waiting)
    }

    ; --- execution -----------------------------------------------------------------------------

    ; def is the newest revision, read by the caller for this step. Class and parameters are taken from it now.
    _Dispatch(run, thread, def) {
        ; The thread must be ready. If another tick started it in between, this one must not start it again.
        if (!thread.Dispatch())
            return
        flowId := run["flowId"]
        elementId := thread.ElementId
        classId := def.ElementClass(elementId)
        this._ElementStarted(run, elementId)
        ctx := ExecContext(flowId, elementId, run["instanceId"], thread.Id
            , ObjBindMethod(this, "_OnFinish", run["instanceId"], thread.Id)
            , VarStore(run["vars"], VarStore.NewMap()))
        if (!def.HasElement(elementId)) {
            ; The element was deleted while the thread waited (ARCHITECTURE 4.2, M-17).
            Log.Write("f1", "engine", "element '" elementId "' was removed before it could start", flowId)
            ctx.Finish("exception", "element was removed")
            return
        }
        cls := ElementRegistry.Get(classId)
        if (!IsObject(cls)) {
            ctx.Finish("exception", "unknown element class '" classId "'")
            return
        }
        if (cls.Mode = "worker") {
            this._DispatchWorker(run, thread, ctx, cls, classId, def)
            return
        }
        if (cls.Mode != "inline") {
            ctx.Finish("exception", "element " classId " cannot be an action (mode " cls.Mode ")")
            return
        }
        params := Executor._Params(def, elementId)
        run["active"][thread.Id] := Map("cls", cls, "ctx", ctx, "params", params)
        ElementRunner.Run(cls, ctx, params, ObjBindMethod(this, "_OnSlow", flowId))
    }

    ; Sends a worker element to the pool. The thread stays running until the worker reports (or the job is
    ; cancelled, see _StopRun). Without a usable worker the run ends with "exception" at once.
    _DispatchWorker(run, thread, ctx, cls, classId, def) {
        params := Executor._ParamMap(def, thread.ElementId)
        env := Map("flowId", run["flowId"], "elementId", thread.ElementId, "instanceId", run["instanceId"]
            , "threadId", thread.Id)
        act := Map("cls", cls, "ctx", ctx, "params", Executor._Params(def, thread.ElementId))
        ; Workers.Run may end the job before it returns (send error). The entry is made first so that the end
        ; (_OnFinish) removes it, and the execId is added only if the job is still open. Without Critical a
        ; stop between Run and the assignment would find an entry without execId and could not cancel the job.
        prev := Critical("On")  ; reason: register, start and note the execId as one step (see above)
        try {
            run["active"][thread.Id] := act
            execId := this._owner.workers.Run(classId, params, Executor._CopyMap(run["vars"]), env
                , ObjBindMethod(this, "_OnWorkerDone", ctx), cls.JobTimeoutMs)
            current := run["active"].Get(thread.Id, "")
            if (execId = "") {
                run["active"].Delete(thread.Id)
            } else if (IsObject(current) && ObjPtr(current) = ObjPtr(act)) {
                act["execId"] := execId
            }
        } finally {
            Critical(prev)
        }
        if (execId = "")
            ctx.Finish("exception", "worker not available for " classId)
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
        def := this._DefOf(run)
        if (!IsObject(def)) {
            this._StopRun(run, "flow.deleted")
            return
        }
        prev := Critical("On")  ; reason: advancing the thread must not be interrupted (see above)
        try {
            outcome := Scheduler.Advance(run["inst"], def, thread, () => Ids.Next("thr-"))
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

    ; Starts the first waiting instance of the flow if no started instance is left. Returns true if it did.
    _PromoteWaiting(flowId) {
        queue := this._waiting.Get(flowId, "")
        if (!IsObject(queue) || queue.Length = 0)
            return false
        for _, run in this._runs {
            if (run["flowId"] = flowId && run["inst"].State != "waiting")
                return false
        }
        instId := queue.RemoveAt(1)
        run := this._runs.Get(instId, "")
        if (!IsObject(run))
            return true
        this._Launch(run, false)
        return true
    }

    ; Removes an instance that ended (or was stopped while waiting) from the queue of its flow.
    _Unqueue(flowId, instId) {
        queue := this._waiting.Get(flowId, "")
        if (!IsObject(queue))
            return
        for i, id in queue {
            if (id = instId) {
                queue.RemoveAt(i)
                break
            }
        }
        if (queue.Length = 0)
            this._waiting.Delete(flowId)
    }

    _CheckEnded(run, reason) {
        if (run["inst"].State = "ended")
            this._EndRun(run, reason)
    }

    _EndRun(run, reason) {
        instId := run["instanceId"]
        prev := Critical("On")  ; reason: ending is reported once, however often it is asked for
        try {
            if (!this._runs.Has(instId))
                return
            this._runs.Delete(instId)
            this._Unqueue(run["flowId"], instId)
            this._wantPromote[run["flowId"]] := true
        } finally {
            Critical(prev)
        }
        this._owner.Emit("topic:flow:" run["flowId"], "evt.instance.ended"
            , Map("flowId", run["flowId"], "instanceId", instId, "reason", reason))
        this._owner.EmitFlowState(run["flowId"])
        this._owner.Kick()
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

    static _NewRun(instId, flowId, inst, triggerId) {
        run := Map("instanceId", instId, "flowId", flowId, "inst", inst, "triggerId", triggerId
            , "vars", VarStore.NewMap(), "active", Map())
        run["active"].CaseSense := "Off"
        return run
    }

    ; The newest committed definition of the run's flow, or "" if the flow is not loaded any more.
    _DefOf(run) {
        rec := this._owner.flows.Get(run["flowId"])
        return IsObject(rec) ? rec.Def : ""
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

    static _IsWorkerElement(def, thread) {
        return ElementRegistry.ModeOf(def.ElementClass(thread.ElementId)) = "worker"
    }

    ; Snapshot of the keys of a Map, so the Map can change while the keys are walked.
    static _Keys(m) {
        keys := []
        for k in m
            keys.Push(k)
        return keys
    }
}
