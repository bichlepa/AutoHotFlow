#Requires AutoHotkey v2.0
; Unit tests for src/engine/core/ThreadState.ahk and Instance.ahk (WI-0008, ARCHITECTURE 5.1, 5.2).
; The expected transitions below are copied from the tables in doc/ARCHITECTURE.md, not from the code.
#Include lib\Assert.ahk
#Include ..\..\src\engine\core\Instance.ahk
#Include ..\..\src\core\Log.ahk

; Allowed transitions as "|from>to|" pairs, copied from the tables. Every pair of states is checked.
ThreadStates() {
    return ["ready", "running", "finished", "stopping", "removed"]
}

ThreadAllowed() {
    return "|ready>running|ready>removed|running>finished|running>stopping|finished>ready|finished>removed|stopping>removed|"
}

InstanceStates() {
    return ["new", "waiting", "running", "stopping", "ended"]
}

InstanceAllowed() {
    return "|new>running|new>waiting|waiting>running|waiting>ended|running>stopping|running>ended|stopping>ended|"
}

; Callback that records invalid transitions as "from>to (reason)".
Recorder() {
    rec := []
    cb := (from, to, reason) => rec.Push(from ">" to " (" reason ")")
    return {rec: rec, cb: cb}
}

IsAllowed(allowedList, from, to) {
    return InStr(allowedList, "|" from ">" to "|") > 0
}

ThreadTableMatches() {
    for from in ThreadStates() {
        for to in ThreadStates() {
            rec := Recorder()
            t := ThreadState("t1", "i1", "e1", "ready", "", rec.cb)
            t.State := from
            ok := t.TryTransition(to, "table")
            expected := IsAllowed(ThreadAllowed(), from, to)
            if (ok != expected)
                throw AssertFailed("thread " from ">" to ": expected " expected " but got " ok)
            if (ok) {
                if (t.State != to || rec.rec.Length != 0)
                    throw AssertFailed("thread " from ">" to ": state or record wrong after an allowed transition")
            } else {
                if (t.State != from || rec.rec.Length != 1)
                    throw AssertFailed("thread " from ">" to ": rejected transition must keep the state and report once")
            }
        }
    }
}

InstanceTableMatches() {
    for from in InstanceStates() {
        for to in InstanceStates() {
            rec := Recorder()
            inst := Instance("i1", "f1", rec.cb)
            inst.State := from
            ok := inst.TryTransition(to, "table")
            expected := IsAllowed(InstanceAllowed(), from, to)
            if (ok != expected)
                throw AssertFailed("instance " from ">" to ": expected " expected " but got " ok)
            if (ok) {
                if (inst.State != to || rec.rec.Length != 0)
                    throw AssertFailed("instance " from ">" to ": state or record wrong after an allowed transition")
            } else {
                if (inst.State != from || rec.rec.Length != 1)
                    throw AssertFailed("instance " from ">" to ": rejected transition must keep the state and report once")
            }
        }
    }
}

; A trigger thread starts finished. The scheduler moves it to ready, the dispatcher to running.
ToRunning(thread) {
    Assert.True(thread.TryTransition("ready", "test"))
    Assert.True(thread.Dispatch())
}

; Late Finish on a thread that is not running: "late", no invalid report.
LateFinishIsIgnored() {
    rec := Recorder()
    t := ThreadState("t1", "i1", "e1", "ready", "", rec.cb)
    Assert.Equal(t.Finish("Normal"), "late")
    Assert.Equal(t.State, "ready")
    Assert.Equal(rec.rec.Length, 0)
    t.State := "stopping"
    Assert.Equal(t.Finish("Normal"), "late")
    Assert.Equal(rec.rec.Length, 0)
}

FinishStoresResult() {
    t := ThreadState("t1", "i1", "e1")
    t.Dispatch()
    Assert.Equal(t.Finish("Yes", "msg"), "finished")
    Assert.Equal(t.State, "finished")
    Assert.Equal(t.Result, "Yes")
    Assert.Equal(t.Message, "msg")
}

CloneIsDeep() {
    t := ThreadState("t1", "i1", "e1")
    t.Loops.Visible["i"] := 1
    c := t.Clone("t2")
    Assert.Equal(c.Id, "t2")
    Assert.Equal(c.State, "ready")
    c.Loops.Visible["i"] := 2
    c.Loops.Push()
    Assert.Equal(t.Loops.Visible["i"], 1)
    Assert.Equal(t.Loops.Depth, 0)
}

InvalidWithoutCallbackGoesToA0Log() {
    Log.Configure(Log.Memory)
    Log.memoryLines := []
    try {
        t := ThreadState("t1", "i1", "e1")
        Assert.Equal(t.TryTransition("finished", "x"), false)
        Assert.Equal(Log.memoryLines.Length, 1)
        Assert.Equal(Log.memoryLines[1]["level"], "a0")
    } finally {
        Log.Configure("")
        Log.memoryLines := []
    }
}

ThrowingCallbackIsLoggedNotRaised() {
    Log.Configure(Log.Memory)
    Log.memoryLines := []
    try {
        cb := (from, to, reason) => ThrowInCallback()
        t := ThreadState("t1", "i1", "e1", "ready", "", cb)
        Assert.Equal(t.TryTransition("finished", "x"), false)
        Assert.Equal(Log.memoryLines.Length, 1)
        Assert.Equal(Log.memoryLines[1]["level"], "a0")
    } finally {
        Log.Configure("")
        Log.memoryLines := []
    }
}

ThrowInCallback() {
    throw ValueError("callback failed")
}

UnknownThreadStateIsRejected() {
    err := Assert.Throws(MakeBadThread, AhfError)
    Assert.Equal(err.code, "bad_args")
}

MakeBadThread() {
    ThreadState("t1", "i1", "e1", "bogus")
}

StartCreatesFinishedTriggerThread() {
    inst := Instance("i1", "f1")
    Assert.Equal(inst.State, "new")
    t := inst.Start("t1", "trig")
    Assert.Equal(inst.State, "running")
    Assert.Equal(t.State, "finished")
    Assert.Equal(t.Result, "Normal")
    Assert.Equal(t.ElementId, "trig")
    Assert.Equal(inst.Threads.Count, 1)
}

StartTwiceIsRejected() {
    rec := Recorder()
    inst := Instance("i1", "f1", rec.cb)
    inst.Start("t1", "trig")
    Assert.Equal(inst.Start("t2", "trig"), "")
    Assert.Equal(rec.rec.Length, 1)
    Assert.Equal(inst.Threads.Count, 1)
}

LastThreadReleasedEndsRunningInstance() {
    inst := Instance("i1", "f1")
    inst.Start("t1", "trig")
    Assert.True(inst.ReleaseThread("t1"))
    Assert.Equal(inst.State, "ended")
    Assert.Equal(inst.Threads.Count, 0)
}

ReleaseNeedsRemovableThread() {
    rec := Recorder()
    inst := Instance("i1", "f1", rec.cb)
    t := inst.Start("t1", "trig")
    ToRunning(t)
    Assert.Equal(inst.ReleaseThread("t1"), false)   ; running -> removed is not allowed
    Assert.Equal(rec.rec.Length, 1)
    Assert.Equal(inst.State, "running")
    Assert.Equal(inst.ReleaseThread("nope"), false)
}

StopWithRunningThreadWaitsForAcknowledgement() {
    inst := Instance("i1", "f1")
    t1 := inst.Start("t1", "trig")
    ToRunning(t1)
    Assert.True(inst.Stop("flow.stop"))
    Assert.Equal(inst.State, "stopping")
    Assert.Equal(t1.State, "stopping")
    Assert.Equal(inst.Threads.Count, 1)
    Assert.True(inst.ReleaseThread("t1", "acknowledged"))
    Assert.Equal(inst.State, "ended")
}

StopWithReadyThreadEndsAtOnce() {
    inst := Instance("i1", "f1")
    inst.Start("t1", "trig")
    Assert.True(inst.Stop())
    Assert.Equal(inst.State, "ended")
    Assert.Equal(inst.Threads.Count, 0)
}

StopRemovesSeveralThreads() {
    inst := Instance("i1", "f1")
    t1 := inst.Start("t1", "trig")
    t2 := t1.Clone("t2")
    inst.AddThread(t2)
    ToRunning(t2)
    Assert.True(inst.Stop())
    Assert.Equal(inst.Threads.Count, 1)
    Assert.Equal(inst.Threads["t2"].State, "stopping")
    Assert.Equal(inst.State, "stopping")
}

ExpireEndsStoppingInstance() {
    rec := Recorder()
    inst := Instance("i1", "f1", rec.cb)
    t := inst.Start("t1", "trig")
    ToRunning(t)
    inst.Stop()
    Assert.True(inst.Expire())
    Assert.Equal(inst.State, "ended")
    Assert.Equal(inst.Threads.Count, 0)
    Assert.Equal(rec.rec.Length, 0)
}

ExpireOnlyFromStopping() {
    rec := Recorder()
    inst := Instance("i1", "f1", rec.cb)
    inst.Start("t1", "trig")
    Assert.Equal(inst.Expire(), false)
    Assert.Equal(inst.State, "running")
    Assert.Equal(rec.rec.Length, 1)
}

EndedInstanceIgnoresEverything() {
    rec := Recorder()
    inst := Instance("i1", "f1", rec.cb)
    inst.Start("t1", "trig")
    inst.Stop()
    Assert.Equal(inst.State, "ended")
    Assert.Equal(inst.Stop(), false)
    Assert.Equal(inst.Expire(), false)
    Assert.Equal(inst.Start("t2", "trig"), "")
    Assert.Equal(rec.rec.Length, 3)
}

AddThreadRejectsForeignInstance() {
    inst := Instance("i1", "f1")
    inst.Start("t1", "trig")
    foreign := ThreadState("t9", "other", "e1")
    err := Assert.Throws(AddForeignThread.Bind(inst, foreign), AhfError)
    Assert.Equal(err.code, "internal")
}

AddForeignThread(inst, thread) {
    inst.AddThread(thread)
}

; wait policy (E0002): an instance is queued (new -> waiting), started later, or stopped while it waits.
WaitingInstanceStartsLater() {
    inst := Instance("i1", "f1")
    Assert.True(inst.Wait(), "queue")
    Assert.Equal(inst.State, "waiting")
    thread := inst.Start("t1", "trig")
    Assert.Equal(inst.State, "running")
    Assert.Equal(thread.State, "finished")
}

WaitingInstanceEndsOnStop() {
    inst := Instance("i1", "f1")
    inst.Wait()
    Assert.True(inst.Stop("flow.stop"))
    Assert.Equal(inst.State, "ended")
    Assert.Equal(inst.Threads.Count, 0)
}

RunningInstanceCannotWait() {
    rec := Recorder()
    inst := Instance("i1", "f1", rec.cb)
    inst.Start("t1", "trig")
    Assert.Equal(inst.Wait(), false)
    Assert.Equal(inst.State, "running")
    Assert.Equal(rec.rec.Length, 1)
}

TestRun.Init()

TestRun.Case("ThreadState: every pair of states matches the table of ARCHITECTURE 5.2", ThreadTableMatches)
TestRun.Case("Instance: every pair of states matches the table of ARCHITECTURE 5.1", InstanceTableMatches)
TestRun.Case("Thread: late Finish is ignored without an invalid report", LateFinishIsIgnored)
TestRun.Case("Thread: Finish stores result and message after running", FinishStoresResult)
TestRun.Case("Thread: Clone copies state and deep-copies the loop stack", CloneIsDeep)
TestRun.Case("Thread: invalid transition without callback goes to the a0 log", InvalidWithoutCallbackGoesToA0Log)
TestRun.Case("Thread: a throwing callback is logged, not raised", ThrowingCallbackIsLoggedNotRaised)
TestRun.Case("Thread: unknown start state is rejected with bad_args", UnknownThreadStateIsRejected)
TestRun.Case("Instance: Start creates a finished trigger thread with result Normal", StartCreatesFinishedTriggerThread)
TestRun.Case("Instance: a second Start is rejected and reported", StartTwiceIsRejected)
TestRun.Case("Instance: releasing the last thread ends a running instance", LastThreadReleasedEndsRunningInstance)
TestRun.Case("Instance: a running thread cannot be released, only stopped", ReleaseNeedsRemovableThread)
TestRun.Case("Instance: Stop with a running thread waits for the acknowledgement", StopWithRunningThreadWaitsForAcknowledgement)
TestRun.Case("Instance: Stop with only a ready thread ends at once", StopWithReadyThreadEndsAtOnce)
TestRun.Case("Instance: Stop removes ready threads and marks running ones", StopRemovesSeveralThreads)
TestRun.Case("Instance: Expire ends a stopping instance and drops its threads", ExpireEndsStoppingInstance)
TestRun.Case("Instance: Expire is only allowed from stopping", ExpireOnlyFromStopping)
TestRun.Case("Instance: an ended instance rejects Stop, Expire and Start", EndedInstanceIgnoresEverything)
TestRun.Case("Instance: AddThread rejects a thread of another instance", AddThreadRejectsForeignInstance)
TestRun.Case("Instance: a queued instance starts later (new -> waiting -> running)", WaitingInstanceStartsLater)
TestRun.Case("Instance: a waiting instance ends on Stop without threads", WaitingInstanceEndsOnStop)
TestRun.Case("Instance: a running instance cannot be queued", RunningInstanceCannotWait)

TestRun.Finish()
