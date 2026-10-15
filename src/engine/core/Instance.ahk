#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ..\..\core\Log.ahk
#Include ThreadState.ahk
#Include ..\vars\VarValues.ahk

; Instance state machine (WI-0008, ARCHITECTURE 5.1, normative).
;
; One instance = one run of a flow, started by a trigger. It holds its threads. The instance
; ends when its last thread is removed (v1 removeThread / removeInstance, Instances and
; Threads.ahk).
;
; The row "(new) + policy skip" of ARCHITECTURE 5.1 is not a transition: no instance is created.
; ExecutionPolicy.Decide returns "skip" and the caller reports the callback "skipped".
;
; Invalid transitions return false and go to OnInvalid(from, to, reason) or the a0 log, as in
; ThreadState.
class Instance {
    ; from state -> allowed target states.
    ; new -> running: flow.start or trigger accepted (v1 newInstance)
    ; new -> waiting: policy wait and the flow is executing (E0002, M-0011)
    ; waiting -> running: the instances before it ended (FIFO per flow)
    ; waiting -> ended: stopped while waiting (flow stop, flow deleted)
    ; running -> ended: last thread removed (v1 removeThread)
    ; running -> stopping: flow stop or policy stop (v1 stopInstance)
    ; stopping -> ended: all threads removed, or deadline (2 s) without acknowledgement
    static Transitions := Map(
        "new", ["running", "waiting"],
        "waiting", ["running", "ended"],
        "running", ["stopping", "ended"],
        "stopping", ["ended"],
        "ended", []
    )

    ; Deadline in ms for a stopping instance (ARCHITECTURE 5.1). The caller uses it for its timer.
    static StopDeadlineMs := 2000

    __New(id, flowId, onInvalid := "") {
        this.Id := id
        this.FlowId := flowId
        this.State := "new"
        this.OnInvalid := onInvalid
        this.Threads := Map()
        ; Instance variables (WI-0040): every name without a prefix. Shared by all threads of the instance.
        this.Vars := VarValues.NewMap()
        this.HiddenVars := VarValues.NewMap()
    }

    ; new or waiting -> running. Creates the trigger thread (threadId, triggerElementId) in state finished
    ; with result "Normal". That is v1 newThread plus finishExecutionOfElement("Normal").
    ; The caller then calls Scheduler.Advance for it. Returns the thread, or "" if rejected.
    Start(threadId, triggerElementId) {
        if (!this.TryTransition("running", "start"))
            return ""
        thread := ThreadState(threadId, this.Id, triggerElementId, "finished", "Normal", this.OnInvalid)
        this.Threads[threadId] := thread
        return thread
    }

    ; new -> waiting (policy wait). The instance has no thread until Start. Returns false if rejected.
    Wait() {
        return this.TryTransition("waiting", "queued")
    }

    ; Adds a thread that belongs to this instance (used for clones made by the Scheduler).
    AddThread(thread) {
        if (thread.InstanceId != this.Id)
            throw AhfError("Instance.AddThread: thread belongs to instance '" thread.InstanceId "'", ErrCode.INTERNAL)
        this.Threads[thread.Id] := thread
    }

    ; Removes a thread that is in state removed. Returns false if the thread is unknown or not
    ; removed. The instance ends when no thread is left (running -> ended, stopping -> ended).
    ; Moving a thread to removed is the caller's job (ThreadState.TryTransition), except here
    ; ReleaseThread does it in one call.
    ReleaseThread(threadId, reason := "released") {
        thread := this.Threads.Get(threadId, "")
        if (thread = "")
            return false
        if (!thread.TryTransition("removed", reason))
            return false
        this.Threads.Delete(threadId)
        this._CheckEnded()
        return true
    }

    ; running -> stopping. Threads that run an element become stopping (the element is asked to
    ; stop by the caller). Ready and finished threads are removed at once. If no thread is left,
    ; the instance ends. Returns false if the instance is not running.
    Stop(reason := "stop") {
        if (this.State = "waiting") {
            ; A waiting instance has no thread: it ends at once.
            return this.TryTransition("ended", reason)
        }
        if (!this.TryTransition("stopping", reason))
            return false
        ids := []
        for id in this.Threads
            ids.Push(id)
        for id in ids {
            thread := this.Threads.Get(id, "")
            if (thread = "")
                continue
            if (thread.State = "running")
                thread.TryTransition("stopping", reason)
            else
                this.ReleaseThread(id, reason)
        }
        this._CheckEnded()
        return true
    }

    ; stopping -> ended by deadline: all remaining threads are dropped without acknowledgement.
    ; The caller logs the forced end. Returns false if the instance is not stopping.
    Expire(reason := "deadline") {
        if (this.State != "stopping") {
            Instance.ReportInvalid(this.OnInvalid, this.Id, this.State, "ended", "deadline: " reason)
            return false
        }
        for id, thread in this.Threads {
            if (thread.State = "running")
                thread.TryTransition("stopping", reason)
            thread.TryTransition("removed", reason)
        }
        this.Threads.Clear()
        this.TryTransition("ended", reason)
        return true
    }

    ; Ends the instance when no thread is left. Only the states running and stopping can end.
    _CheckEnded() {
        if (this.Threads.Count > 0)
            return
        if (this.State = "running")
            this.TryTransition("ended", "last thread removed")
        else if (this.State = "stopping")
            this.TryTransition("ended", "all threads removed")
    }

    ; Checks the table. Returns true and changes State, or false and reports it.
    TryTransition(newState, reason := "") {
        ok := false
        prev := Critical("On")  ; reason: checking and changing the state is one step (an interrupting timer may race)
        try {
            allowed := Instance.Transitions.Get(this.State, [])
            for target in allowed {
                if (target = newState) {
                    this.State := newState
                    ok := true
                    break
                }
            }
        } finally {
            Critical(prev)
        }
        if (ok)
            return true
        Instance.ReportInvalid(this.OnInvalid, this.Id, this.State, newState, reason)
        return false
    }

    static ReportInvalid(onInvalid, owner, from, to, reason) {
        ThreadState.ReportInvalid(onInvalid, "instance " owner, from, to, reason)
    }
}
