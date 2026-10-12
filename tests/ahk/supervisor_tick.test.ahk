#Requires AutoHotkey v2.0
; Unit tests for the order of work in Supervisor._Tick and the heartbeat rules (WI-22, F-06, F-11,
; doc/ARCHITEKTUR.md 6.2). No process of the roles is started: Children works on hand-made records,
; the hub is a fake whose Pump() delivers what "has already arrived".
#Include lib\Assert.ahk
#Include ..\..\src\supervisor\Supervisor.ahk

; Stands in for Hub and Heartbeat/Shutdown collaborators. pending holds the messages that lie in the
; pipes but have not been read yet; Pump() hands them over. links holds the names whose connection has not been
; read to its end yet (Hub.HasLink). pumping simulates a pump that another thread runs at the moment (the timer
; interrupted it): like PipeConnection.Pump, a second Pump then only marks "pump again" and returns (WI-30).
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
    }
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
        this.sent.Push(Map("to", to, "type", type))
        return true
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

TestRun.Case("Tick: a sys.bye that is unread when the process end is seen is read first (F-06, F-11)", ByeIsReadBeforeTheExitIsReported)
TestRun.Case("Tick: an exit without any sys.bye is reported as not clean", ExitWithoutByeIsNotClean)
TestRun.Case("Tick: the hub is pumped at the start of every tick", HubIsPumpedEveryTick)
TestRun.Case("Tick: an exit is not judged while another pump still reads the connection of the child (F-26, WI-30)", ExitWaitsWhileAPumpRuns)
TestRun.Case("Children: an ended process whose connection does not end is judged after the grace time (WI-30)", ExitIsJudgedAfterTheGraceTime)
TestRun.Case("Children: an ended child without a connection is judged at once (WI-30)", ExitWithoutLinkIsJudgedAtOnce)
TestRun.Case("Children: an ended child that waits for its judgement is neither hung nor terminated (WI-30)", EndedChildIsNotHungNorKilled)
TestRun.Case("Stall: a stand-still of the supervisor moves the deadlines of the hub, the shutdown and the report once (WI-33)", StallMovesEveryDeadline)
TestRun.Case("Stall: regular ticks and a short delay move nothing (WI-33)", NoStallMovesNothing)
TestRun.Case("Stall: a stand-still before the first tick is measured too (WI-33)", StallBeforeTheFirstTickIsMeasured)
TestRun.Case("Children: a stand-still moves the kill time, the restart time and the grace time (WI-33)", StallMovesTheTimesOfTheRecords)
TestRun.Case("Shutdown: the deadline and the kill wait move with a stand-still (WI-33)", ShutdownDeadlinesMove)
TestRun.Case("Shutdown: a process that ended by itself at the deadline does not make exit code 5 (F-33, WI-33)", EndedAtTheDeadlineIsNoForcedExit)
TestRun.Case("Shutdown: a process that has to be terminated at the deadline makes exit code 5 (WI-33)", TerminatedAtTheDeadlineIsAForcedExit)
TestRun.Case("Hub: a request ends at its limit once, by the tick, and an answer in time wins (WI-33)", HubRequestEndsAtItsLimit)
TestRun.Case("Hub: a stand-still moves the limit of a request and the hello time of a connection (WI-33)", HubShiftMovesTheLimits)
TestRun.Case("Children: the end of the engine ends its workers at once, as a planned end with the reason engine gone (E10, WI-33)", EngineEndEndsTheWorkers)
TestRun.Case("Children: a worker is not ended when the engine ends during the shutdown (E10, WI-33)", EngineEndDuringShutdownKeepsTheWorkers)
TestRun.Case("Heartbeat: a child without pong for 6 s of regular ticks is hung", SilentChildIsHung)
TestRun.Case("Heartbeat: a stand-still of the supervisor does not make a ready child hung", StallDoesNotHangReadyChild)
TestRun.Case("Heartbeat: a stand-still does not make a starting child hung", StallDoesNotHangStartingChild)
TestRun.Case("Heartbeat: after a stand-still the ping schedule starts again", PingScheduleRestartsAfterStall)
TestRun.Case("Heartbeat: a child that is silent after a stand-still is still found", SilentAfterStallIsStillHung)
TestRun.Case("Heartbeat: a stand-still before the first tick is noticed too (Arm)", StallBeforeTheFirstTick)
TestRun.Case("Heartbeat: a busy worker is not pinged and not hung (WI-27)", BusyWorkerIsNeitherPingedNorHung)
TestRun.Case("Heartbeat: the pong time of a worker starts again when its job ends (WI-27)", PongTimeStartsAgainWhenTheJobEnds)
TestRun.Case("Heartbeat: a worker without a job is hung as before (WI-27)", IdleWorkerWithoutPongIsHung)
TestRun.Case("Heartbeat: only a worker can be busy (WI-27)", OnlyAWorkerCanBeBusy)
TestRun.Case("Children: a hello before the pid is stored keeps the state ready and takes the pid (WI-27)", HelloBeforeThePidIsStored)

ByeIsReadBeforeTheExitIsReported() {
    hub := FakeHub()
    s := NewSupervisor(hub)
    AddChild(s.children, "echo", "stopping", Time.NowMs())
    ; the bye was sent before the process ended, but lies unread in the pipe
    hub.pending.Push(() => s.children.OnBye("echo", true))
    s._Tick()
    ev := hub.Find("evt.process.exited")
    Assert.True(IsObject(ev), "evt.process.exited published")
    Assert.True(ev["payload"]["clean"] == Json.True, "clean, because the bye was read first")
}

ExitWithoutByeIsNotClean() {
    hub := FakeHub()
    s := NewSupervisor(hub)
    AddChild(s.children, "echo", "stopping", Time.NowMs())
    s._Tick()
    ev := hub.Find("evt.process.exited")
    Assert.True(IsObject(ev), "evt.process.exited published")
    Assert.True(ev["payload"]["clean"] == Json.False)
}

HubIsPumpedEveryTick() {
    hub := FakeHub()
    s := NewSupervisor(hub)
    s._Tick()
    s._Tick()
    Assert.Equal(hub.pumps, 2)
}

; Cause B of F-26: the tick timer interrupted a pump thread of the wake-up. Its own hub.Pump() returns at once
; (re-entrance guard), so the bye that the interrupted pump has not read yet is unread when the tick sees the
; ended process. The exit must wait until the connection is read to its end (the link is gone).
ExitWaitsWhileAPumpRuns() {
    hub := FakeHub()
    s := NewSupervisor(hub)
    AddChild(s.children, "echo", "stopping", Time.NowMs())
    hub.links["echo"] := true
    hub.pending.Push(() => s.children.OnBye("echo", true))
    hub.pumping := true
    s._Tick()
    Assert.Equal(hub.Count("evt.process.exited") + hub.Count("evt.process.crashed"), 0
        , "not judged while the bye may still be unread")
    ; the interrupted pump goes on: it reads the bye and then the end of the pipe (the hub drops the link)
    hub.pumping := false
    hub.Pump()
    hub.links.Delete("echo")
    s._Tick()
    ev := hub.Find("evt.process.exited")
    Assert.True(IsObject(ev), "evt.process.exited published after the link is gone")
    Assert.True(ev["payload"]["clean"] == Json.True, "clean, because the bye was read before the exit was judged")
    Assert.Equal(hub.Count("evt.process.exited"), 1)
}

ExitIsJudgedAfterTheGraceTime() {
    hub := FakeHub()
    s := NewSupervisor(hub)
    t0 := 100000
    AddChild(s.children, "echo", "stopping", t0)
    hub.links["echo"] := true                       ; the connection never ends (or is never read)
    s.children.Tick(t0)
    s.children.Tick(t0 + Children.EXIT_GRACE_MS - 1)
    Assert.Equal(hub.Count("evt.process.exited"), 0, "still waiting within the grace time")
    s.children.Tick(t0 + Children.EXIT_GRACE_MS)
    ev := hub.Find("evt.process.exited")
    Assert.True(IsObject(ev), "judged at the end of the grace time")
    Assert.True(ev["payload"]["clean"] == Json.False, "no bye was read")
    Assert.True(s.children.IsGone("echo"))
}

ExitWithoutLinkIsJudgedAtOnce() {
    hub := FakeHub()
    s := NewSupervisor(hub)
    t0 := 100000
    AddChild(s.children, "echo", "ready", t0)       ; ended without being asked, never connected
    s.children.Tick(t0)
    ev := hub.Find("evt.process.crashed")
    Assert.True(IsObject(ev), "crashed is reported in the first tick")
}

EndedChildIsNotHungNorKilled() {
    hub := FakeHub()
    s := NewSupervisor(hub)
    t0 := 100000
    AddChild(s.children, "echo", "ready", t0)
    hub.links["echo"] := true
    s.children.Tick(t0)                              ; the end is seen, the judgement waits for the link
    s.children.MarkHung("echo", "test")
    Assert.Equal(s.children.State("echo"), "ready", "an ended process is not hung")
    s.children.KillAlive()                           ; the shutdown deadline passes in the grace time
    Assert.Equal(s.children.AnyKilled(), false, "an ended process is not terminated and does not count as killed")
    hub.links.Delete("echo")
    s.children.Tick(t0 + 200)
    ev := hub.Find("evt.process.crashed")
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
    hub := FakeHub()
    ; Not named "children": AHK identifiers are case-insensitive, it would shadow the class Children.
    kids := Children(Map("session", "t", "pipe", "p", "data", "d", "hubHwnd", 0, "testRoles", false
        , "script", "x", "roleOpts", ""), hub)
    AddLiveChild(kids, "echo", state, t0)
    return [Heartbeat(kids, hub), kids, hub]
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
    stall := NewStall()
    stall.Arm(t0)
    TickRegularly(hb, t0, 1000)
    stall.Check(t0 + 1000)
    StalledTick(r, stall, t0 + 1000 + 8000)        ; the supervisor was frozen for 8 s
    Assert.Equal(r[2].State("echo"), "ready")
    Assert.Equal(r[3].Count("evt.process.hung"), 0)
    Assert.Equal(r[3].sent.Length, 0, "no shutdown sent to the child")
}

StallDoesNotHangStartingChild() {
    t0 := 100000
    r := NewHeartbeat("starting", t0)
    hb := r[1]
    stall := NewStall()
    stall.Arm(t0)
    StalledTick(r, stall, t0 + 200)
    StalledTick(r, stall, t0 + 200 + Children.STARTUP_MS + 5000)
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
    stall := NewStall()
    stall.Arm(t0)
    StalledTick(r, stall, t0 + 200)
    StalledTick(r, stall, t0 + 20000)              ; stand-still
    Assert.Equal(r[3].sent.Length, 0, "no ping at the moment of the reset")
    hb.Tick(t0 + 20000 + Heartbeat.PING_EVERY_MS)
    Assert.Equal(r[3].sent.Length, 1)
    Assert.Equal(r[3].sent[1]["type"], "sys.ping")
}

SilentAfterStallIsStillHung() {
    t0 := 100000
    r := NewHeartbeat("ready", t0)
    hb := r[1]
    stall := NewStall()
    stall.Arm(t0)
    StalledTick(r, stall, t0 + 200)
    StalledTick(r, stall, t0 + 20000)              ; stand-still, reset
    TickRegularly(hb, t0 + 20000, Heartbeat.PONG_TIMEOUT_MS + 400)
    Assert.Equal(r[2].State("echo"), "hung")
}

StallBeforeTheFirstTick() {
    t0 := 100000
    r := NewHeartbeat("ready", t0)
    hb := r[1]
    stall := NewStall()
    stall.Arm(t0)                    ; the supervisor starts its timer
    StalledTick(r, stall, t0 + 9000) ; frozen before the first tick ever ran
    Assert.Equal(r[2].State("echo"), "ready")
    Assert.Equal(r[3].Count("evt.process.hung"), 0)
}

; --- deadlines after a stand-still (WI-33, F-16, E12) -------------------------------------------------------------------

StallMovesEveryDeadline() {
    hub := FakeHub()
    s := NewSupervisor(hub)
    t0 := 100000
    s.stall.Arm(t0)
    s._RunTick(t0 + 200)
    Assert.Equal(hub.shifted, 0, "a regular tick moves nothing")
    s._RunTick(t0 + 200 + 8200)              ; 8 s without a tick: the gap is 8200 ms, of which 200 ms are a regular tick
    Assert.Equal(hub.shifted, 8000, "the hub moves by the length of the stand-still")
    Assert.Equal(s.shutdown.shifted, 8000)
    Assert.Equal(s.report.shifted, 8000)
    s._RunTick(t0 + 200 + 8200 + 200)
    Assert.Equal(hub.shifted, 8000, "moved once, not again at the next tick")
}

NoStallMovesNothing() {
    hub := FakeHub()
    s := NewSupervisor(hub)
    t0 := 100000
    s.stall.Arm(t0)
    s._RunTick(t0 + 200)
    s._RunTick(t0 + 200 + Stall.MIN_GAP_MS)  ; a gap of exactly the limit is no stand-still
    Assert.Equal(hub.shifted, 0, "a gap of the limit is no stand-still")
    s._RunTick(t0 + 200 + Stall.MIN_GAP_MS + 2300)
    Assert.Equal(hub.shifted, 2100)
}

StallBeforeTheFirstTickIsMeasured() {
    stall := NewStall()
    stall.Arm(1000)
    Assert.Equal(stall.Check(1000 + 9000), 8800)
    Assert.Equal(stall.Check(1000 + 9200), 0)
}

StallMovesTheTimesOfTheRecords() {
    hub := FakeHub()
    kids := Children(Map("session", "t", "pipe", "p", "data", "d", "hubHwnd", 0, "testRoles", false
        , "script", "x", "roleOpts", ""), hub)
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
    hub := FakeHub()
    kids := NewKids(hub)
    sd := Shutdown(kids, hub)
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

; F-33: the deadline passes while a process has ended by itself and is only judged in the grace time (its connection is
; not read to the end yet). Nothing is terminated, so the exit code is 0.
EndedAtTheDeadlineIsNoForcedExit() {
    hub := FakeHub()
    kids := NewKids(hub)
    t0 := 100000
    AddChild(kids, "echo", "stopping", t0)
    hub.links["echo"] := true                        ; the connection is not read to its end yet
    code := ""
    sd := Shutdown(kids, hub)
    sd.onDone := (c) => code := c
    sd.phase := "shutdown"
    sd.deadlineAt := t0
    kids.BeginShutdown()
    kids.Tick(t0)                                    ; the end is seen, the judgement waits
    sd.Tick(t0)                                      ; the deadline: the kill phase begins
    Assert.Equal(sd.phase, "kill")
    Assert.Equal(kids.AnyKilled(), false, "an ended process is not terminated")
    hub.links.Delete("echo")
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
    hub := FakeHub()
    kids := NewKids(hub)
    t0 := 100000
    rec := AddChild(kids, "slow", "stopping", t0)
    DllCall("CloseHandle", "ptr", rec["handle"])
    rec["handle"] := RunningProcessHandle()
    code := ""
    sd := Shutdown(kids, hub)
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

; --- Hub deadlines (WI-33) ---------------------------------------------------------------------------------

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

; --- the workers end with the engine (E10, WI-33) ---------------------------------------------------------------------

AddWorker(kids, name, t0) {
    rec := AddChild(kids, name, "ready", t0)
    rec["role"] := "worker"
    rec["flow"] := SubStr(name, 8)
    DllCall("CloseHandle", "ptr", rec["handle"])
    rec["handle"] := RunningProcessHandle()
    return rec
}

EngineEndEndsTheWorkers() {
    hub := FakeHub()
    kids := NewKids(hub)
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
    for e in hub.events
        if (e["type"] = "evt.process.exited" && e["payload"]["name"] = "worker:1")
            ev := e
    Assert.True(IsObject(ev), "evt.process.exited for the worker")
    Assert.Equal(ev["payload"]["reason"], "engine gone")
    Assert.Equal(hub.Count("evt.process.crashed"), 1, "only the engine crashed")
}

EngineEndDuringShutdownKeepsTheWorkers() {
    hub := FakeHub()
    kids := NewKids(hub)
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

; --- busy workers (WI-27) ---------------------------------------------------------------------------

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

TestRun.Finish()
