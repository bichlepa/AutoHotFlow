#Requires AutoHotkey v2.0
; Unit tests for the order of work in Supervisor._Tick and the heartbeat rules (WI-0022, F-0005, F-0010,
; doc/ARCHITECTURE.md 6.2). No process of the roles is started: Children works on hand-made records,
; the hub is a fake whose Pump() delivers what "has already arrived".
#Include lib\Assert.ahk
#Include ..\..\src\supervisor\Supervisor.ahk

; Stands in for Hub and Heartbeat/Shutdown collaborators. pending holds the messages that lie in the
; pipes but have not been read yet; Pump() hands them over. links holds the names whose connection has not been
; read to its end yet (Hub.HasLink). pumping simulates a pump that another thread runs at the moment (the timer
; interrupted it): like PipeConnection.Pump, a second Pump then only marks "pump again" and returns (WI-0030).
class FakeHub {
    __New() {
        this.pending := []
        this.events := []
        this.sent := []
        this.pumps := 0
        this.links := Map()
        this.pumping := false
        this.pumpAgain := false
        this.shifted := 0
        this.offline := Map()       ; names that are not connected: Send returns false and sends nothing (like Hub)
    }
    LinkNames() => []
    Shift(ms) {
        this.shifted += ms
    }
    HasLink(name) => this.links.Has(name)
    Pump() {
        this.pumps += 1
        if (this.pumping) {
            this.pumpAgain := true
            return
        }
        list := this.pending
        this.pending := []
        for fn in list
            fn.Call()
    }
    Tick(now) {
    }
    Publish(topic, type, payload) {
        this.events.Push(Map("type", type, "payload", payload))
    }
    Send(to, type, payload) {
        if (this.offline.Has(to))
            return false
        this.sent.Push(Map("to", to, "type", type, "payload", payload))
        return true
    }
    SentCount(to, type) {
        n := 0
        for m in this.sent
            if (m["to"] = to && m["type"] = type)
                n += 1
        return n
    }
    LastSent(to, type) {
        found := ""
        for m in this.sent
            if (m["to"] = to && m["type"] = type)
                found := m
        return found
    }
    Count(type) {
        n := 0
        for ev in this.events
            if (ev["type"] = type)
                n += 1
        return n
    }
    Find(type) {
        for ev in this.events
            if (ev["type"] = type)
                return ev
        return ""
    }
}

class NoopTicker {
    shifted := 0
    Tick(now) {
    }
    Shift(ms) {
        this.shifted += ms
    }
}

; Stands in for DiagReport: only the stand-still hook.
class FakeReport {
    shifted := 0
    Shift(now, ms) {
        this.shifted += ms
    }
}

; An already ended process, so that WaitForSingleObject(handle, 0) is signalled at once.
EndedProcessHandle() {
    pid := 0
    Run(A_ComSpec ' /c exit 0', , "Hide", &pid)
    h := DllCall("OpenProcess", "uint", Children.OPEN_ACCESS, "int", 0, "uint", pid, "ptr")
    Loop 100 {
        if (DllCall("WaitForSingleObject", "ptr", h, "uint", 0, "uint") = 0)
            break
        Sleep(50)
    }
    return h
}

; A record in the state the supervisor has after sys.shutdown was sent, process ended, sys.bye not yet read.
AddChild(children, name, state, now) {
    rec := Map("name", name, "role", name, "flow", "", "state", state, "pid", 4242, "handle", EndedProcessHandle()
        , "gone", false, "exitCode", "", "startedAt", now, "readyAt", now, "lastPingAt", now, "pingN", 0
        , "lastPongAt", now, "bye", false, "byeClean", false, "restartTimes", [], "restartAt", 0
        , "killAt", 0, "restartable", false, "reader", "", "output", [])
    children._recs[name] := rec
    return rec
}

NewSupervisor(hub) {
    s := Supervisor(Map())
    s.hub := hub
    s.children := Children(Map("session", "t", "pipe", "p", "data", "d", "hubHwnd", 0, "testRoles", false
        , "script", "x", "roleOpts", ""), hub)
    s.heartbeat := NoopTicker()
    s.shutdown := NoopTicker()
    s.report := FakeReport()
    return s
}

TestRun.Init()

TestRun.Case("Tick: a sys.bye that is unread when the process end is seen is read first (F-0005, F-0010)", ByeIsReadBeforeTheExitIsReported)
TestRun.Case("Tick: an exit without any sys.bye is reported as not clean", ExitWithoutByeIsNotClean)
TestRun.Case("Tick: the hub is pumped at the start of every tick", HubIsPumpedEveryTick)
TestRun.Case("Tick: an exit is not judged while another pump still reads the connection of the child (F-0023, WI-0030)", ExitWaitsWhileAPumpRuns)
TestRun.Case("Children: an ended process whose connection does not end is judged after the grace time (WI-0030)", ExitIsJudgedAfterTheGraceTime)
TestRun.Case("Children: an ended child without a connection is judged at once (WI-0030)", ExitWithoutLinkIsJudgedAtOnce)
TestRun.Case("Children: an ended child that waits for its judgement is neither hung nor terminated (WI-0030)", EndedChildIsNotHungNorKilled)
TestRun.Case("Stall: a stand-still of the supervisor moves the deadlines of the hub, the shutdown and the report once (WI-0033)", StallMovesEveryDeadline)
TestRun.Case("Stall: regular ticks and a short delay move nothing (WI-0033)", NoStallMovesNothing)
TestRun.Case("Stall: a stand-still before the first tick is measured too (WI-0033)", StallBeforeTheFirstTickIsMeasured)
TestRun.Case("Children: a stand-still moves the kill time, the restart time and the grace time (WI-0033)", StallMovesTheTimesOfTheRecords)
TestRun.Case("Shutdown: the deadline and the kill wait move with a stand-still (WI-0033)", ShutdownDeadlinesMove)
TestRun.Case("Shutdown: a process that ended by itself at the deadline does not make exit code 5 (F-0029, WI-0033)", EndedAtTheDeadlineIsNoForcedExit)
TestRun.Case("Shutdown: a process that has to be terminated at the deadline makes exit code 5 (WI-0033)", TerminatedAtTheDeadlineIsAForcedExit)
TestRun.Case("Hub: a request ends at its limit once, by the tick, and an answer in time wins (WI-0033)", HubRequestEndsAtItsLimit)
TestRun.Case("Hub: a stand-still moves the limit of a request and the hello time of a connection (WI-0033)", HubShiftMovesTheLimits)
TestRun.Case("Hub: a forwarded request is forgotten after its deadline, moves with a stand-still and ends only with the answer of its target (F-0036, WI-0034)", RoutedRequestEndsWithItsAnswerOrDeadline)
TestRun.Case("Hub: when the target goes, each open request gets one peer_gone and an answered one none (F-0036, WI-0034)", GoneTargetAnswersItsOpenRequests)
TestRun.Case("Hub: the requests of a sender that has gone are forgotten (F-0036, WI-0034)", RequestsOfAGoneSenderAreForgotten)
TestRun.Case("Children: the end of the engine ends its workers at once, as a planned end with the reason engine gone (E0010, WI-0033)", EngineEndEndsTheWorkers)
TestRun.Case("Children: a worker is not ended when the engine ends during the shutdown (E0010, WI-0033)", EngineEndDuringShutdownKeepsTheWorkers)
TestRun.Case("Children: a kill request for a worker whose process has already ended does not turn its crash into a planned exit (F-0042, WI-0035)", KillOfAnEndedWorkerStaysACrash)
TestRun.Case("Children: a kill request for a running worker ends it as a planned exit with the reason killed (WI-0035)", KillOfARunningWorkerIsAPlannedExit)
TestRun.Case("Children: the end of the engine does not relabel a worker that has ended already (F-0042, WI-0035)", EngineEndKeepsTheCrashOfAnEndedWorker)
TestRun.Case("Heartbeat: a child without pong for 6 s of regular ticks is hung", SilentChildIsHung)
TestRun.Case("Heartbeat: a stand-still of the supervisor does not make a ready child hung", StallDoesNotHangReadyChild)
TestRun.Case("Heartbeat: a stand-still does not make a starting child hung", StallDoesNotHangStartingChild)
TestRun.Case("Heartbeat: after a stand-still the ping schedule starts again", PingScheduleRestartsAfterStall)
TestRun.Case("Heartbeat: a child that is silent after a stand-still is still found", SilentAfterStallIsStillHung)
TestRun.Case("Heartbeat: a stand-still before the first tick is noticed too (Arm)", StallBeforeTheFirstTick)
TestRun.Case("Heartbeat: a busy worker is not pinged and not hung (WI-0027)", BusyWorkerIsNeitherPingedNorHung)
TestRun.Case("Heartbeat: the pong time of a worker starts again when its job ends (WI-0027)", PongTimeStartsAgainWhenTheJobEnds)
TestRun.Case("Heartbeat: a worker without a job is hung as before (WI-0027)", IdleWorkerWithoutPongIsHung)
TestRun.Case("Heartbeat: only a worker can be busy (WI-0027)", OnlyAWorkerCanBeBusy)
TestRun.Case("Children: a hello before the pid is stored keeps the state ready and takes the pid (WI-0027)", HelloBeforeThePidIsStored)
TestRun.Case("Shutdown: a child of a group that had its turn gets sys.shutdown at its late hello, then the next group follows (F-0037, WI-0034)", LateHelloGetsTheShutdown)
TestRun.Case("Shutdown: a child of a later group that says hello during the shutdown waits for the turn of its group (F-0037, WI-0034)", LateHelloOfALaterGroupWaitsForItsTurn)
TestRun.Case("Shutdown: a child that is in no group (started after the groups were made) gets sys.shutdown at its hello (F-0037, WI-0034)", LateHelloOfAChildInNoGroup)
TestRun.Case("Shutdown: a hello in the prepare phase or in the kill phase gets no sys.shutdown (F-0037, WI-0034)", HelloOutsideThePhaseShutdownGetsNothing)
TestRun.Case("Children: a restart that was planned before the shutdown does not start (F-0037, WI-0034)", PlannedRestartIsCancelledByTheShutdown)
TestRun.Case("Data directory: --data wins over AHF_DATA_DIR, which wins over the application data folder", DataDirFollowsOptionThenEnvironmentThenAppData)

ByeIsReadBeforeTheExitIsReported() {
    hubStub := FakeHub()
    s := NewSupervisor(hubStub)
    AddChild(s.children, "echo", "stopping", Time.NowMs())
    ; the bye was sent before the process ended, but lies unread in the pipe
    hubStub.pending.Push(() => s.children.OnBye("echo", true))
    s._Tick()
    ev := hubStub.Find("evt.process.exited")
    Assert.True(IsObject(ev), "evt.process.exited published")
    Assert.True(ev["payload"]["clean"] == Json.True, "clean, because the bye was read first")
}

ExitWithoutByeIsNotClean() {
    hubStub := FakeHub()
    s := NewSupervisor(hubStub)
    AddChild(s.children, "echo", "stopping", Time.NowMs())
    s._Tick()
    ev := hubStub.Find("evt.process.exited")
    Assert.True(IsObject(ev), "evt.process.exited published")
    Assert.True(ev["payload"]["clean"] == Json.False)
}

HubIsPumpedEveryTick() {
    hubStub := FakeHub()
    s := NewSupervisor(hubStub)
    s._Tick()
    s._Tick()
    Assert.Equal(hubStub.pumps, 2)
}

; Cause B of F-0023: the tick timer interrupted a pump thread of the wake-up. Its own hub.Pump() returns at once
; (re-entrance guard), so the bye that the interrupted pump has not read yet is unread when the tick sees the
; ended process. The exit must wait until the connection is read to its end (the link is gone).
ExitWaitsWhileAPumpRuns() {
    hubStub := FakeHub()
    s := NewSupervisor(hubStub)
    AddChild(s.children, "echo", "stopping", Time.NowMs())
    hubStub.links["echo"] := true
    hubStub.pending.Push(() => s.children.OnBye("echo", true))
    hubStub.pumping := true
    s._Tick()
    Assert.Equal(hubStub.Count("evt.process.exited") + hubStub.Count("evt.process.crashed"), 0
        , "not judged while the bye may still be unread")
    ; the interrupted pump goes on: it reads the bye and then the end of the pipe (the hub drops the link)
    hubStub.pumping := false
    hubStub.Pump()
    hubStub.links.Delete("echo")
    s._Tick()
    ev := hubStub.Find("evt.process.exited")
    Assert.True(IsObject(ev), "evt.process.exited published after the link is gone")
    Assert.True(ev["payload"]["clean"] == Json.True, "clean, because the bye was read before the exit was judged")
    Assert.Equal(hubStub.Count("evt.process.exited"), 1)
}

ExitIsJudgedAfterTheGraceTime() {
    hubStub := FakeHub()
    s := NewSupervisor(hubStub)
    t0 := 100000
    AddChild(s.children, "echo", "stopping", t0)
    hubStub.links["echo"] := true                       ; the connection never ends (or is never read)
    s.children.Tick(t0)
    s.children.Tick(t0 + Children.EXIT_GRACE_MS - 1)
    Assert.Equal(hubStub.Count("evt.process.exited"), 0, "still waiting within the grace time")
    s.children.Tick(t0 + Children.EXIT_GRACE_MS)
    ev := hubStub.Find("evt.process.exited")
    Assert.True(IsObject(ev), "judged at the end of the grace time")
    Assert.True(ev["payload"]["clean"] == Json.False, "no bye was read")
    Assert.True(s.children.IsGone("echo"))
}

ExitWithoutLinkIsJudgedAtOnce() {
    hubStub := FakeHub()
    s := NewSupervisor(hubStub)
    t0 := 100000
    AddChild(s.children, "echo", "ready", t0)       ; ended without being asked, never connected
    s.children.Tick(t0)
    ev := hubStub.Find("evt.process.crashed")
    Assert.True(IsObject(ev), "crashed is reported in the first tick")
}

EndedChildIsNotHungNorKilled() {
    hubStub := FakeHub()
    s := NewSupervisor(hubStub)
    t0 := 100000
    AddChild(s.children, "echo", "ready", t0)
    hubStub.links["echo"] := true
    s.children.Tick(t0)                              ; the end is seen, the judgement waits for the link
    s.children.MarkHung("echo", "test")
    Assert.Equal(s.children.State("echo"), "ready", "an ended process is not hung")
    s.children.KillAlive()                           ; the shutdown deadline passes in the grace time
    Assert.Equal(s.children.AnyKilled(), false, "an ended process is not terminated and does not count as killed")
    hubStub.links.Delete("echo")
    s.children.Tick(t0 + 200)
    ev := hubStub.Find("evt.process.crashed")
    Assert.True(IsObject(ev) && ev["payload"]["reason"] == "exited", "an exit, not a hang")
}

; --- heartbeat ------------------------------------------------------------------------------------

; A ready child without a process (handle 0 is never looked at by Heartbeat).
AddLiveChild(children, name, state, t0) {
    rec := AddChildRecord(children, name, state, t0)
    rec["handle"] := 0
    return rec
}

AddChildRecord(children, name, state, t0) {
    rec := Map("name", name, "role", name, "flow", "", "state", state, "pid", 4242, "handle", 0
        , "gone", false, "exitCode", "", "startedAt", t0, "readyAt", t0, "lastPingAt", t0, "pingN", 0
        , "lastPongAt", t0, "bye", false, "byeClean", false, "restartTimes", [], "restartAt", 0
        , "killAt", 0, "restartable", false, "reader", "", "output", [])
    children._recs[name] := rec
    return rec
}

NewHeartbeat(state, t0) {
    hubStub := FakeHub()
    ; Not named "children": AHK identifiers are case-insensitive, it would shadow the class Children.
    kids := Children(Map("session", "t", "pipe", "p", "data", "d", "hubHwnd", 0, "testRoles", false
        , "script", "x", "roleOpts", ""), hubStub)
    AddLiveChild(kids, "echo", state, t0)
    return [Heartbeat(kids, hubStub), kids, hubStub]
}

; Ticks every 200 ms from t0 + 200 up to and including t0 + untilMs.
TickRegularly(hb, t0, untilMs) {
    t := t0 + 200
    while (t <= t0 + untilMs) {
        hb.Tick(t)
        t += 200
    }
}

SilentChildIsHung() {
    t0 := 100000
    r := NewHeartbeat("ready", t0)
    TickRegularly(r[1], t0, 7000)
    Assert.Equal(r[2].State("echo"), "hung")
    Assert.Equal(r[3].Count("evt.process.hung"), 1)
}

; What Supervisor._RunTick does about a stand-still, without the supervisor: Stall measures it, Children.OnStall acts,
; then the heartbeat runs. r is the result of NewHeartbeat.
StalledTick(r, stall, t) {
    ms := stall.Check(t)
    if (ms > 0)
        r[2].OnStall(t, ms)
    r[1].Tick(t)
}

NewStall() => Stall(Stall.MIN_GAP_MS, Supervisor.TICK_MS)

StallDoesNotHangReadyChild() {
    t0 := 100000
    r := NewHeartbeat("ready", t0)
    hb := r[1]
    stallObj := NewStall()
    stallObj.Arm(t0)
    TickRegularly(hb, t0, 1000)
    stallObj.Check(t0 + 1000)
    StalledTick(r, stallObj, t0 + 1000 + 8000)        ; the supervisor was frozen for 8 s
    Assert.Equal(r[2].State("echo"), "ready")
    Assert.Equal(r[3].Count("evt.process.hung"), 0)
    Assert.Equal(r[3].sent.Length, 0, "no shutdown sent to the child")
}

StallDoesNotHangStartingChild() {
    t0 := 100000
    r := NewHeartbeat("starting", t0)
    hb := r[1]
    stallObj := NewStall()
    stallObj.Arm(t0)
    StalledTick(r, stallObj, t0 + 200)
    StalledTick(r, stallObj, t0 + 200 + Children.STARTUP_MS + 5000)
    Assert.Equal(r[2].State("echo"), "starting")
    ; the start deadline begins again after the stand-still
    TickRegularly(hb, t0 + 15200, Children.STARTUP_MS - 400)
    Assert.Equal(r[2].State("echo"), "starting")
    hb.Tick(t0 + 15200 + Children.STARTUP_MS + 200)
    Assert.Equal(r[2].State("echo"), "hung")
}

PingScheduleRestartsAfterStall() {
    t0 := 100000
    r := NewHeartbeat("ready", t0)
    hb := r[1]
    stallObj := NewStall()
    stallObj.Arm(t0)
    StalledTick(r, stallObj, t0 + 200)
    StalledTick(r, stallObj, t0 + 20000)              ; stand-still
    Assert.Equal(r[3].sent.Length, 0, "no ping at the moment of the reset")
    hb.Tick(t0 + 20000 + Heartbeat.PING_EVERY_MS)
    Assert.Equal(r[3].sent.Length, 1)
    Assert.Equal(r[3].sent[1]["type"], "sys.ping")
}

SilentAfterStallIsStillHung() {
    t0 := 100000
    r := NewHeartbeat("ready", t0)
    hb := r[1]
    stallObj := NewStall()
    stallObj.Arm(t0)
    StalledTick(r, stallObj, t0 + 200)
    StalledTick(r, stallObj, t0 + 20000)              ; stand-still, reset
    TickRegularly(hb, t0 + 20000, Heartbeat.PONG_TIMEOUT_MS + 400)
    Assert.Equal(r[2].State("echo"), "hung")
}

StallBeforeTheFirstTick() {
    t0 := 100000
    r := NewHeartbeat("ready", t0)
    hb := r[1]
    stallObj := NewStall()
    stallObj.Arm(t0)                    ; the supervisor starts its timer
    StalledTick(r, stallObj, t0 + 9000) ; frozen before the first tick ever ran
    Assert.Equal(r[2].State("echo"), "ready")
    Assert.Equal(r[3].Count("evt.process.hung"), 0)
}

; --- deadlines after a stand-still (WI-0033, F-0015, E0012) -------------------------------------------------------------------

StallMovesEveryDeadline() {
    hubStub := FakeHub()
    s := NewSupervisor(hubStub)
    t0 := 100000
    s.stall.Arm(t0)
    s._RunTick(t0 + 200)
    Assert.Equal(hubStub.shifted, 0, "a regular tick moves nothing")
    s._RunTick(t0 + 200 + 8200)              ; 8 s without a tick: the gap is 8200 ms, of which 200 ms are a regular tick
    Assert.Equal(hubStub.shifted, 8000, "the hub moves by the length of the stand-still")
    Assert.Equal(s.shutdown.shifted, 8000)
    Assert.Equal(s.report.shifted, 8000)
    s._RunTick(t0 + 200 + 8200 + 200)
    Assert.Equal(hubStub.shifted, 8000, "moved once, not again at the next tick")
}

NoStallMovesNothing() {
    hubStub := FakeHub()
    s := NewSupervisor(hubStub)
    t0 := 100000
    s.stall.Arm(t0)
    s._RunTick(t0 + 200)
    s._RunTick(t0 + 200 + Stall.MIN_GAP_MS)  ; a gap of exactly the limit is no stand-still
    Assert.Equal(hubStub.shifted, 0, "a gap of the limit is no stand-still")
    s._RunTick(t0 + 200 + Stall.MIN_GAP_MS + 2300)
    Assert.Equal(hubStub.shifted, 2100)
}

StallBeforeTheFirstTickIsMeasured() {
    stallObj := NewStall()
    stallObj.Arm(1000)
    Assert.Equal(stallObj.Check(1000 + 9000), 8800)
    Assert.Equal(stallObj.Check(1000 + 9200), 0)
}

StallMovesTheTimesOfTheRecords() {
    hubStub := FakeHub()
    kids := Children(Map("session", "t", "pipe", "p", "data", "d", "hubHwnd", 0, "testRoles", false
        , "script", "x", "roleOpts", ""), hubStub)
    t0 := 100000
    hung := AddLiveChild(kids, "hung", "hung", t0)
    hung["killAt"] := t0 + 2000
    hung["handle"] := 0
    seen := AddLiveChild(kids, "seen", "ready", t0)
    seen["exitSeenAt"] := t0 + 50
    gone := AddLiveChild(kids, "gone", "crashed", t0)
    gone["gone"] := true
    gone["restartAt"] := t0 + 300
    kids.OnStall(t0 + 9000, 8000)
    Assert.Equal(hung["killAt"], t0 + 10000, "a hung child gets its kill time later by the stand-still")
    Assert.Equal(seen["exitSeenAt"], t0 + 8050, "the grace time of an ended process keeps its rest")
    Assert.Equal(gone["restartAt"], t0 + 8300, "the planned restart moves")
    Assert.Equal(kids.KillDue("hung", t0 + 9000), false, "not killed at once after the stand-still")
    Assert.True(kids.KillDue("hung", t0 + 10000))
}

NewKids(hub) {
    return Children(Map("session", "t", "pipe", "p", "data", "d", "hubHwnd", 0, "testRoles", false
        , "script", "x", "roleOpts", ""), hub)
}

ShutdownDeadlinesMove() {
    hubStub := FakeHub()
    kids := NewKids(hubStub)
    sd := Shutdown(kids, hubStub)
    sd.Shift(5000)
    Assert.Equal(sd.deadlineAt, 0, "nothing is set before the shutdown: nothing moves")
    sd.deadlineAt := 50000
    sd.Shift(8000)
    Assert.Equal(sd.deadlineAt, 58000)
    Assert.Equal(sd.killDeadline, 0)
    sd.killDeadline := 60000
    sd.Shift(1000)
    Assert.Equal(sd.killDeadline, 61000)
}

; F-0029: the deadline passes while a process has ended by itself and is only judged in the grace time (its connection is
; not read to the end yet). Nothing is terminated, so the exit code is 0.
EndedAtTheDeadlineIsNoForcedExit() {
    hubStub := FakeHub()
    kids := NewKids(hubStub)
    t0 := 100000
    AddChild(kids, "echo", "stopping", t0)
    hubStub.links["echo"] := true                        ; the connection is not read to its end yet
    code := ""
    sd := Shutdown(kids, hubStub)
    sd.onDone := (c) => code := c
    sd.phase := "shutdown"
    sd.deadlineAt := t0
    kids.BeginShutdown()
    kids.Tick(t0)                                    ; the end is seen, the judgement waits
    sd.Tick(t0)                                      ; the deadline: the kill phase begins
    Assert.Equal(sd.phase, "kill")
    Assert.Equal(kids.AnyKilled(), false, "an ended process is not terminated")
    hubStub.links.Delete("echo")
    kids.Tick(t0 + 200)
    sd.Tick(t0 + 200)
    Assert.Equal(sd.phase, "done")
    Assert.Equal(code, Shutdown.EXIT_CLEAN, "nothing was terminated: exit 0")
}

; A process that is still running; the handle is the one the tests open (Children.OPEN_ACCESS).
RunningProcessHandle() {
    pid := 0
    Run(A_ComSpec ' /c ping -n 30 127.0.0.1 >nul', , "Hide", &pid)
    return DllCall("OpenProcess", "uint", Children.OPEN_ACCESS, "int", 0, "uint", pid, "ptr")
}

WaitForEnd(h) {
    Loop 100 {
        if (DllCall("WaitForSingleObject", "ptr", h, "uint", 0, "uint") = 0)
            return
        Sleep(50)
    }
}

TerminatedAtTheDeadlineIsAForcedExit() {
    hubStub := FakeHub()
    kids := NewKids(hubStub)
    t0 := 100000
    rec := AddChild(kids, "slow", "stopping", t0)
    DllCall("CloseHandle", "ptr", rec["handle"])
    rec["handle"] := RunningProcessHandle()
    code := ""
    sd := Shutdown(kids, hubStub)
    sd.onDone := (c) => code := c
    sd.phase := "shutdown"
    sd.deadlineAt := t0
    kids.BeginShutdown()
    sd.Tick(t0)                                      ; the deadline: the process is terminated
    Assert.True(kids.AnyKilled())
    WaitForEnd(rec["handle"])
    kids.Tick(t0 + 200)
    sd.Tick(t0 + 200)
    Assert.Equal(code, Shutdown.EXIT_FORCED)
}

; --- Hub deadlines (WI-0033) ---------------------------------------------------------------------------------

; A connection whose frames go nowhere. No pipe, no listener.
class SinkConn {
    closed := false
    SendFrame(text) {
        return true
    }
    Close() {
        this.closed := true
    }
}

NewHubWithClient() {
    Ids.Configure("tick-test")
    h := Hub("unused", "t")
    h._links["ui"] := Map("name", "ui", "conn", SinkConn(), "pid", 1, "hwnd", 0, "topics", Map(), "helloAt", 0)
    return h
}

HubRequestEndsAtItsLimit() {
    h := NewHubWithClient()
    answers := []
    h.Request("ui", "cmd.x.y", Map(), (a) => answers.Push(a), 1000)
    t := Time.NowMs()
    h.Tick(t + 500)
    Assert.Equal(answers.Length, 0, "not before the limit")
    h.Tick(t + 1100)
    Assert.Equal(answers.Length, 1)
    Assert.True(IsObject(answers[1]) && answers[1].payload["error"]["code"] == ErrCode.TIMEOUT, "the synthetic timeout answer")
    h.Tick(t + 3000)
    Assert.Equal(answers.Length, 1, "once")
    ; an answer that comes in time wins, and nothing is called twice
    answers2 := []
    id2 := h.Request("ui", "cmd.x.y", Map(), (a) => answers2.Push(a), 1000)
    h._Answer(Message("supervisor", "ui", "ui#1", "res.x.y", Map("ok", true), id2))
    h.Tick(Time.NowMs() + 5000)
    Assert.Equal(answers2.Length, 1)
    Assert.True(answers2[1].payload["ok"])
}

HubShiftMovesTheLimits() {
    h := NewHubWithClient()
    answers := []
    h.Request("ui", "cmd.x.y", Map(), (a) => answers.Push(a), 5000)
    anon := SinkConn()
    h._anon[ObjPtr(anon)] := Map("conn", anon, "since", Time.NowMs())
    t := Time.NowMs()
    h.Shift(8000)                                    ; a stand-still of 8 s
    h.Tick(t + 8000)
    Assert.Equal(answers.Length, 0, "the request has its rest of the time")
    Assert.Equal(anon.closed, false, "the connection without hello has its rest of the time")
    h.Tick(t + 8000 + 5200)
    Assert.Equal(answers.Length, 1)
    Assert.True(anon.closed)
}

; --- requests between clients (F-0036, WI-0034) ---------------------------------------------------------------------------

; A connection that keeps what is sent to it.
class RecordConn {
    __New() {
        this.frames := []
    }
    SendFrame(text) {
        this.frames.Push(text)
        return true
    }
    Close() {
    }
}

AddHubLink(h, name, conn) {
    h._links[name] := Map("name", name, "conn", conn, "pid", 1, "hwnd", 0, "topics", Map(), "helloAt", 0)
}

RoutedRequestEndsWithItsAnswerOrDeadline() {
    h := NewHubWithClient()
    AddHubLink(h, "st", SinkConn())
    t := Time.NowMs()
    h._NoteRouted("ui", "st", "cmd.storage.flow.read", "ui#1", "", 1000)
    Assert.Equal(h._routed.Count, 1)
    h.Shift(8000)                                    ; a stand-still of 8 s
    h.Tick(t + 8000 + 1500)
    Assert.Equal(h._routed.Count, 1, "the deadline plus the slack has not passed after the shift")
    h.Tick(t + 8000 + 1000 + Hub.ROUTED_SLACK_MS + 300)
    Assert.Equal(h._routed.Count, 0, "forgotten after its deadline, without an answer of the hub")
    h._NoteRouted("ui", "st", "cmd.x.y", "ui#2", "", 5000)
    h._NoteRouted("other", "ui", "res.x.y", "other#1", "ui#2", 0)
    Assert.Equal(h._routed.Count, 1, "an answer from someone else than the target does not end it")
    h._NoteRouted("st", "ui", "res.x.y", "st#1", "ui#2", 0)
    Assert.Equal(h._routed.Count, 0, "the answer of the target ends it")
    h._NoteRouted("ui", "st", "evt.x.y", "ui#3", "", 0)
    Assert.Equal(h._routed.Count, 0, "events are not requests")
    h._NoteRouted("ui", "st", "cmd.x.z", "ui#4", "", 0)
    Assert.True(h._routed["ui`nui#4"]["dueAt"] >= Time.NowMs() + Hub.ROUTED_DEFAULT_MS, "without timeoutMs: the default")
}

GoneTargetAnswersItsOpenRequests() {
    h := NewHubWithClient()
    ui := RecordConn()
    AddHubLink(h, "ui", ui)
    AddHubLink(h, "st", SinkConn())
    h._NoteRouted("ui", "st", "cmd.storage.flow.read", "ui#1", "", 30000)
    h._NoteRouted("ui", "st", "cmd.storage.flow.read", "ui#2", "", 30000)
    h._NoteRouted("st", "ui", "res.storage.flow.read", "st#1", "ui#1", 0)    ; ui#1 was answered before the end
    h._FailRouted("st", "peer_closed")
    Assert.Equal(ui.frames.Length, 1, "one peer_gone, only for the open request")
    m := Message.Parse(ui.frames[1])
    Assert.Equal(m.type, "res.storage.flow.read")
    Assert.Equal(m.corr, "ui#2")
    Assert.Equal(m.to, "ui")
    Assert.Equal(m.payload["error"]["code"], ErrCode.PEER_GONE)
    Assert.True(!m.payload["ok"])
    Assert.Equal(h._routed.Count, 0)
    Assert.Equal(h.goneAnswers, 1)
    h._FailRouted("st", "peer_closed")
    Assert.Equal(ui.frames.Length, 1, "nothing twice")
}

RequestsOfAGoneSenderAreForgotten() {
    h := NewHubWithClient()
    AddHubLink(h, "st", SinkConn())
    h._NoteRouted("ui", "st", "cmd.x.y", "ui#1", "", 30000)
    h._NoteRouted("st", "ui", "cmd.x.y", "st#1", "", 30000)
    h._ForgetRoutedFrom("ui")
    Assert.Equal(h._routed.Count, 1, "only the requests of the sender")
    Assert.True(h._routed.Has("st`nst#1"))
}

; --- the workers end with the engine (E0010, WI-0033) ---------------------------------------------------------------------

AddWorker(kids, name, t0) {
    rec := AddChild(kids, name, "ready", t0)
    rec["role"] := "worker"
    rec["flow"] := SubStr(name, 8)
    DllCall("CloseHandle", "ptr", rec["handle"])
    rec["handle"] := RunningProcessHandle()
    return rec
}

EngineEndEndsTheWorkers() {
    hubStub := FakeHub()
    kids := NewKids(hubStub)
    t0 := 100000
    engine := AddChild(kids, "engine", "ready", t0)     ; ended, never connected: judged at once
    engine["role"] := "engine"
    w := AddWorker(kids, "worker:1", t0)
    kids.Tick(t0)
    Assert.Equal(w["state"], "stopping")
    Assert.Equal(w["killReason"], "engine gone")
    Assert.Equal(kids.AnyKilled(), false, "a planned end does not count for exit code 5")
    WaitForEnd(w["handle"])
    kids.Tick(t0 + 200)
    ev := ""
    for e in hubStub.events
        if (e["type"] = "evt.process.exited" && e["payload"]["name"] = "worker:1")
            ev := e
    Assert.True(IsObject(ev), "evt.process.exited for the worker")
    Assert.Equal(ev["payload"]["reason"], "engine gone")
    Assert.Equal(hubStub.Count("evt.process.crashed"), 1, "only the engine crashed")
}

; F-0042 (WI-0035): the engine asks for the kill of a worker that has died already, the supervisor has not judged its end yet.
; The end must stay a crash; it is not a planned exit "killed".
KillOfAnEndedWorkerStaysACrash() {
    hubStub := FakeHub()
    kids := NewKids(hubStub)
    t0 := 100000
    w := AddChild(kids, "worker:1", "ready", t0)         ; process ended, not judged yet
    w["role"] := "worker"
    w["flow"] := "1"
    kids.KillWorker("worker:1", "run not accepted: peer_gone")
    Assert.Equal(w["state"], "ready", "an ended process is not relabelled as stopping")
    Assert.Equal(w.Get("killReason", ""), "")
    kids.Tick(t0)
    Assert.Equal(hubStub.Count("evt.process.crashed"), 1, "judged as a crash")
    Assert.Equal(hubStub.Count("evt.process.exited"), 0, "not as a planned exit")
    Assert.Equal(hubStub.Find("evt.process.crashed")["payload"]["reason"], "exited")
    Assert.Equal(kids.AnyKilled(), false)
    Assert.Equal(kids.State("worker:1"), "crashed")
}

KillOfARunningWorkerIsAPlannedExit() {
    hubStub := FakeHub()
    kids := NewKids(hubStub)
    t0 := 100000
    w := AddWorker(kids, "worker:1", t0)
    kids.KillWorker("worker:1", "test")
    Assert.Equal(w["killReason"], "killed")
    WaitForEnd(w["handle"])
    kids.Tick(t0 + 200)
    ev := hubStub.Find("evt.process.exited")
    Assert.True(IsObject(ev), "evt.process.exited")
    Assert.Equal(ev["payload"]["reason"], "killed")
    Assert.Equal(hubStub.Count("evt.process.crashed"), 0)
}

EngineEndKeepsTheCrashOfAnEndedWorker() {
    hubStub := FakeHub()
    kids := NewKids(hubStub)
    t0 := 100000
    engine := AddChild(kids, "engine", "ready", t0)
    engine["role"] := "engine"
    w := AddChild(kids, "worker:1", "ready", t0)         ; died before the engine, not judged yet
    w["role"] := "worker"
    w["flow"] := "1"
    kids.Tick(t0)
    Assert.Equal(hubStub.Count("evt.process.exited"), 0, "an ended worker is not reported as 'engine gone'")
    Assert.Equal(hubStub.Count("evt.process.crashed"), 2, "engine and worker crashed")
}

EngineEndDuringShutdownKeepsTheWorkers() {
    hubStub := FakeHub()
    kids := NewKids(hubStub)
    t0 := 100000
    engine := AddChild(kids, "engine", "stopping", t0)
    engine["role"] := "engine"
    w := AddWorker(kids, "worker:1", t0)
    kids.BeginShutdown()
    kids.Tick(t0)
    Assert.Equal(w["state"], "ready", "the shutdown order of the ranks applies, not the end with the engine")
    Assert.Equal(w.Get("killReason", ""), "")
    kids.Terminate("worker:1", false)
}

; --- busy workers (WI-0027) ---------------------------------------------------------------------------

NewWorkerHeartbeat(t0) {
    r := NewHeartbeat("ready", t0)
    kids := r[2]
    rec := kids._recs["echo"]
    kids._recs.Delete("echo")
    rec["name"] := "worker:1"
    rec["role"] := "worker"
    kids._recs["worker:1"] := rec
    return r
}

BusyWorkerIsNeitherPingedNorHung() {
    t0 := 100000
    r := NewWorkerHeartbeat(t0)
    r[2].OnBusy("worker:1", true, t0)
    TickRegularly(r[1], t0, 20000)           ; 20 s without any pong
    Assert.Equal(r[2].State("worker:1"), "ready")
    Assert.Equal(r[3].Count("evt.process.hung"), 0)
    Assert.Equal(r[3].sent.Length, 0, "not pinged")
}

PongTimeStartsAgainWhenTheJobEnds() {
    t0 := 100000
    r := NewWorkerHeartbeat(t0)
    hb := r[1]
    r[2].OnBusy("worker:1", true, t0)
    TickRegularly(hb, t0, 20000)
    r[2].OnBusy("worker:1", false, t0 + 20000)
    hb.Tick(t0 + 20200)
    Assert.Equal(r[2].State("worker:1"), "ready", "the 20 s of the job are not held against it")
    TickRegularly(hb, t0 + 20200, Heartbeat.PONG_TIMEOUT_MS + 400)
    Assert.Equal(r[2].State("worker:1"), "hung", "silent after the job: found as before")
}

IdleWorkerWithoutPongIsHung() {
    t0 := 100000
    r := NewWorkerHeartbeat(t0)
    TickRegularly(r[1], t0, 7000)
    Assert.Equal(r[2].State("worker:1"), "hung")
}

OnlyAWorkerCanBeBusy() {
    t0 := 100000
    r := NewHeartbeat("ready", t0)           ; the child is "echo"
    r[2].OnBusy("echo", true, t0)
    Assert.Equal(r[2].IsBusy("echo"), false)
    TickRegularly(r[1], t0, 7000)
    Assert.Equal(r[2].State("echo"), "hung")
}

; The child said hello while the supervisor was still inside Spawn (interrupted between CreateProcessW and the
; storing of the pid): the record is ready and keeps the pid of the link.
HelloBeforeThePidIsStored() {
    t0 := 100000
    r := NewHeartbeat("starting", t0)
    kids := r[2]
    kids._recs["echo"]["pid"] := 0
    kids.OnHello(Map("name", "echo", "pid", 5151))
    Assert.Equal(kids.State("echo"), "ready")
    Assert.Equal(kids._recs["echo"]["pid"], 5151)
}

; --- a child that says hello during the shutdown (F-0037, WI-0034) --------------------------------------------------

; A supervisor with a real Shutdown and two children without processes (handle 0; Children.Tick is not called).
NewShutdownSupervisor(hub, children) {
    s := NewSupervisor(hub)
    s.shutdown := Shutdown(s.children, hub)
    s.shutdown.reason := "user"
    s.shutdown.deadlineMs := 5000
    for entry in children {
        rec := AddLiveChild(s.children, entry[1], entry[3], Time.NowMs())
        rec["role"] := entry[2]
    }
    return s
}

; The late child (rank 3) is still starting when its group gets sys.shutdown: nothing reaches it. Its hello comes later.
; It must get sys.shutdown then, with the rest of the deadline. Storage (rank 4) does not wait for it (F-0039).
LateHelloGetsTheShutdown() {
    hubStub := FakeHub()
    s := NewShutdownSupervisor(hubStub, [["storage", "storage", "ready"], ["echo:late", "echo", "starting"]])
    hubStub.offline["echo:late"] := true
    s.shutdown._StartShutdown()
    s.shutdown.Tick(Time.NowMs())
    Assert.Equal(hubStub.SentCount("echo:late", "sys.shutdown"), 0, "not connected yet: nothing was sent")
    Assert.Equal(hubStub.SentCount("storage", "sys.shutdown"), 1, "storage does not wait for a child that has not connected (F-0039)")
    hubStub.offline.Delete("echo:late")
    s._OnHello(Map("name", "echo:late", "pid", 1))
    msg := hubStub.LastSent("echo:late", "sys.shutdown")
    Assert.True(IsObject(msg), "the late child gets sys.shutdown at its hello")
    d := msg["payload"]["deadlineMs"]
    Assert.True(d > 0 && d <= 5000, "with the rest of the deadline, got " d)
    Assert.Equal(msg["payload"]["reason"], "user")
    Assert.Equal(s.children.State("echo:late"), "stopping")
    s.children.OnBye("echo:late", true)
    s.shutdown.Tick(Time.NowMs())
    Assert.Equal(hubStub.SentCount("storage", "sys.shutdown"), 1, "once")
    Assert.Equal(hubStub.SentCount("echo:late", "sys.shutdown"), 1, "once")
}

; The manager (rank 0) has not said bye yet when the late child (rank 3) says hello: the order of the ranks applies.
LateHelloOfALaterGroupWaitsForItsTurn() {
    hubStub := FakeHub()
    s := NewShutdownSupervisor(hubStub, [["manager", "manager", "ready"], ["echo:late", "echo", "starting"]
        , ["storage", "storage", "ready"]])
    hubStub.offline["echo:late"] := true
    s.shutdown._StartShutdown()
    Assert.Equal(hubStub.SentCount("manager", "sys.shutdown"), 1)
    hubStub.offline.Delete("echo:late")
    s._OnHello(Map("name", "echo:late", "pid", 1))
    Assert.Equal(hubStub.SentCount("echo:late", "sys.shutdown"), 0, "its group has not had its turn yet")
    s.children.OnBye("manager", true)
    s.shutdown.Tick(Time.NowMs())
    Assert.Equal(hubStub.SentCount("echo:late", "sys.shutdown"), 1, "sent when its group has its turn, once")
    Assert.Equal(hubStub.SentCount("storage", "sys.shutdown"), 0, "storage after it")
}

; A child that was not alive when the groups were made (its process was being created at that moment) is in no group.
; Nobody waits for it in the order, but the shutdown waits for its end (AllGone): it gets sys.shutdown at its hello.
LateHelloOfAChildInNoGroup() {
    hubStub := FakeHub()
    s := NewShutdownSupervisor(hubStub, [["storage", "storage", "ready"]])
    s.shutdown._StartShutdown()
    rec := AddLiveChild(s.children, "worker:1", "starting", Time.NowMs())
    rec["role"] := "worker"
    s._OnHello(Map("name", "worker:1", "pid", 1))
    Assert.Equal(hubStub.SentCount("worker:1", "sys.shutdown"), 1)
}

HelloOutsideThePhaseShutdownGetsNothing() {
    hubStub := FakeHub()
    s := NewShutdownSupervisor(hubStub, [["echo:late", "echo", "starting"]])
    s.shutdown.phase := "prepare"
    s._OnHello(Map("name", "echo:late", "pid", 1))
    Assert.Equal(hubStub.SentCount("echo:late", "sys.shutdown"), 0, "prepare: the groups are made later and include it")
    s.children._recs["echo:late"]["state"] := "starting"
    s.shutdown.phase := "kill"
    s._OnHello(Map("name", "echo:late", "pid", 1))
    Assert.Equal(hubStub.SentCount("echo:late", "sys.shutdown"), 0, "kill: KillAlive has ended it already")
}

; Children that start no process: _Launch only records the name.
class NoLaunchChildren extends Children {
    launched := []
    _Launch(rec, isRestart, now) {
        this.launched.Push(rec["name"])
    }
}

; The engine crashed and its restart is planned (RESTART_DELAY_MS) when the session begins to end. Before WI-0034 the
; tick still started it: a new engine in the middle of the shutdown, in no group, terminated at the deadline (exit 5).
PlannedRestartIsCancelledByTheShutdown() {
    t0 := 100000
    for shuttingDown in [false, true] {
        kids := NoLaunchChildren(Map("session", "t", "pipe", "p", "data", "d", "hubHwnd", 0, "testRoles", false
            , "script", "x", "roleOpts", ""), FakeHub())
        rec := AddChildRecord(kids, "engine", "crashed", t0)
        rec["role"] := "engine"
        rec["gone"] := true
        rec["restartAt"] := t0 + Children.RESTART_DELAY_MS
        if (shuttingDown)
            kids.BeginShutdown()
        kids.Tick(t0 + Children.RESTART_DELAY_MS + 200)
        if (!shuttingDown) {
            Assert.Equal(kids.launched.Length, 1, "without a shutdown the planned restart starts (the test double works)")
            continue
        }
        Assert.Equal(kids.launched.Length, 0, "no restart while the session ends")
        Assert.Equal(rec["restartAt"], 0, "the planned restart is cancelled")
    }
}

; --data wins over AHF_DATA_DIR, which wins over %APPDATA%\AutoHotFlow v2 (not the v1 folder, E0033). The environment
; of this process is changed and restored, nothing is started.
DataDirFollowsOptionThenEnvironmentThenAppData() {
    saved := EnvGet(Supervisor.DATA_DIR_ENV)
    try {
        EnvSet(Supervisor.DATA_DIR_ENV, "C:\env-dir")
        Assert.Equal(Supervisor.DataDir(Map("data", "C:\option-dir")), "C:\option-dir", "--data wins")
        Assert.Equal(Supervisor.DataDir(Map()), "C:\env-dir", "the environment variable is the second choice")
        EnvSet(Supervisor.DATA_DIR_ENV, "")
        Assert.Equal(Supervisor.DataDir(Map()), A_AppData "\AutoHotFlow v2", "without both: the application data folder of v2")
    } finally {
        EnvSet(Supervisor.DATA_DIR_ENV, saved)
    }
}

TestRun.Finish()
