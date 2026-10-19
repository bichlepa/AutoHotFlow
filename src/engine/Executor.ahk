#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Ids.ahk
#Include ..\core\Log.ahk
#Include ..\elements\base\ElementRegistry.ahk
#Include ..\elements\base\ElementRunner.ahk
#Include ..\elements\base\ExecContext.ahk
#Include ..\elements\base\ParamEvaluator.ahk
#Include core\ExecutionPolicy.ahk
#Include core\FlowDefinition.ahk
#Include core\RunawayGuard.ahk
#Include core\Instance.ahk
#Include core\Scheduler.ahk
#Include core\ThreadState.ahk
#Include WorkerBridge.ahk
#Include vars\BuiltInVars.ahk
#Include vars\VarAccess.ahk
#Include vars\VarNames.ahk

; Runs the instances of the engine (WI-0010, ARCHITECTURE 2.3, 5.1, 5.2, 6.2). Runs the state machines of
; engine/core and calls the elements through ElementRunner. Knows nothing about IPC: it reports through
; owner.Emit, owner.EmitFlowState and owner.Kick (implemented by Engine).
;
; Dispatching is event driven: a state change calls owner.Kick (a timer runs Tick once). Tick starts every
; ready thread. A run of Tick is limited to TICK_BATCH dispatches, then it schedules itself again, so a flow
; of synchronous elements cannot keep the message loop busy.
;
; Modes (ELEMENT-API-V2 section 2): inline runs here. worker goes to the pool (WorkerBridge, WI-0011): the thread
; waits in state ready while every worker is busy, and ends with "exception" ("worker not available") when no
; worker is usable at all. trigger cannot be an action.
;
; Policy "wait" (ARCHITECTURE 5.1, E0002, M-0011): a start while the flow is executing creates the instance in state
; waiting and queues it (FIFO per flow, evt.instance.queued). When no started instance of the flow is left, the next
; waiting one is started. This happens in Tick (_PromoteWaiting), not in the call that ended the previous instance,
; so a long queue of short flows does not nest calls, and Tick's guard keeps it serial. Stop ends waiting and
; running instances; waiting ones first, so a stop never starts an instance on its way.
;
; Revisions (ARCHITECTURE 4.2, E0001): a run keeps only the flow ID. Every step reads the newest committed definition
; from owner.flows (DefOf), so an edit takes effect at the next step. A running element keeps the class and the
; parameters it was started with (they are stored in run["active"]). A flow that is gone from the table stops its
; instances at the next step (reason "flow.deleted"); Engine calls FlowDeleted when it removes a flow.
;
; Variables (WI-0040, doc/EXPRESSION-LANGUAGE.md section 18): every element run gets a VarAccess, its view on the loop
; and thread variables of its thread (ThreadState), the instance variables (Instance), the static variables of the flow
; and the global variables (owner.vars, EngineVars). A worker element reaches the same view through the variable
; requests (VarRequests, WI-0050): the job keeps the context of the element; the job carries no copies (M-0045).
; ContextOf makes such a view for a client that names an instance (and a thread).
;
; Parameters are passed as they are stored in the flow file (object with case-insensitive properties). An inline
; element evaluates them when it calls ctx.EvalParams (WI-0042, as v1 x_AutoEvaluateParameters); for a worker element
; the engine evaluates all of them before the job is sent (E0026, _DispatchWorker), because the worker has no access to
; the variables.
;
; Calls (WI-0055, ARCHITECTURE 4.4): CallFlow starts an instance for a caller, with initial instance variables and a
; chosen trigger, and, if the caller waits, notes the call. When the called instance ends, its outcome (a Map: result,
; reason, message and, if asked for, a copy of its instance variables) goes to the caller's function, in the next Tick
; (_notes), never from inside the step that ended the instance; so no element code runs nested in another instance's
; step, and nothing in the engine waits. A call is cancelled with CancelCall (the context does it when the waiting
; element is stopped); the called instance then runs on. A waiting call that could never end (the called flow has the
; policy wait and one of its instances waits for the caller) is refused, and so is a chain of waiting calls deeper than
; MAX_CALL_DEPTH.
; Runaway guard (WI-0066, REQ-EXE-170, RunawayGuard): every element start is counted here (_ElementStarted, the one counting
; point; the start of a trigger of a new instance passes it too). A flow over its executions per minute is stopped at the
; next dispatch, its triggers are disabled by the engine (LimitReached). A start over the limit of waiting or running
; instances is refused in _Start with the error code limit; a refusal is logged at most every 10 s per flow.
class Executor {
    static TICK_BATCH := 1000
    static DIAG_INSTANCES := 100
    ; Waiting calls in a row (a flow that calls itself and waits, for example): deeper ones are refused. The calls do not
    ; nest on the AutoHotkey stack (see the header), so the limit only bounds the instances that wait for each other.
    static MAX_CALL_DEPTH := 100

    __New(owner) {
        this._owner := owner
        this._runs := Map()       ; instanceId -> run (Map, see _NewRun)
        this._elems := Map()      ; flowId -> Map elementId -> element record (_Elem): state, countRuns (v1), warnings (WI-0086)
        this._elems.CaseSense := "Off"
        this._dirty := []         ; element records with a warning count that was not sent yet (_Mark, WI-0086)
        this._flushScheduled := false  ; the flush timer of _Mark is set
        this._flushFn := ObjBindMethod(this, "_FlushTimer")
        this._guard := RunawayGuard()  ; the runaway limits: counts of element executions per flow (WI-0066)
        this._overLimit := Map()  ; flowId -> limit exceeded, the flow is stopped at the next dispatch (WI-0066)
        this._waiting := Map()    ; flowId -> Array of instance IDs in the order they were queued (policy wait)
        this._waiting.CaseSense := "Off"
        this._wantPromote := Map() ; flowId -> true: an instance ended, a waiting one may start (see Tick)
        this._wantPromote.CaseSense := "Off"
        this._ticking := false    ; a Tick is running (see Tick)
        this._tickAgain := false  ; a Tick was asked for while one was running
        this._notes := []         ; [call, outcome] of called instances that ended, delivered by Tick (CallFlow)
    }

    ; True if an instance of the flow is running, stopping or waiting.
    IsExecuting(flowId) {
        for _, runRec in this._runs {
            if (runRec["flowId"] = flowId)
                return true
        }
        return false
    }

    ; The number of instances of the flow that run or stop (not the waiting ones): the count of the snapshot and of
    ; evt.flow.state (PROTOCOL 4.2, E0079).
    RunningCount(flowId) => this._CountRunning(flowId)

    ; Instances with their threads for the snapshot (doc/PROTOCOL.md 4.9): ids, states, the element of each thread.
    ; No variables and no parameters. At most DIAG_INSTANCES instances (the rest is only counted by the caller).
    DiagInstances() {
        list := []
        for instId, runRec in this._runs {
            if (list.Length >= Executor.DIAG_INSTANCES)
                break
            threads := []
            for threadId, thr in runRec["inst"].Threads
                threads.Push(Map("threadId", threadId, "elementId", thr.ElementId, "state", thr.State
                    , "result", String(thr.Result)))
            list.Push(Map("instanceId", instId, "flowId", runRec["flowId"], "state", runRec["inst"].State, "threads", threads))
        }
        return list
    }

    ; True if the instance exists and waits for its turn (policy wait).
    IsWaiting(instId) {
        runRec := this._runs.Get(instId, "")
        return IsObject(runRec) && runRec["inst"].State = "waiting"
    }

    ; Starts an instance of the flow at the given trigger (or the first trigger). Returns the instance ID.
    ; With the policy wait and a running instance the new one is only queued: IsWaiting(id) is true then.
    ; Throws AhfError: bad_payload (no trigger, or a flow without one, invalid policy), busy (policy skip).
    ; fired: the event of an armed trigger (WI-0062): Map params (the evaluated parameters of the arming) and data (a Map
    ; of the event, or ""). Without it the parameters are evaluated now (TriggerArms.StartInfo).
    StartFlow(rec, triggerId := "", fired := "") => this._Start(rec, triggerId, "", "", 0, fired)

    ; Starts an instance of a flow for a caller (WI-0055, ELEMENT-API-V2 section 3, ARCHITECTURE 4.4): the engine
    ; function behind Action_Execute_Flow, meant to serve a flow called as a function too (REQ-SCR-040). opts (a Map, all
    ; keys optional):
    ;   vars       Map name -> value: instance variables of the new instance, set before its trigger fires (a copy)
    ;   onEnd      onEnd(outcome): the caller waits; called once, in a later Tick, when the instance has ended
    ;   withVars   true: the outcome holds a copy of the instance variables of the instance at its end
    ;   caller     the instance ID of the caller (with callerThread, its thread): needed for a waiting call (depth,
    ;              deadlock, and no wait is noted when the caller is gone by the time the instance starts)
    ; outcome: Map instanceId, flowId, reason (of evt.instance.ended), result ("normal": the instance finished without an
    ; unhandled exception; "exception": at least one thread ended with an exception that had no connection, message is
    ; the first one; "stopped": the instance was stopped, reason says why), message, vars (a Map, or "").
    ; Returns Map instanceId, waiting (1: queued by the policy wait), call (the handle for CancelCall, "" without onEnd).
    ; Throws AhfError: not_found (flow not loaded), bad_payload (no such trigger), busy (policy skip and the flow runs),
    ; denied (the wait could never end, or the chain of waiting calls is too deep).
    CallFlow(flowId, triggerId := "", opts := "") {
        if (!(opts is Map))
            opts := Map()
        rec := this._owner.flows.Get(flowId)
        if (!IsObject(rec))
            throw AhfError("flow '" flowId "' is not loaded", ErrCode.NOT_FOUND)
        call := ""
        depth := 0
        onEnd := opts.Get("onEnd", "")
        if (IsObject(onEnd)) {
            callerId := String(opts.Get("caller", ""))
            callerRun := this._runs.Get(callerId, "")
            depth := (IsObject(callerRun) ? callerRun["depth"] : 0) + 1
            if (depth > Executor.MAX_CALL_DEPTH)
                throw AhfError("flow '" rec.FlowId "' was not started: " Executor.MAX_CALL_DEPTH
                    . " calls that wait for each other are the limit", ErrCode.DENIED)
            call := Map("onEnd", onEnd, "withVars", opts.Get("withVars", false) ? 1 : 0, "caller", callerId
                , "callerThread", String(opts.Get("callerThread", "")), "instanceId", "", "cancelled", 0)
        }
        instId := this._Start(rec, triggerId, call, opts.Get("vars", ""), depth, "")
        return Map("instanceId", instId, "waiting", this.IsWaiting(instId) ? 1 : 0, "call", call)
    }

    ; Cancels a waiting call (the handle of CallFlow): its function is not called, the called instance runs on. Called
    ; when the waiting element is stopped (ExecContext.CancelTimers). Safe to call twice and after the end.
    CancelCall(call) {
        if (!(call is Map) || call["cancelled"])
            return
        call["cancelled"] := 1
        call["onEnd"] := ""          ; the function holds the context of the caller: release it
        callerRun := this._runs.Get(call["caller"], "")
        if (IsObject(callerRun) && callerRun["callees"].Has(call["instanceId"]))
            callerRun["callees"].Delete(call["instanceId"])
    }

    ; True if the flow is loaded.
    FlowExists(flowId) => this._owner.flows.Has(flowId)

    ; True if the element is a trigger of the newest revision of the flow.
    HasTrigger(flowId, triggerId) {
        rec := this._owner.flows.Get(flowId)
        return IsObject(rec) && triggerId != "" && rec.Def.ElementKind(triggerId) = "trigger"
    }

    ; The default manual trigger of the flow (FlowDefinition.DefaultManualTrigger), "" if none or the flow is not loaded.
    DefaultTriggerOf(flowId) {
        rec := this._owner.flows.Get(flowId)
        return IsObject(rec) ? rec.Def.DefaultManualTrigger() : ""
    }

    ; True if the trigger may be started by an element (v1 x_isTriggerEnabled): its target state is enabled (E0056,
    ; WI-0060, REQ-EXE-070). Whether it is armed is WI-0062; a trigger of a disabled flow is not enabled unless it is
    ; independent and switched on (the flow itself does not count).
    IsTriggerEnabled(flowId, triggerId) {
        rec := this._owner.flows.Get(flowId)
        return IsObject(rec) && rec.TriggerEnabled(triggerId) && this.HasTrigger(flowId, triggerId)
    }

    ; The triggers of a scope of a flow and how many of them are enabled (WI-0065, ctx.CountTriggers): Map("total", n,
    ; "enabled", m). The scopes are those of FlowRecord.TriggersOf. Throws AhfError if the flow is not loaded.
    CountTriggers(flowId, scope) {
        rec := this._LoadedFlow(flowId)
        ids := rec.TriggersOf(scope)
        enabled := 0
        for triggerId in ids {
            if (rec.TriggerEnabled(triggerId))
                enabled += 1
        }
        return Map("total", ids.Length, "enabled", enabled)
    }

    ; Switches the triggers of a scope of a flow, or the one trigger triggerId (scope "one"), as cmd.flow.enable/disable and
    ; cmd.trigger.enable/disable do (WI-0065, E0056, E0063): the engine arms, announces and saves them. Returns the number
    ; of triggers of the scope. Throws AhfError if the flow is not loaded, its state is not known, or triggerId is no
    ; trigger of the flow (ctx.SetTriggers and ctx.SetTriggerEnabled turn it into ElementError).
    SetTriggers(flowId, scope, enabled, triggerId := "") {
        return this._owner.SwitchFromElement(String(flowId), String(scope), enabled ? true : false, String(triggerId))
    }

    _LoadedFlow(flowId) {
        rec := this._owner.flows.Get(flowId)
        if (!IsObject(rec))
            throw AhfError("flow '" flowId "' is not loaded", ErrCode.NOT_FOUND)
        return rec
    }

    ; StartFlow and CallFlow. call: the Map of a waiting call or "". vars: initial instance variables or "". depth: the
    ; number of waiting calls that lead to this instance (0 for a start that nobody waits for).
    _Start(rec, triggerId, call, vars, depth, fired) {
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
            decision := ExecutionPolicy.Decide(Executor._PolicyOf(def), this.IsExecuting(flowId)
                , this._owner.settings.Value("executionPolicy"))
        } catch as e {
            throw AhfError(e.Message, ErrCode.BAD_PAYLOAD)
        }
        if (decision = "skip")
            throw AhfError("flow '" flowId "' is running and its execution policy is skip", ErrCode.BUSY)
        if (decision = "wait" && IsObject(call) && this._WaitsFor(flowId, call["caller"]))
            throw AhfError("flow '" flowId "' was not started: its execution policy is wait and one of its instances "
                . "waits for the calling element, so the call would never end", ErrCode.DENIED)
        this._CheckStartLimits(flowId, def, decision)
        if (decision = "stop_and_start")
            this.StopFlow(flowId, "policy stop")

        instId := Ids.Next("inst-")
        inst := Instance(instId, flowId)
        runRec := Executor._NewRun(instId, flowId, inst, triggerId)
        runRec["depth"] := depth
        ; The parameters of the trigger for TriggerVariables (WI-0062, M-0069): kept with the run, so a waiting instance
        ; has them as well. Evaluated now for a start that no event caused; "" when they cannot be evaluated.
        runRec["trigger"] := IsObject(fired) ? fired : this._owner.arms.StartInfo(rec, triggerId)
        if (vars is Map)
            Executor._SetInstanceVars(inst, vars, flowId)
        this._runs[instId] := runRec
        if (IsObject(call))
            this._NoteCall(runRec, call)
        if (decision = "wait") {
            inst.Wait()
            if (!this._waiting.Has(flowId))
                this._waiting[flowId] := []
            this._waiting[flowId].Push(instId)
            this._owner.Emit("topic:flow:" flowId, "evt.instance.queued"
                , Map("flowId", flowId, "instanceId", instId, "position", this._waiting[flowId].Length))
            return instId
        }
        this._Launch(runRec)
        this._owner.Kick()
        return instId
    }

    ; The limits of waiting and running instances (WI-0066, REQ-EXE-170): a start over the limit is refused like skip, with
    ; ErrCode.LIMIT. A start that waits counts the queue; a start that runs now counts the running instances. A stop_and_start
    ; stops the running ones first, so it is not checked.
    _CheckStartLimits(flowId, def, decision) {
        if (decision = "wait") {
            cap := RunawayGuard.LimitOf(def, "maxWaitingInstances", this._owner.settings.Value("maxWaitingInstances"))
            queued := this._waiting.Has(flowId) ? this._waiting[flowId].Length : 0
            if (cap > 0 && queued >= cap)
                this._RefuseStart(flowId, "waiting", "maxWaitingInstances", cap)
        } else if (decision = "start") {
            cap := RunawayGuard.LimitOf(def, "maxParallelInstances", this._owner.settings.Value("maxParallelInstances"))
            if (cap > 0 && this._CountRunning(flowId) >= cap)
                this._RefuseStart(flowId, "running", "maxParallelInstances", cap)
        }
    }

    ; Throws the refusal (ErrCode.LIMIT). The log line is written at most once per 10 s and flow (RunawayGuard.Refused), so a
    ; trigger that fires fast does not flood the log; the trigger callers do not log the refusal again (_OnTriggerFired).
    _RefuseStart(flowId, what, key, cap) {
        limitText := "the limit of " cap " " what " instances (flowSettings." key ") is reached"
        line := this._guard.Refused(flowId, limitText)
        if (line != "")
            Log.Write("f1", "engine", line, flowId)
        throw AhfError("flow '" flowId "' was not started: " limitText, ErrCode.LIMIT)
    }

    ; The instances of the flow that run or stop (not the waiting ones).
    _CountRunning(flowId) {
        n := 0
        for _, runRec in this._runs {
            if (runRec["flowId"] = flowId && runRec["inst"].State != "waiting")
                n += 1
        }
        return n
    }

    ; Counts one element execution against the runaway limit of its flow (WI-0066). Over the limit, the flow is marked; it is
    ; stopped at the next dispatch (_EnforceLimits), so the element that crossed the limit does not start more work.
    _CountExecution(run) {
        flowId := run["flowId"]
        def := this._DefOf(run)
        if (!IsObject(def))
            return
        limit := RunawayGuard.LimitOf(def, "maxExecutionsPerMinute", this._owner.settings.Value("maxExecutionsPerMinute"))
        if (limit = 0)
            return
        if (this._guard.Count(flowId) > limit && !this._overLimit.Has(flowId))
            this._overLimit[flowId] := limit
    }

    ; Stops the flows that exceeded their limit (WI-0066): all their instances end with reason limit, then the engine disables
    ; their triggers and reports evt.flow.limit (LimitReached). Called by Tick before and after each dispatch.
    _EnforceLimits() {
        if (this._overLimit.Count = 0)
            return
        for flowId in Executor._Keys(this._overLimit) {
            limit := this._overLimit.Get(flowId, 0)
            this._overLimit.Delete(flowId)
            this.StopFlow(flowId, "limit")
            this._owner.LimitReached(flowId, "executionsPerMinute", limit)
        }
    }

    ; Starts a new or waiting instance: creates the trigger thread, reports the start and moves the trigger
    ; thread on. The trigger fires when the engine is asked to start the flow: running, then finished (v1
    ; newInstance). A waiting instance reads the newest revision now; if the flow or its trigger is gone by
    ; then, the instance ends without having started. Every start sends evt.flow.state: it carries the count of running
    ; instances (E0079), which changes with every start, also with a promoted waiting instance.
    _Launch(run) {
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
        ; Thread variables about the trigger event (v1 newInstance, Instances and Threads.ahk:91). Set before the
        ; trigger thread moves on, so every branch has them.
        trigger.Vars["A_TriggerTime"] := A_Now
        trigger.Vars["A_TriggerID"] := triggerId
        this._SetTriggerVars(run, def, trigger)
        this._owner.Emit("topic:flow:" flowId, "evt.instance.started", Map("flowId", flowId, "instanceId", instId))
        this._owner.EmitFlowState(flowId)
        this._ElementStarted(run, triggerId)
        this._ElementStopped(run, triggerId, "normal", "")
        this._Advance(run, trigger)
    }

    ; The thread variables that the trigger class sets for its event (TriggerVariables(params, data), ELEMENT-API-V2 section
    ; 2, WI-0062). Pure function of the class, called in the engine: an error is logged and the instance starts without them.
    _SetTriggerVars(run, def, trigger) {
        fire := run["trigger"]
        if (!(fire is Map) || !IsObject(fire.Get("params", "")))
            return
        triggerId := run["triggerId"]
        cls := ElementRegistry.Get(Executor._QidOf(def, triggerId))
        if (!IsObject(cls) || !cls.HasMethod("TriggerVariables"))
            return
        try {
            vars := cls.TriggerVariables(fire["params"], fire.Get("data", ""))
            if (vars is Map) {
                for name, value in vars
                    trigger.Vars[name] := value
            }
        } catch as e {
            Log.Write("f0", "engine", "trigger '" triggerId "' could not set its variables, the instance starts without "
                . "them: " Executor.ErrorText(e), run["flowId"])
        }
    }

    ; Stops one instance by ID (running or waiting). Returns false if it does not exist.
    StopInstance(instId, reason := "stop") {
        runRec := this._runs.Get(instId, "")
        if (!IsObject(runRec))
            return false
        this._StopRun(runRec, reason)
        return true
    }

    ; The element IDs of a flow that have a class (v1 x_getAllElementIDsOfClass, WI-0052): the newest committed revision.
    ; className is "<class>" (package Default) or "<package>.<class>". Empty Array if the flow is not loaded.
    ElementIdsOfClass(flowId, className) {
        rec := this._owner.flows.Get(flowId)
        return IsObject(rec) ? rec.Def.ElementIdsOfClass(className) : []
    }

    ; The stored parameters of an element of a flow (v1 x_getElementPars, WI-0052), see FlowDefinition.ElementPars. ""
    ; if the flow or the element does not exist.
    ElementParams(flowId, elementId) {
        rec := this._owner.flows.Get(flowId)
        return IsObject(rec) ? rec.Def.ElementPars(elementId) : ""
    }

    ; Stops all instances of the flow (ARCHITECTURE 5.1). Returns the number of instances stopped.
    ; Waiting instances are stopped first, so no stop starts an instance that was waiting.
    StopFlow(flowId, reason := "flow.stop") {
        n := 0
        for waitingPass in [true, false] {
            for instId in Executor._Keys(this._runs) {
                runRec := this._runs.Get(instId, "")
                if (IsObject(runRec) && runRec["flowId"] = flowId && (runRec["inst"].State = "waiting") = waitingPass) {
                    this._StopRun(runRec, reason)
                    n += 1
                }
            }
        }
        return n
    }

    ; The flow is deleted: stops all its instances (ARCHITECTURE 4.2). Returns the number of instances stopped.
    ; A stop does not wait for acknowledgements (see _StopRun), so deleting never has to give up like v1 does.
    FlowDeleted(flowId) {
        this._guard.Forget(flowId)
        if (this._overLimit.Has(flowId))
            this._overLimit.Delete(flowId)
        return this.StopFlow(flowId, "flow.deleted")
    }

    StopAll(reason) {
        for waitingPass in [true, false] {
            for instId in Executor._Keys(this._runs) {
                runRec := this._runs.Get(instId, "")
                if (IsObject(runRec) && (runRec["inst"].State = "waiting") = waitingPass)
                    this._StopRun(runRec, reason)
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
        waitCount := 0
        this._EnforceLimits()
        while (progress) {
            progress := false
            waitCount := 0
            ; The ends of called instances go to their callers first (CallFlow): a caller that finishes now may let its
            ; own instance end and a waiting one move up below.
            while (this._notes.Length) {
                this._Deliver(this._notes.RemoveAt(1))
                progress := true
                budget -= 1
            }
            for flowId in Executor._Keys(this._wantPromote) {
                this._wantPromote.Delete(flowId)
                if (this._PromoteWaiting(flowId)) {
                    progress := true
                    budget -= 1
                }
            }
            for instId in Executor._Keys(this._runs) {
                runRec := this._runs.Get(instId, "")
                if (!IsObject(runRec))
                    continue
                def := this._DefOf(runRec)
                if (!IsObject(def)) {
                    this._StopRun(runRec, "flow.deleted")
                    continue
                }
                for threadId in Executor._Keys(runRec["inst"].Threads) {
                    thr := runRec["inst"].Threads.Get(threadId, "")
                    if (!IsObject(thr) || thr.State != "ready")
                        continue
                    ; The definition may have been replaced by a step run from inside this loop.
                    def := this._DefOf(runRec)
                    if (!IsObject(def))
                        break
                    ; A worker element waits while the pool is busy; it is dispatched when a worker reports done.
                    if (Executor._IsWorkerElement(def, thr) && this._owner.workers.Usable()
                        && !this._owner.workers.Free()) {
                        waitCount += 1
                        continue
                    }
                    this._Dispatch(runRec, thr, def)
                    this._EnforceLimits()
                    progress := true
                    budget -= 1
                    if (budget <= 0) {
                        this._owner.Kick()
                        return
                    }
                }
            }
        }
        ; Threads that wait for a worker: the pool grows to meet the demand (WI-0027, ARCHITECTURE 6.4).
        if (waitCount > 0)
            this._owner.workers.Want(waitCount)
    }

    ; --- execution -----------------------------------------------------------------------------

    ; def is the newest revision, read by the caller for this step. Class and parameters are taken from it now.
    _Dispatch(run, thread, def) {
        ; The thread must be ready. If another tick started it in between, this one must not start it again.
        if (!thread.Dispatch())
            return
        flowId := run["flowId"]
        elementId := thread.ElementId
        classId := Executor._QidOf(def, elementId)    ; the qualified ID "<package>.<class>" (E0045)
        this._ElementStarted(run, elementId, thread.ConnectionId)
        ctx := ExecContext(flowId, elementId, run["instanceId"], thread.Id
            , ObjBindMethod(this, "_OnFinish", run["instanceId"], thread.Id)
            , this._VarAccess(run, thread, def, elementId))
        ctx.entryPoint := thread.EntryPoint      ; "head" or "tail" for a loop (v1 x_getEntryPoint)
        ctx.onWarn := ObjBindMethod(this, "_Warned", flowId, elementId)   ; the warnings of its evaluations (WI-0086)
        ctx.host := this                         ; the flow functions of the context: element lookup, stop (WI-0052)
        if (!def.HasElement(elementId)) {
            ; The element was deleted while the thread waited (ARCHITECTURE 4.2, M-0017).
            Log.Write("f1", "engine", "element '" elementId "' was removed before it could start", flowId)
            ctx.Finish("exception", "element was removed")
            return
        }
        cls := ElementRegistry.Get(classId)
        if (!IsObject(cls)) {
            ; not ported yet, or of a package that is not installed (WI-0047): the flow keeps the element as it is
            ctx.Finish("exception", ElementRegistry.MissingText(classId))
            return
        }
        classId := ElementRegistry.IdOf(cls)    ; the spelling of the class, for the worker job and the log
        ctx.cls := cls                         ; Parameters() of the class for ctx.EvalParams (WI-0042)
        ctx.strictTypes := def.StrictTypes      ; the type mode of the flow (E0034)
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
        ; E0026: the engine evaluates every parameter now, with its variables and the mode of the flow; the worker has no
        ; access to them. An assignment in a parameter has run before the job leaves, so the element sees its result.
        try {
            evaluated := Executor._EvalForWorker(cls, ctx, Executor._Params(def, thread.ElementId))
        } catch as e {
            ; Parameters() of the class or the evaluation failed (element code never takes the engine down)
            ctx.Finish("exception", "parameters of " classId " could not be evaluated: " e.Message)
            return
        }
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
            ; No copies of the variables (M-0045, WI-0050): the element asks the engine with the variable requests, which
            ; find this context (ctx) through the job.
            execId := this._owner.workers.Run(classId, params, Map(), env
                , ObjBindMethod(this, "_OnWorkerDone", ctx), cls.JobTimeoutMs, evaluated, ctx)
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

    ; Every parameter of a worker element, evaluated in the engine (E0026, ParamEvaluator): an Array, in the order of
    ; Parameters(), of Map {id, value} or {id, error}. The value is made fit for JSON (_Wire). Throws if Parameters() of
    ; the class throws.
    static _EvalForWorker(cls, ctx, params) {
        list := []
        src := ctx.EvalSource()
        for item in ParamEvaluator.List(cls, ctx) {
            src.at.param := item["id"]
            r := ParamEvaluator.One(item, params, src)
            entry := Map("id", r["id"])
            if (r["error"] != "")
                entry["error"] := r["error"]
            else
                entry["value"] := Executor.ToWire(r["value"])
            list.Push(entry)
        }
        return list
    }

    ; A value that JSON can carry: a Float that is not finite (inf, nan) becomes its text, a Map is copied with its
    ; values made fit too. JSON has no Integer keys: the worker turns keys of digits back into Integers.
    static ToWire(value) {
        if (value is Map) {
            m := Map()
            m.CaseSense := "Off"
            for k, v in value
                m[k] := Executor.ToWire(v)
            return m
        }
        if (Type(value) = "Float" && value - value != 0)
            return String(value)
        return value
    }

    ; Called by WorkerBridge when the job ends (bound: ctx first). Exports become variables where their name says (an
    ; A_ name a thread variable). An element can also set variables during the run (SetVar through the engine, WI-0050).
    _OnWorkerDone(ctx, result, message, exports) {
        if (!ExecContext.IsResult(result)) {
            message := "worker reported result '" result "'"
            result := "exception"
        }
        for name, value in exports
            ctx.SetVar(name, value, VarNames.IsA(name) ? "thread" : "")
        ctx.Finish(result, message)
    }

    ; Called by ExecContext.Finish (bound arguments first, then ctx, result, msg).
    _OnFinish(instId, threadId, ctx, result, msg) {
        runRec := this._runs.Get(instId, "")
        if (!IsObject(runRec)) {
            Log.Write("f2", "engine", "late finish '" result "' for ended instance " instId, "")
            return
        }
        inst := runRec["inst"]
        thr := inst.Threads.Get(threadId, "")
        if (!IsObject(thr)) {
            Log.Write("f2", "engine", "late finish '" result "' for removed thread " threadId, runRec["flowId"])
            return
        }
        ; One take: _StopRun may have taken the entry already (F-0012). Then the thread is stopping and Finish
        ; answers "late" below, so the element is stopped and released once, by _StopRun.
        try {
            runRec["active"].Delete(threadId)
        } catch {
            ; reason: the entry is gone, taken by _StopRun (the thread is then stopping)
        }
        if (thr.Finish(result, msg) = "late") {
            Log.Write("f2", "engine", "late finish '" result "' for thread " threadId, runRec["flowId"])
            return
        }
        this._ElementStopped(runRec, thr.ElementId, result, msg)
        this._Advance(runRec, thr)
        this._owner.Kick()
    }

    ; Moves a finished thread on (Scheduler.Advance) and ends the instance when nothing is left.
    ; Critical: Scheduler.Advance sets a thread "ready" a few lines before it names the next element.
    ; A dispatch tick that interrupts in between (AHK interrupts after 15 ms) would run the thread with
    ; its old element, e.g. a trigger as an action ("cannot be an action"; seen in 2 of about 50 runs
    ; with 200 parallel instances, WI-0016).
    _Advance(run, thread) {
        def := this._DefOf(run)
        if (!IsObject(def)) {
            this._StopRun(run, "flow.deleted")
            return
        }
        prev := Critical("On")  ; reason: advancing the thread must not be interrupted (see above)
        try {
            advOutcome := Scheduler.Advance(run["inst"], def, thread, () => Ids.Next("thr-"))
            if (advOutcome["unhandled"]) {
                Log.Write("f0", "engine", "unhandled exception in element " thread.ElementId ": " thread.Message
                    , run["flowId"])
                if (run["error"] = "")      ; for the caller of the instance (CallFlow)
                    run["error"] := "element '" thread.ElementId "': " thread.Message
                this._owner.FlowException(run["flowId"], thread.ElementId, thread.Message)   ; notice (WI-0075)
            }
            this._CheckEnded(run, advOutcome["unhandled"] ? "exception" : "finished")
        } finally {
            Critical(prev)
        }
    }

    ; Stops one instance: running elements get Stop and are released at once (the element has no
    ; asynchronous acknowledgement in WI-0010, so the 2 s deadline of ARCHITECTURE 5.1 never applies).
    _StopRun(run, reason) {
        inst := run["inst"]
        if (!inst.Stop(reason))
            return
        for threadId in Executor._Keys(inst.Threads) {
            thr := inst.Threads.Get(threadId, "")
            if (!IsObject(thr) || thr.State != "stopping")
                continue
            ; One take (F-0012): a finish that meets this stop may have taken the entry; then the element has
            ; ended and needs no stop. The thread is released here either way.
            act := ""
            try {
                act := run["active"].Delete(threadId)
            } catch {
                ; reason: the entry is gone, taken by a finish of this thread (the element has ended)
            }
            if (IsObject(act)) {
                if (act.Has("execId"))
                    this._owner.workers.Cancel(act["execId"])
                else
                    ElementRunner.Stop(act["cls"], act["ctx"], act["params"])
            }
            this._ElementStopped(run, thr.ElementId, "stopped", "")
            inst.ReleaseThread(threadId, reason)
        }
        this._CheckEnded(run, reason)
    }

    ; Starts the first waiting instance of the flow if no started instance is left. Returns true if it did.
    _PromoteWaiting(flowId) {
        queue := this._waiting.Get(flowId, "")
        if (!IsObject(queue) || queue.Length = 0)
            return false
        for _, runRec in this._runs {
            if (runRec["flowId"] = flowId && runRec["inst"].State != "waiting")
                return false
        }
        instId := queue.RemoveAt(1)
        runRec := this._runs.Get(instId, "")
        if (!IsObject(runRec))
            return true
        this._Launch(runRec)
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
            ; A waiting call (CallFlow): the caller gets the outcome in the next Tick, not from inside this step.
            call := run["call"]
            if (IsObject(call)) {
                callerRun := this._runs.Get(call["caller"], "")
                if (IsObject(callerRun) && callerRun["callees"].Has(instId))
                    callerRun["callees"].Delete(instId)
                if (!call["cancelled"])
                    this._notes.Push([call, Executor._Outcome(run, reason)])
            }
            ; The calls that this instance waited for: nobody waits for them any more, they run on.
            for calleeId in Executor._Keys(run["callees"]) {
                calleeRun := this._runs.Get(calleeId, "")
                if (IsObject(calleeRun) && IsObject(calleeRun["call"]))
                    this.CancelCall(calleeRun["call"])
            }
        } finally {
            Critical(prev)
        }
        this._owner.Emit("topic:flow:" run["flowId"], "evt.instance.ended"
            , Map("flowId", run["flowId"], "instanceId", instId, "reason", reason))
        this._owner.EmitFlowState(run["flowId"])
        this._owner.Kick()
    }

    ; --- element events ------------------------------------------------------------------------

    ; connectionId: the connection the thread took to the element ("" at a trigger), sent with the start (WI-0086).
    _ElementStarted(run, elementId, connectionId := "") {
        prev := Critical("On")  ; reason: read, change and store of the count is one step (a dispatch tick may interrupt)
        rec := this._Elem(run["flowId"], elementId)
        rec["countRuns"] := rec["countRuns"] + 1
        rec["lastRun"] := FormatTime(A_NowUTC, "yyyy-MM-dd HH:mm:ss")
        this._CountExecution(run)      ; the runaway guard (WI-0066): the one counting point of an element execution
        Critical(prev)
        rec["state"] := "running"
        rec["message"] := ""
        this._EmitElement(rec, connectionId)
    }

    ; result "normal", "yes", "no", "head", "tail", "exception" or "stopped" (stop by the engine).
    _ElementStopped(run, elementId, result, msg) {
        prev := Critical("On")  ; reason: read, change and store of the count is one step (see _ElementStarted)
        rec := this._Elem(run["flowId"], elementId)
        n := Max(0, rec["countRuns"] - 1)
        rec["countRuns"] := n
        Critical(prev)
        if (n > 0)
            state := "running"
        else
            state := (result = "exception") ? "exception" : "finished"
        rec["state"] := state
        rec["message"] := (result = "exception") ? msg : ""
        this._EmitElement(rec, "")
    }

    ; The record of one element of a flow (WI-0086), created by its first start or warning. Its fields: flowId, elementId,
    ; state (idle, running, finished, exception), countRuns, lastRun, message, warnings and lastWarning (the warnings of
    ; the evaluations, see _Warned), and dirty and sentAt for the coalesced events (_Mark).
    _Elem(flowId, elementId) {
        flow := this._elems.Get(flowId, "")
        if (!IsObject(flow)) {
            flow := Map()
            flow.CaseSense := "Off"
            this._elems[flowId] := flow
        }
        rec := flow.Get(elementId, "")
        if (!IsObject(rec)) {
            rec := Map("flowId", flowId, "elementId", elementId, "state", "idle", "countRuns", 0, "lastRun", ""
                , "message", "", "warnings", 0, "lastWarning", "", "dirty", false, "sentAt", -2000)
            flow[elementId] := rec
        }
        return rec
    }

    ; The errors and warnings of one evaluation of an element, in compatibility mode (ExecContext.onWarn, WI-0086). The
    ; count is exact; the event is coalesced by _Mark. An error here is logged and does not reach the element.
    _Warned(flowId, elementId, paramId, records) {
        try {
            prev := Critical("On")  ; reason: the count and the last text change as one step (a flush may interrupt)
            try {
                rec := this._Elem(flowId, elementId)
                rec["warnings"] := rec["warnings"] + records.Length
                rec["lastWarning"] := Executor._WarningText(paramId, records[records.Length])
            } finally {
                Critical(prev)
            }
            this._Mark(rec)
        } catch as e {
            Log.Write("a0", "engine", "warnings of element " elementId " could not be counted: " e.Message, flowId)
        }
    }

    ; The text of the last warning: parameter, message, line and column, at most 500 characters.
    static _WarningText(paramId, rec) {
        text := (paramId != "" ? "parameter '" paramId "': " : "") rec["message"]
            . " (line " rec["line"] ", column " rec["col"] ")"
        return SubStr(text, 1, 500)
    }

    ; Marks a record for evt.element.warning and sends what is due. At most one event per second and element: a record
    ; sent less than a second ago waits, and the flush timer sends it when the second is over (the count is then the
    ; exact one, as it is read at the send).
    _Mark(rec) {
        if (!rec["dirty"]) {
            rec["dirty"] := true
            this._dirty.Push(rec)
        }
        this._FlushWarnings()
    }

    _FlushWarnings() {
        now := A_TickCount
        rest := []
        ; take the list first: a warning that arrives while an Emit below is interrupted must not be lost by the store of rest
        pending := this._dirty
        this._dirty := []
        for rec in pending {
            if (!rec["dirty"])
                continue                    ; dropped by ForgetFlow
            if (now - rec["sentAt"] < 1000) {
                rest.Push(rec)
                continue
            }
            rec["dirty"] := false
            rec["sentAt"] := now
            this._owner.Emit("topic:flow:" rec["flowId"], "evt.element.warning"
                , Map("flowId", rec["flowId"], "elementId", rec["elementId"], "count", rec["warnings"]
                    , "text", rec["lastWarning"]))
        }
        for rec in rest
            this._dirty.Push(rec)
        if (this._dirty.Length && !this._flushScheduled) {
            this._flushScheduled := true
            SetTimer(this._flushFn, -1000)
        }
    }

    _FlushTimer() {
        this._flushScheduled := false
        this._FlushWarnings()
    }

    ; Drops the counts and warnings of a flow that was deleted (WI-0086). Its waiting warning events are not sent.
    ForgetFlow(flowId) {
        flow := this._elems.Get(flowId, "")
        if (!IsObject(flow))
            return
        for elementId, rec in flow
            rec["dirty"] := false
        this._elems.Delete(flowId)
    }

    ; The states of the elements of a flow that ran or have warnings, for cmd.flow.runstate (PROTOCOL 4.2). The counts of an
    ; element that def no longer has are dropped here. def: the committed definition of the flow.
    ElementStates(flowId, def) {
        list := []
        flow := this._elems.Get(flowId, "")
        if (!IsObject(flow))
            return list
        for elementId in Executor._Keys(flow) {
            rec := flow[elementId]
            if (!def.HasElement(elementId)) {
                rec["dirty"] := false
                flow.Delete(elementId)
                continue
            }
            entry := Map("elementId", elementId, "state", rec["state"], "countRuns", rec["countRuns"]
                , "lastRun", rec["lastRun"], "warnings", rec["warnings"])
            if (rec["message"] != "")
                entry["message"] := rec["message"]
            if (rec["warnings"] > 0)
                entry["lastWarning"] := rec["lastWarning"]
            list.Push(entry)
        }
        return list
    }

    _EmitElement(rec, connectionId) {
        payload := Map("flowId", rec["flowId"], "elementId", rec["elementId"], "state", rec["state"]
            , "countRuns", rec["countRuns"], "lastRun", rec["lastRun"])
        if (rec["message"] != "")
            payload["message"] := rec["message"]
        if (connectionId != "")
            payload["connectionId"] := connectionId      ; the connection taken, on running only (PROTOCOL 4.3)
        this._owner.Emit("topic:flow:" rec["flowId"], "evt.element.state", payload)
    }

    _OnSlow(flowId, classId, ms) {
        Log.Write("f0", "engine", "element " classId " blocked the engine for " Round(ms) " ms, it must be inline-safe"
            , flowId)
    }

    ; --- helpers -------------------------------------------------------------------------------

    ; depth: waiting calls that lead to the instance; call: the waiting call that started it ("" if nobody waits);
    ; callees: instance ID -> true for the calls that elements of this instance wait for; error: the first exception that
    ; ended a thread without a connection ("element '<id>': <message>"), for the outcome of a call.
    static _NewRun(instId, flowId, inst, triggerId) {
        runRec := Map("instanceId", instId, "flowId", flowId, "inst", inst, "triggerId", triggerId, "active", Map()
            , "depth", 0, "call", "", "callees", Map(), "error", "")
        runRec["active"].CaseSense := "Off"
        runRec["callees"].CaseSense := "Off"
        return runRec
    }

    ; Sets the initial instance variables of a new instance (v1 newInstance with p_instanceVars): a copy of each value,
    ; whatever the prefix of the name (as v1 InstanceVariable_Set and ctx.ImportInstanceVars). A name that is empty or has
    ; a forbidden character is skipped with an f0 entry.
    static _SetInstanceVars(inst, vars, flowId) {
        for name, value in vars {
            check := VarNames.Check(String(name))
            if (check = "Empty" || check = "ForbiddenCharacter") {
                Log.Write("f0", "engine", "Setting variable '" name "' failed. It contains forbidden characters.", flowId)
                continue
            }
            try {
                inst.Vars[String(name)] := VarValues.Import(value)
            } catch as e {
                Log.Write("f0", "engine", "Setting variable '" name "' failed: " e.Message, flowId)
            }
        }
    }

    ; Notes the waiting call of a new instance at its caller. A caller that is gone, or whose thread does not run its
    ; element any more (a policy stop of the caller's own flow has just stopped it), waits for nothing: the call is
    ; cancelled at once and the instance runs without anybody waiting for it.
    _NoteCall(runRec, call) {
        callerId := call["caller"]
        if (callerId != "") {
            callerRun := this._runs.Get(callerId, "")
            thr := IsObject(callerRun) ? callerRun["inst"].Threads.Get(call["callerThread"], "") : ""
            if (!IsObject(callerRun) || (call["callerThread"] != "" && (!IsObject(thr) || thr.State != "running"))) {
                call["cancelled"] := 1
                call["onEnd"] := ""
                return
            }
            callerRun["callees"][runRec["instanceId"]] := true
        }
        call["instanceId"] := runRec["instanceId"]
        runRec["call"] := call
    }

    ; True if an instance of the flow (running, stopping or waiting) waits, directly or through others, for the instance
    ; callerId. A new instance of the flow that is queued by the policy wait waits for all of them, so a call of it that
    ; the caller waits for would never end. The edges: an instance waits for the instances its elements called and wait
    ; for (callees); a queued instance waits for every started instance of its flow and for the queued ones before it.
    _WaitsFor(flowId, callerId) {
        if (callerId = "")
            return false
        todo := []
        for id, runRec in this._runs {
            if (runRec["flowId"] = flowId)
                todo.Push(id)
        }
        seen := Map()
        seen.CaseSense := "Off"
        while (todo.Length) {
            id := todo.Pop()
            if (id = callerId)
                return true
            if (seen.Has(id))
                continue
            seen[id] := true
            runRec := this._runs.Get(id, "")
            if (!IsObject(runRec))
                continue
            for calleeId in runRec["callees"]
                todo.Push(calleeId)
            if (runRec["inst"].State != "waiting")
                continue
            queue := this._waiting.Get(runRec["flowId"], [])
            for otherId, other in this._runs {
                if (other["flowId"] != runRec["flowId"] || otherId = id)
                    continue
                if (other["inst"].State != "waiting") {
                    todo.Push(otherId)
                    continue
                }
                for queuedId in queue {           ; a queued instance before this one in the queue
                    if (queuedId = id)
                        break
                    if (queuedId = otherId) {
                        todo.Push(otherId)
                        break
                    }
                }
            }
        }
        return false
    }

    ; The outcome of an ended instance for its caller (see CallFlow).
    static _Outcome(run, reason) {
        if (run["error"] != "")
            result := "exception"
        else
            result := (reason = "finished") ? "normal" : "stopped"
        vars := ""
        call := run["call"]
        if (IsObject(call) && call["withVars"]) {
            vars := VarValues.NewMap()
            for name, value in run["inst"].Vars
                vars[name] := VarValues.Copy(value)
        }
        return Map("instanceId", run["instanceId"], "flowId", run["flowId"], "reason", reason, "result", result
            , "message", run["error"], "vars", vars)
    }

    ; Gives the outcome of a called instance to its caller, once (a Tick does it, see CallFlow). An error of the
    ; function is logged; the function of an element (ExecContext) catches its own errors.
    _Deliver(note) {
        call := note[1]
        if (call["cancelled"])
            return
        fn := call["onEnd"]
        call["cancelled"] := 1
        call["onEnd"] := ""
        try {
            fn(note[2])
        } catch as e {
            Log.Write("a0", "engine", "the end of instance " note[2]["instanceId"] " could not be given to its caller: "
                . Type(e) ": " e.Message, note[2]["flowId"])
        }
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
        params := {}
        for k, v in Executor._ParamMap(def, elementId)
            params.%k% := v
        return params
    }

    ; The same parameters as a Map (sent to workers as JSON). Objects and null values become "".
    static _ParamMap(def, elementId) {
        m := Map()
        elem := def.Element(elementId)
        pars := (elem is Map) ? elem.Get("pars", "") : ""
        if (pars is Map) {
            for k, v in pars {
                if (IsObject(v))
                    v := ""
                m[k] := v
            }
        }
        return m
    }

    ; The view of one element run on the variables (WI-0040). The built-in variables a_flowName, a_elementName and
    ; a_workingdir come from the revision the element starts with.
    _VarAccess(run, thread, def, elementId) {
        elem := def.Element(elementId)
        name := (elem is Map) ? elem.Get("name", "") : ""
        env := Map("flowId", run["flowId"], "elementId", elementId, "flowName", def.Name
            , "elementName", IsObject(name) ? "" : String(name)
            , "workingDir", BuiltInVars.WorkingDirOf(def.Raw.Get("flowSettings", ""), this._owner.settings.Value("workingDir")))
        return VarAccess(this._owner.vars, run["inst"], thread, env)
    }

    ; An element context for a variable request of a client (WI-0050, VarRequests): the view of the instance and, with a
    ; threadId, of that thread, with the type mode of the flow. Without a thread the context has no loop and thread
    ; variables (an empty stand-in; ctx.noThread is true). Throws AhfError gone when the instance or the thread does not
    ; exist (any more).
    ContextOf(instId, threadId := "") {
        runRec := this._runs.Get(instId, "")
        if (!IsObject(runRec))
            throw AhfError("instance '" instId "' does not exist (ended or never started)", ErrCode.GONE)
        def := this._DefOf(runRec)
        if (!IsObject(def))
            throw AhfError("the flow of instance '" instId "' is not loaded any more", ErrCode.GONE)
        if (threadId != "") {
            thr := runRec["inst"].Threads.Get(threadId, "")
            if (!IsObject(thr) || thr.State = "removed")
                throw AhfError("thread '" threadId "' of instance '" instId "' does not exist", ErrCode.GONE)
            elementId := thr.ElementId
        } else {
            thr := ThreadState("-", instId, "")      ; stand-in: no thread variables, no loops
            elementId := ""
        }
        ctx := ExecContext(runRec["flowId"], elementId, instId, threadId, "", this._VarAccess(runRec, thr, def, elementId))
        ctx.strictTypes := def.StrictTypes
        ctx.noThread := (threadId = "")
        return ctx
    }

    static _IsWorkerElement(def, thread) {
        return ElementRegistry.ModeOf(Executor._QidOf(def, thread.ElementId)) = "worker"
    }

    ; The qualified ID of an element of the flow: its package (missing means Default) and its class (E0045).
    static _QidOf(def, elementId) => ElementRegistry.QualifiedId(def.ElementPackage(elementId), def.ElementClass(elementId))

    ; The text of an error for a log line: an element error as it is, any other error with its type.
    static ErrorText(e) {
        if (e is ElementError)
            return e.Message
        if (e is Error)
            return Type(e) ": " e.Message
        return String(e)
    }

    ; Snapshot of the keys of a Map, so the Map can change while the keys are walked.
    static _Keys(m) {
        keys := []
        for k in m
            keys.Push(k)
        return keys
    }
}
