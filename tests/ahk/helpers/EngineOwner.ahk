#Requires AutoHotkey v2.0
; Test owner for Executor (WI-0021): a stand-in for Engine that records events instead of sending them.
; Provides what Executor reads from its owner: flows (FlowTable), vars (EngineVars), workers, Emit, EmitFlowState, Kick.
#Include ..\..\..\src\engine\Executor.ahk
#Include ..\..\..\src\engine\FlowTable.ahk
#Include ..\..\..\src\engine\EngineSettings.ahk
#Include ..\..\..\src\elements\base\AhfElement.ahk
#Include ..\..\..\src\elements\base\ElementRegistry.ahk

; Stand-in for WorkerBridge. A job stays open until the test completes it.
class FakeWorkers {
    __New() {
        this.runs := 0
        this.jobs := Map()
        this.hasFree := true
        this.failAtOnce := false   ; Run ends the job at once and still returns the execId (send error)
        this.hook := ""            ; called once, inside Usable() (an interruption point of Executor.Tick)
        this.cancelled := []
        this.wanted := []          ; the arguments of Want (threads waiting for a worker)
        this.timeouts := []        ; the jobTimeoutMs of every Run
        this.imports := []         ; the imports of every Run
        this.payloads := Map()     ; execId -> Map classId, params, imports, env, evaluated (what cmd.worker.run sends)
    }

    Want(waiting) {
        this.wanted.Push(waiting)
    }

    Usable() {
        h := this.hook
        if (IsObject(h)) {
            this.hook := ""
            h()
        }
        return true
    }

    Free() => this.hasFree

    Run(classId, params, imports, env, onDone, jobTimeoutMs := 0, evaluated := "", ctx := "") {
        this.runs += 1
        this.timeouts.Push(jobTimeoutMs)
        this.imports.Push(imports)
        execId := "fx-" this.runs
        this.payloads[execId] := Map("classId", classId, "params", params, "imports", imports, "env", env
            , "evaluated", evaluated, "ctx", ctx)
        if (this.failAtOnce) {
            onDone("exception", "worker not available", Map())
            return execId
        }
        this.jobs[execId] := onDone
        return execId
    }

    ; As WorkerBridge.JobOf (WI-0050): the context of an open job, the slot is always "worker:fake".
    JobOf(execId) {
        if (!this.jobs.Has(execId))
            return ""
        return Map("ctx", this.payloads[execId]["ctx"], "slot", "worker:fake")
    }

    Cancel(execId) {
        this.cancelled.Push(execId)
        this.jobs.Delete(execId)
        return true
    }

    Complete(execId, result := "normal", exports := "", message := "") {
        onDone := this.jobs[execId]
        this.jobs.Delete(execId)
        onDone(result, message, IsObject(exports) ? exports : Map())
    }
}

; Stand-in for TriggerArms (WI-0062): a start without an event has no trigger parameters.
class NoArms {
    StartInfo(rec, triggerId) => ""
}

class EngineOwner {
    __New() {
        this.arms := NoArms()
        this.settings := EngineSettings(this)    ; the defaults (WI-0077); a test may change settings._values
        this.flows := FlowTable()
        this.vars := EngineVars()
        this.workers := FakeWorkers()
        this.events := []
        this.kicks := 0
        this.executor := Executor(this)
    }

    Emit(to, msgType, payload) {
        this.events.Push(Map("to", to, "type", msgType, "payload", payload))
    }

    EmitFlowState(flowId) {
        this.Emit("topic:flow:" flowId, "evt.flow.state"
            , Map("flowId", flowId, "executing", this.executor.IsExecuting(flowId)))
    }

    Kick() {
        this.kicks += 1
    }

    ; The runaway guard stopped a flow (Engine.LimitReached, WI-0066): the stand-in records it.
    LimitReached(flowId, kind, limit) {
        this.limits := this.HasProp("limits") ? this.limits : []
        this.limits.Push(Map("flowId", flowId, "kind", kind, "limit", limit))
    }

    ; An unhandled exception ended a branch of a flow (Engine.FlowException, WI-0075): the stand-in records it.
    FlowException(flowId, elementId, message) {
        this.exceptions := this.HasProp("exceptions") ? this.exceptions : []
        this.exceptions.Push(Map("flowId", flowId, "elementId", elementId, "message", message))
    }

    ; Dispatches until nothing is ready (one Tick does that, up to Executor.TICK_BATCH).
    Drive() {
        this.executor.Tick()
    }

    ; "type:n" of the evt.instance.* events, in order, "n" is the index of the instance in ids.
    InstanceLog(ids) {
        out := ""
        for ev in this.events {
            if (SubStr(ev["type"], 1, 13) != "evt.instance.")
                continue
            n := 0
            for i, id in ids {
                if (id = ev["payload"]["instanceId"])
                    n := i
            }
            out .= (out = "" ? "" : ",") SubStr(ev["type"], 14) ":" n
        }
        return out
    }

    ; The states of one element as "state state ...".
    ElementStates(elementId) {
        out := ""
        for ev in this.events {
            if (ev["type"] = "evt.element.state" && ev["payload"]["elementId"] = elementId)
                out .= (out = "" ? "" : " ") ev["payload"]["state"]
        }
        return out
    }

    ; The reason of the last evt.instance.ended.
    LastEndReason() {
        last := ""
        for ev in this.events {
            if (ev["type"] = "evt.instance.ended")
                last := ev["payload"]["reason"]
        }
        return last
    }
}
