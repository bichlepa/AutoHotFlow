#Requires AutoHotkey v2.0
; Unit tests for src/engine/Executor.ahk (WI-0021): the newest committed revision is used at every step
; (ARCHITECTURE 4.2, E0001). Executor runs against EngineOwner (helpers/), which records the events.
#Include helpers\ExecutorKit.ahk

; --- newest revision (point 3) ---------------------------------------------------------------------

HoldFlow() {
    return FlowText([El("h", "ExecKit.Test_Hold", '{"x":1}'), El("b", "ExecKit.Test_Count"), El("c", "ExecKit.Test_Count")]
        , [Conn("c1", "t0", "h"), Conn("c2", "h", "b")])
}

NextConnectionComesFromTheNewestRevision() {
    owner := NewOwner(HoldFlow())
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Assert.True(Probe.held.Has("h"), "h is running")
    Commit(owner, FlowText([El("h", "ExecKit.Test_Hold", '{"x":1}'), El("b", "ExecKit.Test_Count"), El("c", "ExecKit.Test_Count")]
        , [Conn("c1", "t0", "h"), Conn("c3", "h", "c")]))
    Probe.Release("h")
    owner.Drive()
    Assert.Equal(Probe.Count("b"), 0, "old connection not taken")
    Assert.Equal(Probe.Count("c"), 1, "new connection taken")
}

RunningElementKeepsItsParametersForStop() {
    owner := NewOwner(HoldFlow())
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Commit(owner, FlowText([El("h", "ExecKit.Test_Hold", '{"x":2}'), El("b", "ExecKit.Test_Count")]
        , [Conn("c1", "t0", "h"), Conn("c2", "h", "b")]))
    owner.executor.StopFlow("f")
    Assert.Equal(Probe.stops.Length, 1)
    Assert.Equal(Probe.stops[1], "h:1", "Stop gets the parameters of the start")
}

RunningElementDeletedRunsToTheEnd() {
    owner := NewOwner(HoldFlow())
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Commit(owner, FlowText([El("b", "ExecKit.Test_Count")], [Conn("c1", "t0", "b")]))   ; h and its connection are gone
    Probe.Release("h")
    owner.Drive()
    Assert.Equal(Probe.Count("b"), 0, "no connection from a deleted element")
    Assert.Equal(owner.executor.IsExecuting("f"), false)
    Assert.Equal(owner.ElementStates("h"), "running finished")
}

ReadyThreadWhoseElementWasDeletedEndsWithException() {
    owner := NewOwner(FlowText([El("w", "ExecKit.Test_Wk")], [Conn("c1", "t0", "w")]))
    owner.workers.hasFree := false              ; the thread waits in state ready
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Commit(owner, FlowText([El("b", "ExecKit.Test_Count")], [Conn("c1", "t0", "b")]))   ; w is gone
    owner.workers.hasFree := true
    owner.Drive()
    Assert.Equal(owner.workers.runs, 0, "the removed element is not started")
    Assert.Equal(owner.executor.IsExecuting("f"), false)
    Assert.True(InStr(owner.ElementStates("w"), "exception"), "w reports an exception: " owner.ElementStates("w"))
    Assert.True(HasLog("f1", "was removed"), "f1 log line")
}

ReadyThreadStartsWithTheClassOfTheNewestRevision() {
    owner := NewOwner(FlowText([El("w", "ExecKit.Test_Wk")], [Conn("c1", "t0", "w")]))
    owner.workers.hasFree := false
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Commit(owner, FlowText([El("w", "ExecKit.Test_Count")], [Conn("c1", "t0", "w")]))   ; same ID, other class
    owner.Drive()
    Assert.Equal(owner.workers.runs, 0)
    Assert.Equal(Probe.Count("w"), 1)
}

DeletedFlowStopsItsInstances() {
    owner := NewOwner(HoldFlow())
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Assert.Equal(owner.executor.FlowDeleted("f"), 2)
    Assert.Equal(owner.executor.IsExecuting("f"), false)
    Assert.Equal(owner.LastEndReason(), "flow.deleted")
}

; The flow vanishes from the table while an element runs (no stop yet): the next step stops the instance.
VanishedFlowStopsTheInstanceAtTheNextStep() {
    owner := NewOwner(HoldFlow())
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    owner.flows.Remove("f")
    Probe.Release("h")
    owner.Drive()
    Assert.Equal(Probe.Count("b"), 0)
    Assert.Equal(owner.executor.IsExecuting("f"), false)
    Assert.Equal(owner.LastEndReason(), "flow.deleted")
}

TestRun.Init()

TestRun.Case("Revision: the next connection comes from the newest revision", NextConnectionComesFromTheNewestRevision)
TestRun.Case("Revision: a running element keeps its parameters for Stop", RunningElementKeepsItsParametersForStop)
TestRun.Case("Revision: a running element that was deleted runs to the end and the thread ends", RunningElementDeletedRunsToTheEnd)
TestRun.Case("Revision: a ready thread whose element was deleted ends with exception", ReadyThreadWhoseElementWasDeletedEndsWithException)
TestRun.Case("Revision: a ready thread starts with the class of the newest revision", ReadyThreadStartsWithTheClassOfTheNewestRevision)
TestRun.Case("Revision: FlowDeleted ends all instances with the reason flow.deleted", DeletedFlowStopsItsInstances)
TestRun.Case("Revision: a flow that vanished from the table stops the instance at the next step", VanishedFlowStopsTheInstanceAtTheNextStep)

TestRun.Finish()
