#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ..\..\core\Log.ahk
#Include Loops.ahk

; Thread state machine (WI-08, ARCHITEKTUR 5.2, normative).
;
; States follow v1 with one rename: v1 "starting" is "ready" here (v1 Execution Task.ahk:57).
; Transitions are only allowed if listed in Transitions. Anything else returns false and is
; reported through OnInvalid(from, to, reason), or logged as a0 when no callback is set.
;
; Late Finish: Finish() on a thread that is not running is not a transition. v1 ignores it
; (finishExecutionOfElement, v1 Execution Task.ahk:266 to 270). Finish()
; returns "late" and does not call OnInvalid; the caller logs f2.
;
; Clone() copies the thread for an additional matching connection (v1 newThread with
; ToCloneFromThreadID, Instances and Threads.ahk). The caller gives the new ID, there is no
; counter here (see Ids in src/core/Ids.ahk).
class ThreadState {
    ; from state -> allowed target states.
    ; ready -> running: dispatcher picks the thread (v1 Execution Task.ahk:57 to 71)
    ; running -> finished: element called Finish
    ; finished -> ready: next connection found (v1 Execution Task.ahk:119 to 150)
    ; finished -> removed: no matching connection (v1 Execution Task.ahk:153 to 166)
    ; running -> stopping: instance stop (v1 Execution Task.ahk:175 to 178, 195)
    ; stopping -> removed: stop acknowledged or deadline
    ; ready -> removed: instance stop before dispatch
    ; finished -> removed: instance stop while the result waits for the dispatcher (not in the
    ;   table of ARCHITEKTUR 5.2, see WI-08 open question 4)
    static Transitions := Map(
        "ready", ["running", "removed"],
        "running", ["finished", "stopping"],
        "finished", ["ready", "removed"],
        "stopping", ["removed"],
        "removed", []
    )

    ; id: thread ID from the caller. state: "ready" (default) or any state, used by Clone.
    ; result / message: set for a thread that starts as finished (trigger thread, v1 newInstance
    ; finishes it with "Normal").
    __New(id, instanceId, elementId, state := "ready", result := "", onInvalid := "") {
        if (!ThreadState.Transitions.Has(state))
            throw AhfError("ThreadState: unknown state '" state "'", ErrCode.BAD_ARGS)
        this.Id := id
        this.InstanceId := instanceId
        this.ElementId := elementId
        this.EntryPoint := ""
        this.State := state
        this.Result := result
        this.Message := ""
        this.Loops := LoopStack()
        this.OnInvalid := onInvalid
    }

    ; Checks the transition table. Returns true and changes State, or false and reports it.
    TryTransition(newState, reason := "") {
        allowed := ThreadState.Transitions.Get(this.State, [])
        for target in allowed {
            if (target = newState) {
                this.State := newState
                return true
            }
        }
        ThreadState.ReportInvalid(this.OnInvalid, "thread " this.Id, this.State, newState, reason)
        return false
    }

    ; ready -> running. The caller starts the element (inline or worker) afterwards.
    Dispatch() {
        return this.TryTransition("running", "dispatched")
    }

    ; running -> finished, with the result and message of the element.
    ; Returns "finished", or "late" if the thread is no longer running (the caller logs f2).
    Finish(result, message := "") {
        if (this.State != "running")
            return "late"
        this.TryTransition("finished", "element finished with result " result)
        this.Result := result
        this.Message := message
        return "finished"
    }

    ; Copy with a new ID. Keeps state, element, entry point, result and loop stacks (deep copy).
    Clone(newId) {
        copy := ThreadState(newId, this.InstanceId, this.ElementId, this.State, this.Result, this.OnInvalid)
        copy.EntryPoint := this.EntryPoint
        copy.Message := this.Message
        copy.Loops := this.Loops.Clone()
        return copy
    }

    ; Reports an invalid transition. A callback that throws must not break the engine, so its
    ; error is logged instead. Without a callback the transition goes to the a0 log.
    static ReportInvalid(onInvalid, owner, from, to, reason) {
        cb := onInvalid
        if (IsObject(cb)) {
            try {
                cb(from, to, reason)
            } catch as e {
                Log.Write("a0", "engine", "onInvalid callback failed for " owner ": " e.Message)
            }
            return
        }
        Log.Write("a0", "engine", "invalid thread transition " from " -> " to " for " owner " (" reason ")")
    }
}
