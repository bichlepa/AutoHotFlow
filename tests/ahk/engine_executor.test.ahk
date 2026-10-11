#Requires AutoHotkey v2.0
; Unit tests for src/engine/Executor.ahk (WI-21): re-entrant ticks
; and the job bookkeeping of worker elements.
; Executor runs against EngineOwner (helpers/), a stand-in for Engine that records the events.
#Include helpers\ExecutorKit.ahk

; --- re-entrant Tick (point 2) ---------------------------------------------------------------------

; A worker element is checked in Tick (ready?) and started after workers.Usable(). A tick that interrupts
; there starts the thread; the outer tick must not start it a second time.
InterruptedTickStartsAnElementOnce() {
    owner := NewOwner(FlowText([El("w", "Test_Wk")], [Conn("c1", "t0", "w")]))
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.workers.hook := () => owner.executor.Tick()
    owner.Drive()
    Assert.Equal(owner.workers.runs, 1, "worker jobs started")
}

; An element whose Run calls Tick again: every element runs exactly once, none is lost.
TickInsideRunStartsEveryElementOnce() {
    owner := NewOwner(FlowText([El("a", "Test_Count"), El("b", "Test_Count"), El("c", "Test_Count")]
        , [Conn("c1", "t0", "a"), Conn("c2", "a", "b"), Conn("c3", "a", "c")]))
    Probe.onRun := (ctx) => owner.executor.Tick()
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Assert.Equal(Probe.Count("a"), 1)
    Assert.Equal(Probe.Count("b"), 1)
    Assert.Equal(Probe.Count("c"), 1)
    Assert.Equal(owner.executor.IsExecuting("f"), false)
}

; --- worker job bookkeeping (point 5) ---------------------------------------------------------------

; WorkerBridge.Run can end a job at once (send error) and still return its execId. The thread has moved on,
; so no "active" entry may be left behind for it.
WorkerJobEndedAtOnceLeavesNoActiveEntry() {
    owner := NewOwner(FlowText([El("h", "Test_Hold"), El("w", "Test_Wk")]
        , [Conn("c1", "t0", "h"), Conn("c2", "t0", "w")]))
    owner.workers.failAtOnce := true
    instId := owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    run := owner.executor._runs[instId]    ; the instance lives on: the thread of "h" still runs
    Assert.Equal(run["active"].Count, 1, "only the thread of h is active")
    Assert.Equal(owner.workers.runs, 1)
}

TestRun.Init()

TestRun.Case("Tick: a tick that interrupts before the dispatch does not start an element twice", InterruptedTickStartsAnElementOnce)
TestRun.Case("Tick: an element that calls Tick in Run does not lose or repeat other elements", TickInsideRunStartsEveryElementOnce)
TestRun.Case("Worker: a job that ends at once leaves no active entry", WorkerJobEndedAtOnceLeavesNoActiveEntry)

TestRun.Finish()
