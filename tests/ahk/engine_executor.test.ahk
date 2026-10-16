#Requires AutoHotkey v2.0
; Unit tests for src/engine/Executor.ahk (WI-0021): re-entrant ticks
; and the job bookkeeping of worker elements.
; Executor runs against EngineOwner (helpers/), a stand-in for Engine that records the events.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include helpers\ExecutorKit.ahk

; --- re-entrant Tick (point 2) ---------------------------------------------------------------------

; A worker element is checked in Tick (ready?) and started after workers.Usable(). A tick that interrupts
; there starts the thread; the outer tick must not start it a second time.
InterruptedTickStartsAnElementOnce() {
    owner := NewOwner(FlowText([El("w", "ExecKit.Test_Wk")], [Conn("c1", "t0", "w")]))
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.workers.hook := () => owner.executor.Tick()
    owner.Drive()
    Assert.Equal(owner.workers.runs, 1, "worker jobs started")
}

; An element whose Run calls Tick again: every element runs exactly once, none is lost.
TickInsideRunStartsEveryElementOnce() {
    owner := NewOwner(FlowText([El("a", "ExecKit.Test_Count"), El("b", "ExecKit.Test_Count"), El("c", "ExecKit.Test_Count")]
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
    owner := NewOwner(FlowText([El("h", "ExecKit.Test_Hold"), El("w", "ExecKit.Test_Wk")]
        , [Conn("c1", "t0", "h"), Conn("c2", "t0", "w")]))
    owner.workers.failAtOnce := true
    instId := owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    runRec := owner.executor._runs[instId]    ; the instance lives on: the thread of "h" still runs
    Assert.Equal(runRec["active"].Count, 1, "only the thread of h is active")
    Assert.Equal(owner.workers.runs, 1)
}

; E0041: a worker element is sent to the pool; its Run never runs in the engine process (the engine has the class for the
; metadata only).
WorkerElementIsNeverRunInTheEngine() {
    owner := NewOwner(FlowText([El("w", "ExecKit.Test_Wk")], [Conn("c1", "t0", "w")]))
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Assert.Equal(owner.workers.runs, 1, "worker jobs started")
    Assert.Equal(Probe.Count("w"), 0, "Run of the worker element called in the engine")
}

; --- the active-thread map (F-0012) ----------------------------------------------------------------

; A spy for run["active"]: the first Delete runs the hook just before it takes the entry. The hook is the other path
; (a finish or a stop) that interrupts between the check and the take (F-0012).
class SpyActive extends Map {
    __New(hook) {
        super.__New()
        this.hook := hook
    }

    Delete(key) {
        if (IsObject(this.hook)) {
            hook := this.hook
            this.hook := ""
            hook()
        }
        return super.Delete(key)
    }
}

; Replaces run["active"] of the instance by a spy with the same entries.
ArmActive(owner, instId, hook) {
    runRec := owner.executor._runs[instId]
    spy := SpyActive(hook)
    for key, act in runRec["active"]
        spy[key] := act
    runRec["active"] := spy
}

; A stop that meets the finish of the thread it stops: the stop checks the thread's entry, the finish takes it in
; between. The stop must complete, end the instance and leave the element alone (it has finished).
AStopThatMeetsTheFinishOfItsThreadCompletes() {
    owner := NewOwner(FlowText([El("h", "ExecKit.Test_Hold")], [Conn("c1", "t0", "h")]))
    instId := owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Assert.Equal(Probe.Count("h"), 1, "the hold element runs")
    ArmActive(owner, instId, () => Probe.held["h"].Finish("normal"))
    err := ""
    try {
        owner.executor.StopFlow("f")
    } catch as e {
        err := e.Message
    }
    Assert.Equal(err, "", "the stop completes")
    Assert.Equal(owner.executor.IsExecuting("f"), false, "the instance has ended")
    Assert.Equal(Probe.stops.Length, 0, "the element finished before the stop could stop it")
}

; A finish that meets a stop of its thread: the finish checks the entry, the stop takes it in between. The finish
; must complete, the instance must end and the element must be stopped once.
AFinishThatMeetsAStopOfItsThreadCompletes() {
    owner := NewOwner(FlowText([El("h", "ExecKit.Test_Hold")], [Conn("c1", "t0", "h")]))
    instId := owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    ctx := Probe.held["h"]
    ArmActive(owner, instId, () => owner.executor.StopFlow("f"))
    err := ""
    try {
        ctx.Finish("normal")
    } catch as e {
        err := e.Message
    }
    Assert.Equal(err, "", "the finish completes")
    Assert.Equal(Probe.stops.Length, 1, "the element is stopped once")
    Assert.Equal(owner.executor.IsExecuting("f"), false, "the instance has ended")
}

TestRun.Init()

TestRun.Case("Tick: a tick that interrupts before the dispatch does not start an element twice", InterruptedTickStartsAnElementOnce)
TestRun.Case("Tick: an element that calls Tick in Run does not lose or repeat other elements", TickInsideRunStartsEveryElementOnce)
TestRun.Case("Worker: the engine never calls Run of a worker element (E0041)", WorkerElementIsNeverRunInTheEngine)
TestRun.Case("Worker: a job that ends at once leaves no active entry", WorkerJobEndedAtOnceLeavesNoActiveEntry)
TestRun.Case("Active: a stop that meets the finish of its thread completes (F-0012)", AStopThatMeetsTheFinishOfItsThreadCompletes)
TestRun.Case("Active: a finish that meets a stop of its thread completes (F-0012)", AFinishThatMeetsAStopOfItsThreadCompletes)

TestRun.Finish()
