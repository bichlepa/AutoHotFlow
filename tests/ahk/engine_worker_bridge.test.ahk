#Requires AutoHotkey v2.0
; Unit tests for the pool rules in src/engine/WorkerBridge.ahk (WI-27, ARCHITEKTUR 6.4): size limit, demand, warm
; workers, idle end, failures and the storm limit, cancel that is not confirmed, job deadline, orphans at the start.
; No process is started: the owner is a stand-in whose peer records every request. The tests answer them by hand.
; Timers run while Sleep() pumps messages.
#Include lib\Assert.ahk
#Include ..\..\src\engine\WorkerBridge.ahk

class FakeRes {
    __New(payload) {
        this.payload := payload
    }
}

class FakeMsg {
    __New(type, payload) {
        this.type := type
        this.payload := payload
    }
}

; Records the requests of the bridge. Answer(call, payload) calls the callback like the peer would.
class FakePeer {
    __New() {
        this.calls := []
    }

    Request(to, type, payload, cb, timeout := 0) {
        this.calls.Push(Map("to", to, "type", type, "payload", payload, "cb", cb, "answered", false))
    }

    ; The calls of one type that have not been answered yet.
    Open(type) {
        out := []
        for call in this.calls {
            if (call["type"] = type && !call["answered"])
                out.Push(call)
        }
        return out
    }

    Count(type) {
        n := 0
        for call in this.calls {
            if (call["type"] = type)
                n += 1
        }
        return n
    }

    ; "worker:1,worker:2": the addressees of all calls of this type.
    Targets(type) {
        out := ""
        for call in this.calls {
            if (call["type"] = type)
                out .= (out = "" ? "" : ",") call["to"]
        }
        return out
    }

    ; "worker:1,worker:2": the names of all calls of this type (field "name" of the payload).
    Names(type) {
        out := ""
        for call in this.calls {
            if (call["type"] = type)
                out .= (out = "" ? "" : ",") call["payload"].Get("name", "")
        }
        return out
    }

    Answer(call, payload) {
        call["answered"] := true
        cb := call["cb"]
        cb(FakeRes(payload))
    }
}

class FakeOwner {
    __New() {
        this.peer := FakePeer()
        this.kicks := 0
    }

    Kick() {
        this.kicks += 1
    }
}

Ids.Configure("test")
Log.Configure(Log.Memory)
Log.memoryLines := []

; A bridge whose start is done: the process list was answered with `processes`.
NewPool(size, warm := 1, idleMs := 60000, processes := "") {
    owner := FakeOwner()
    bridge := WorkerBridge(owner, size, warm, idleMs)
    bridge.Start()
    owner.peer.Answer(owner.peer.Open("cmd.process.list")[1], Map("ok", true, "processes", IsObject(processes) ? processes : []))
    return [owner, bridge]
}

; Answers the open spawn requests with worker:<first>, worker:<first+1>, ... and reports them ready.
SpawnReady(owner, bridge, first := 1) {
    n := first
    for call in owner.peer.Open("cmd.process.spawn") {
        name := "worker:" n
        owner.peer.Answer(call, Map("ok", true, "name", name))
        bridge.OnProcessEvent(FakeMsg("evt.process.ready", Map("name", name, "pid", 1000 + n)))
        n += 1
    }
    return n
}

Noop(*) {
}

; --- start and orphans ------------------------------------------------------------------------------------

StartAsksForTheProcessListFirstAndDoesNotGrowBeforeTheAnswer() {
    owner := FakeOwner()
    bridge := WorkerBridge(owner, 4, 1, 60000)
    bridge.Start()
    Assert.Equal(owner.peer.Count("cmd.process.list"), 1)
    bridge.Want(3)
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 0, "no spawn before the orphans are gone")
    Assert.True(bridge.Usable(), "a pool that is starting is usable")
    Assert.Equal(bridge.Free(), false)
}

OrphansOfAnEarlierEngineAreKilledAndTheWarmWorkerIsAskedForAfterwards() {
    procs := [Map("name", "worker:3", "state", "ready"), Map("name", "worker:4", "state", "starting")
        , Map("name", "worker:2", "state", "exited"), Map("name", "worker:1", "state", "crashed")
        , Map("name", "storage", "state", "ready"), Map("name", "engine", "state", "ready")]
    r := NewPool(4, 1, 60000, procs)
    owner := r[1]
    Assert.Equal(owner.peer.Names("cmd.process.kill"), "worker:3,worker:4", "only living workers, no other role")
    Assert.Equal(owner.peer.Open("cmd.process.kill")[1]["payload"]["reason"], "orphan of a previous engine")
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 1, "one warm worker")
}

FailedProcessListStillStartsThePool() {
    owner := FakeOwner()
    bridge := WorkerBridge(owner, 2, 1, 60000)
    bridge.Start()
    owner.peer.Answer(owner.peer.Open("cmd.process.list")[1], Map("ok", false, "error", Map("code", "timeout", "message", "x")))
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 1)
}

NoPoolIsNeverUsable() {
    owner := FakeOwner()
    bridge := WorkerBridge(owner, 0, 0, 60000)
    bridge.Start()
    Assert.Equal(owner.peer.Count("cmd.process.list"), 0)
    Assert.Equal(bridge.Usable(), false)
    bridge.Want(2)
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 0)
}

; --- size limit and demand -----------------------------------------------------------------------------------

WantNeverGoesAboveTheLimit() {
    r := NewPool(2, 0)
    owner := r[1]
    bridge := r[2]
    bridge.Want(5)
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 2, "the limit is 2 even if 5 threads wait")
    bridge.Want(5)
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 2, "requests on their way count")
    SpawnReady(owner, bridge)
    bridge.Want(5)
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 2, "slots count")
    Assert.Equal(bridge.Count, 2)
}

WantCountsTheWorkersThatAreAlreadyStarting() {
    r := NewPool(4, 0)
    owner := r[1]
    bridge := r[2]
    bridge.Want(1)
    bridge.Want(1)
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 1, "one waiting thread, one starting worker")
    bridge.Want(3)
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 3, "three waiting, one on its way: two more")
    owner.peer.Answer(owner.peer.Open("cmd.process.spawn")[1], Map("ok", true, "name", "worker:1"))
    bridge.Want(3)
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 3, "an answered request is a starting slot")
    bridge.Want(1)
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 3, "fewer waiting than starting (negative need) asks for nothing")
}

ReadyEventBeforeTheSpawnAnswerStillMakesTheSlotIdle() {
    r := NewPool(2, 0)
    owner := r[1]
    bridge := r[2]
    bridge.Want(1)
    bridge.OnProcessEvent(FakeMsg("evt.process.ready", Map("name", "worker:9", "pid", 1)))
    Assert.Equal(bridge.Free(), false)
    owner.peer.Answer(owner.peer.Open("cmd.process.spawn")[1], Map("ok", true, "name", "worker:9"))
    Assert.Equal(bridge.Free(), true)
}

RunUsesTheMostRecentlyIdleWorkerSoTheOthersCanIdleOut() {
    r := NewPool(3, 0)
    owner := r[1]
    bridge := r[2]
    bridge.Want(3)
    SpawnReady(owner, bridge)
    ; worker:3 became idle last
    bridge.Run("Action_X", Map(), Map(), Map(), Noop)
    bridge.Run("Action_X", Map(), Map(), Map(), Noop)
    Assert.Equal(owner.peer.Targets("cmd.worker.run"), "worker:3,worker:2")
}

RunHandsOutOnlyIdleSlots() {
    r := NewPool(1, 0)
    owner := r[1]
    bridge := r[2]
    Assert.Equal(bridge.Run("Action_X", Map(), Map(), Map(), Noop), "", "no worker yet")
    bridge.Want(1)
    SpawnReady(owner, bridge)
    first := bridge.Run("Action_X", Map(), Map(), Map(), Noop)
    Assert.True(first != "")
    Assert.Equal(bridge.Free(), false)
    Assert.Equal(bridge.Run("Action_X", Map(), Map(), Map(), Noop), "", "the only worker is busy")
}

; --- idle end ----------------------------------------------------------------------------------------------------

IdleWorkersBeyondTheWarmOnesAreKilledAfterTheIdleTime() {
    r := NewPool(3, 1, 150)
    owner := r[1]
    bridge := r[2]
    SpawnReady(owner, bridge)               ; the warm worker
    bridge.Want(3)
    SpawnReady(owner, bridge, 2)            ; two more
    Assert.Equal(bridge.Count, 3)
    Assert.Equal(owner.peer.Count("cmd.process.kill"), 0)
    Sleep(500)
    Assert.Equal(owner.peer.Count("cmd.process.kill"), 2, "two killed, the warm one stays")
    Assert.Equal(bridge.Count, 1)
    Assert.Equal(owner.peer.Open("cmd.process.kill")[1]["payload"]["reason"], "idle")
    Sleep(400)
    Assert.Equal(owner.peer.Count("cmd.process.kill"), 2, "the warm worker is never ended")
    Assert.Equal(bridge.Free(), true)
}

ABusyWorkerIsNotEndedAsIdle() {
    r := NewPool(2, 0, 150)
    owner := r[1]
    bridge := r[2]
    bridge.Want(2)
    SpawnReady(owner, bridge)
    bridge.Run("Action_X", Map(), Map(), Map(), Noop)
    Sleep(500)
    Assert.Equal(owner.peer.Count("cmd.process.kill"), 1, "only the idle one")
    Assert.Equal(bridge.Count, 1)
}

; --- crash, failures, storm ----------------------------------------------------------------------------------------

CrashOfABusyWorkerEndsItsJobAndTheWarmWorkerIsAskedForAgain() {
    r := NewPool(2, 1)
    owner := r[1]
    bridge := r[2]
    SpawnReady(owner, bridge)
    got := Map("result", "", "message", "")
    onDone := (result, message, exports) => (got["result"] := result, got["message"] := message)
    bridge.Run("Action_X", Map(), Map(), Map(), onDone)
    bridge.OnProcessEvent(FakeMsg("evt.process.crashed", Map("name", "worker:1", "pid", 1001)))
    Assert.Equal(got["result"], "exception")
    Assert.Equal(got["message"], "worker crashed (worker:1)")
    Assert.Equal(bridge.Count, 0)
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 2, "a replacement for the warm worker")
}

ARunThatTheWorkerRefusesRemovesAndKillsItAndEndsTheJob() {
    r := NewPool(2, 0)
    owner := r[1]
    bridge := r[2]
    bridge.Want(1)
    SpawnReady(owner, bridge)
    got := Map("result", "", "message", "")
    onDone := (result, message, exports) => (got["result"] := result, got["message"] := message)
    bridge.Run("Action_X", Map(), Map(), Map(), onDone)
    owner.peer.Answer(owner.peer.Open("cmd.worker.run")[1], Map("ok", false, "error", Map("code", "busy", "message", "x")))
    Assert.Equal(got["result"], "exception")
    Assert.Equal(got["message"], "worker not available: worker:1 (busy)")
    Assert.Equal(bridge.Count, 0)
    Assert.Equal(owner.peer.Names("cmd.process.kill"), "worker:1")
}

FiveFailuresBlockThePoolAndWithoutAWorkerItIsNotUsable() {
    r := NewPool(2, 1)
    owner := r[1]
    bridge := r[2]
    loop 5 {
        ; the warm worker is asked for, started, and crashes
        SpawnReady(owner, bridge, A_Index)
        name := "worker:" A_Index
        bridge.OnProcessEvent(FakeMsg("evt.process.crashed", Map("name", name, "pid", 1)))
    }
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 5, "no sixth start after the fifth failure")
    Assert.Equal(bridge.Count, 0)
    Assert.Equal(bridge.Usable(), false, "blocked and no worker: jobs end with worker not available")
    bridge.Want(3)
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 5)
}

AnEndThatTheEngineCausedItselfIsNoFailure() {
    r := NewPool(2, 0, 100)
    owner := r[1]
    bridge := r[2]
    loop 6 {
        bridge.Want(1)
        SpawnReady(owner, bridge, A_Index)
        ; the engine kills it (idle end after Sleep), the supervisor reports the planned exit
        Sleep(200)
        bridge.OnProcessEvent(FakeMsg("evt.process.exited", Map("name", "worker:" A_Index, "pid", 1)))
    }
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 6, "growing and shrinking does not make a storm")
    Assert.Equal(bridge.Usable(), true)
}

FailedSpawnRequestsAreCountedToo() {
    r := NewPool(2, 0)
    owner := r[1]
    bridge := r[2]
    loop 5 {
        bridge.Want(1)
        owner.peer.Answer(owner.peer.Open("cmd.process.spawn")[1], Map("ok", false, "error", Map("code", "shutting_down", "message", "x")))
    }
    bridge.Want(1)
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 5)
    Assert.Equal(bridge.Usable(), false)
}

; --- cancel and deadline --------------------------------------------------------------------------------------------

CancelThatIsConfirmedKeepsTheWorker() {
    saved := WorkerBridge.ORPHAN_MS
    WorkerBridge.ORPHAN_MS := 150
    try {
        r := NewPool(2, 0)
        owner := r[1]
        bridge := r[2]
        bridge.Want(1)
        SpawnReady(owner, bridge)
        execId := bridge.Run("Action_X", Map(), Map(), Map(), Noop)
        Assert.True(bridge.Cancel(execId))
        Assert.Equal(owner.peer.Count("cmd.worker.cancel"), 1)
        bridge.OnDone(FakeMsg("evt.worker.done", Map("execId", execId, "result", "stopped", "message", "", "exports", Map())))
        Sleep(400)
        Assert.Equal(owner.peer.Count("cmd.process.kill"), 0)
        Assert.Equal(bridge.Free(), true)
    } finally {
        WorkerBridge.ORPHAN_MS := saved
    }
}

CancelThatIsNotConfirmedKillsTheWorkerAfterTheOrphanTime() {
    saved := WorkerBridge.ORPHAN_MS
    WorkerBridge.ORPHAN_MS := 150
    try {
        r := NewPool(2, 0)
        owner := r[1]
        bridge := r[2]
        bridge.Want(1)
        SpawnReady(owner, bridge)
        execId := bridge.Run("Action_X", Map(), Map(), Map(), Noop)
        bridge.Cancel(execId)
        Assert.Equal(owner.peer.Count("cmd.process.kill"), 0)
        Sleep(400)
        Assert.Equal(owner.peer.Names("cmd.process.kill"), "worker:1")
        Assert.Equal(owner.peer.Open("cmd.process.kill")[1]["payload"]["reason"], "cancel not confirmed")
        Assert.Equal(bridge.Count, 0, "the slot is gone")
    } finally {
        WorkerBridge.ORPHAN_MS := saved
    }
}

JobDeadlineEndsTheJobAtOnceAndCancelsThenKills() {
    saved := WorkerBridge.ORPHAN_MS
    WorkerBridge.ORPHAN_MS := 150
    try {
        r := NewPool(2, 0)
        owner := r[1]
        bridge := r[2]
        bridge.Want(1)
        SpawnReady(owner, bridge)
        got := Map("result", "", "message", "", "calls", 0)
        onDone := (result, message, exports) => (got["result"] := result, got["message"] := message, got["calls"] += 1)
        bridge.Run("Action_X", Map(), Map(), Map(), onDone, 120)
        Assert.Equal(got["calls"], 0)
        Sleep(250)
        Assert.Equal(got["result"], "exception")
        Assert.Equal(got["message"], "worker timeout")
        Assert.Equal(owner.peer.Count("cmd.worker.cancel"), 1, "the worker is asked to stop")
        Sleep(400)
        Assert.Equal(owner.peer.Names("cmd.process.kill"), "worker:1", "it did not confirm: killed")
        Assert.Equal(got["calls"], 1, "the job ends once")
    } finally {
        WorkerBridge.ORPHAN_MS := saved
    }
}

JobThatEndsBeforeItsDeadlineIsNotTimedOut() {
    r := NewPool(2, 0)
    owner := r[1]
    bridge := r[2]
    bridge.Want(1)
    SpawnReady(owner, bridge)
    got := Map("result", "", "calls", 0)
    onDone := (result, message, exports) => (got["result"] := result, got["calls"] += 1)
    execId := bridge.Run("Action_X", Map(), Map(), Map(), onDone, 150)
    bridge.OnDone(FakeMsg("evt.worker.done", Map("execId", execId, "result", "normal", "message", "", "exports", Map())))
    Sleep(350)
    Assert.Equal(got["result"], "normal")
    Assert.Equal(got["calls"], 1)
    Assert.Equal(owner.peer.Count("cmd.worker.cancel"), 0)
}

StoppedPoolAsksForNothing() {
    r := NewPool(2, 1)
    owner := r[1]
    bridge := r[2]
    bridge.Stop()
    bridge.Want(2)
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 1, "only the warm worker of the start")
    bridge.OnProcessEvent(FakeMsg("evt.process.crashed", Map("name", "worker:1", "pid", 1)))
    Assert.Equal(owner.peer.Count("cmd.process.spawn"), 1)
    Assert.Equal(bridge.Usable(), false)
}

TestRun.Init()

TestRun.Case("Pool: the start asks for the process list first and does not grow before the answer", StartAsksForTheProcessListFirstAndDoesNotGrowBeforeTheAnswer)
TestRun.Case("Pool: workers of an earlier engine are killed, then the warm worker is asked for", OrphansOfAnEarlierEngineAreKilledAndTheWarmWorkerIsAskedForAfterwards)
TestRun.Case("Pool: a failed process list still starts the pool", FailedProcessListStillStartsThePool)
TestRun.Case("Pool: size 0 is never usable and asks for nothing", NoPoolIsNeverUsable)
TestRun.Case("Pool: demand never goes above the limit", WantNeverGoesAboveTheLimit)
TestRun.Case("Pool: demand counts workers that are already starting", WantCountsTheWorkersThatAreAlreadyStarting)
TestRun.Case("Pool: ready before the spawn answer still gives an idle slot", ReadyEventBeforeTheSpawnAnswerStillMakesTheSlotIdle)
TestRun.Case("Pool: Run takes the most recently idle worker", RunUsesTheMostRecentlyIdleWorkerSoTheOthersCanIdleOut)
TestRun.Case("Pool: Run hands out idle slots only", RunHandsOutOnlyIdleSlots)
TestRun.Case("Pool: idle workers beyond the warm ones are killed after the idle time", IdleWorkersBeyondTheWarmOnesAreKilledAfterTheIdleTime)
TestRun.Case("Pool: a busy worker is not ended as idle", ABusyWorkerIsNotEndedAsIdle)
TestRun.Case("Pool: crash of a busy worker ends its job, the warm worker is asked for again", CrashOfABusyWorkerEndsItsJobAndTheWarmWorkerIsAskedForAgain)
TestRun.Case("Pool: a refused run removes and kills the worker and ends the job", ARunThatTheWorkerRefusesRemovesAndKillsItAndEndsTheJob)
TestRun.Case("Pool: five failures block the pool", FiveFailuresBlockThePoolAndWithoutAWorkerItIsNotUsable)
TestRun.Case("Pool: ends caused by the engine are no failures", AnEndThatTheEngineCausedItselfIsNoFailure)
TestRun.Case("Pool: refused spawn requests are failures", FailedSpawnRequestsAreCountedToo)
TestRun.Case("Pool: a confirmed cancel keeps the worker", CancelThatIsConfirmedKeepsTheWorker)
TestRun.Case("Pool: an unconfirmed cancel kills the worker after the orphan time", CancelThatIsNotConfirmedKillsTheWorkerAfterTheOrphanTime)
TestRun.Case("Pool: the job deadline ends the job, cancels and kills", JobDeadlineEndsTheJobAtOnceAndCancelsThenKills)
TestRun.Case("Pool: a job that ends in time is not timed out", JobThatEndsBeforeItsDeadlineIsNotTimedOut)
TestRun.Case("Pool: a stopped pool asks for nothing", StoppedPoolAsksForNothing)

TestRun.Finish()
