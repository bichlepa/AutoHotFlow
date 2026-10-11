#Requires AutoHotkey v2.0
; Unit tests for the execution policy "wait" in src/engine/Executor.ahk (WI-21, ARCHITEKTUR 5.1, E2, M-11).
#Include helpers\ExecutorKit.ahk

WaitFlow() {
    return FlowText([El("h", "Test_Hold")], [Conn("c1", "t0", "h")], "wait")
}

; Starts three instances of the wait flow; returns [owner, [id1, id2, id3]].
StartThree() {
    owner := NewOwner(WaitFlow())
    rec := owner.flows.Get("f")
    ids := [owner.executor.StartFlow(rec)]
    owner.Drive()
    ids.Push(owner.executor.StartFlow(rec))
    ids.Push(owner.executor.StartFlow(rec))
    owner.Drive()
    return [owner, ids]
}

WaitQueuesTheSecondAndThirdInstance() {
    r := StartThree()
    owner := r[1]
    ids := r[2]
    Assert.Equal(owner.executor.IsWaiting(ids[1]), false)
    Assert.Equal(owner.executor.IsWaiting(ids[2]), true)
    Assert.Equal(owner.executor.IsWaiting(ids[3]), true)
    Assert.Equal(owner.InstanceLog(ids), "started:1,queued:2,queued:3")
    Assert.Equal(Probe.Count("h"), 1, "only the first instance runs")
    Assert.Equal(owner.executor.IsExecuting("f"), true)
}

WaitRunsTheInstancesOneAfterTheOther() {
    r := StartThree()
    owner := r[1]
    ids := r[2]
    Probe.Release("h")
    owner.Drive()
    Assert.Equal(Probe.Count("h"), 2, "second instance started")
    Assert.Equal(owner.executor.IsWaiting(ids[2]), false)
    Assert.Equal(owner.executor.IsWaiting(ids[3]), true)
    Probe.Release("h")
    owner.Drive()
    Assert.Equal(Probe.Count("h"), 3)
    Probe.Release("h")
    owner.Drive()
    Assert.Equal(owner.executor.IsExecuting("f"), false)
    Assert.Equal(owner.InstanceLog(ids)
        , "started:1,queued:2,queued:3,ended:1,started:2,ended:2,started:3,ended:3")
}

WaitStopEndsRunningAndWaitingInstances() {
    r := StartThree()
    owner := r[1]
    ids := r[2]
    Assert.Equal(owner.executor.StopFlow("f", "flow.stop"), 3)
    Assert.Equal(owner.executor.IsExecuting("f"), false)
    Assert.Equal(Probe.Count("h"), 1, "no waiting instance was started by the stop")
    Assert.Equal(owner.InstanceLog(ids), "started:1,queued:2,queued:3,ended:2,ended:3,ended:1")
}

; A queued instance that is stopped alone leaves the queue; the next one runs after the first.
WaitStoppedWaitingInstanceIsSkipped() {
    r := StartThree()
    owner := r[1]
    ids := r[2]
    Assert.Equal(owner.executor.StopInstance(ids[2], "test"), true)
    Probe.Release("h")
    owner.Drive()
    Assert.Equal(owner.executor.IsWaiting(ids[3]), false)
    Assert.Equal(Probe.Count("h"), 2)
}

; With the policy parallel nothing waits.
ParallelDoesNotQueue() {
    owner := NewOwner(FlowText([El("h", "Test_Hold")], [Conn("c1", "t0", "h")], "parallel"))
    rec := owner.flows.Get("f")
    owner.executor.StartFlow(rec)
    b := owner.executor.StartFlow(rec)
    owner.Drive()
    Assert.Equal(owner.executor.IsWaiting(b), false)
    Assert.Equal(Probe.Count("h"), 2)
}

; The trigger of a waiting instance vanished before its turn: the instance ends without having started.
WaitingInstanceWithVanishedTriggerEndsWithoutStart() {
    r := StartThree()
    owner := r[1]
    ids := r[2]
    ; the first instance keeps running; the new revision has no trigger any more
    Commit(owner, FlowText([El("h", "Test_Hold")], [], "wait", false))
    Probe.Release("h")
    owner.Drive()
    Assert.Equal(owner.executor.IsExecuting("f"), false)
    Assert.Equal(owner.InstanceLog(ids), "started:1,queued:2,queued:3,ended:1,ended:2,ended:3")
    Assert.True(HasLog("f1", "trigger"), "f1 log line")
}

TestRun.Init()

TestRun.Case("Wait: the second and third start are queued, only the first runs", WaitQueuesTheSecondAndThirdInstance)
TestRun.Case("Wait: the queued instances run one after the other in order", WaitRunsTheInstancesOneAfterTheOther)
TestRun.Case("Wait: stop ends the running and the waiting instances without starting any", WaitStopEndsRunningAndWaitingInstances)
TestRun.Case("Wait: a stopped waiting instance leaves the queue", WaitStoppedWaitingInstanceIsSkipped)
TestRun.Case("Wait: the policy parallel does not queue", ParallelDoesNotQueue)
TestRun.Case("Wait: a waiting instance whose trigger vanished ends without starting", WaitingInstanceWithVanishedTriggerEndsWithoutStart)

TestRun.Finish()
