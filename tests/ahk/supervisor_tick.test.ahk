#Requires AutoHotkey v2.0
; Unit tests for the order of work in Supervisor._Tick and the heartbeat rules (WI-22, F-06, F-11,
; doc/ARCHITEKTUR.md 6.2). No process of the roles is started: Children works on hand-made records,
; the hub is a fake whose Pump() delivers what "has already arrived".
#Include lib\Assert.ahk
#Include ..\..\src\supervisor\Supervisor.ahk

; Stands in for Hub and Heartbeat/Shutdown collaborators. pending holds the messages that lie in the
; pipes but have not been read yet; Pump() hands them over.
class FakeHub {
    __New() {
        this.pending := []
        this.events := []
        this.sent := []
        this.pumps := 0
    }
    Pump() {
        this.pumps += 1
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
    Tick(now) {
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
    return s
}

TestRun.Init()

TestRun.Case("Tick: a sys.bye that is unread when the process end is seen is read first (F-06, F-11)", ByeIsReadBeforeTheExitIsReported)
TestRun.Case("Tick: an exit without any sys.bye is reported as not clean", ExitWithoutByeIsNotClean)
TestRun.Case("Tick: the hub is pumped at the start of every tick", HubIsPumpedEveryTick)
TestRun.Case("Heartbeat: a child without pong for 6 s of regular ticks is hung", SilentChildIsHung)
TestRun.Case("Heartbeat: a stand-still of the supervisor does not make a ready child hung", StallDoesNotHangReadyChild)
TestRun.Case("Heartbeat: a stand-still does not make a starting child hung", StallDoesNotHangStartingChild)
TestRun.Case("Heartbeat: after a stand-still the ping schedule starts again", PingScheduleRestartsAfterStall)
TestRun.Case("Heartbeat: a child that is silent after a stand-still is still found", SilentAfterStallIsStillHung)
TestRun.Case("Heartbeat: a stand-still before the first tick is noticed too (Arm)", StallBeforeTheFirstTick)

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

StallDoesNotHangReadyChild() {
    t0 := 100000
    r := NewHeartbeat("ready", t0)
    hb := r[1]
    TickRegularly(hb, t0, 1000)
    hb.Tick(t0 + 1000 + 8000)        ; the supervisor was frozen for 8 s
    Assert.Equal(r[2].State("echo"), "ready")
    Assert.Equal(r[3].Count("evt.process.hung"), 0)
    Assert.Equal(r[3].sent.Length, 0, "no shutdown sent to the child")
}

StallDoesNotHangStartingChild() {
    t0 := 100000
    r := NewHeartbeat("starting", t0)
    hb := r[1]
    hb.Tick(t0 + 200)
    hb.Tick(t0 + 200 + Children.STARTUP_MS + 5000)
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
    hb.Tick(t0 + 200)
    hb.Tick(t0 + 20000)              ; stand-still
    Assert.Equal(r[3].sent.Length, 0, "no ping at the moment of the reset")
    hb.Tick(t0 + 20000 + Heartbeat.PING_EVERY_MS)
    Assert.Equal(r[3].sent.Length, 1)
    Assert.Equal(r[3].sent[1]["type"], "sys.ping")
}

SilentAfterStallIsStillHung() {
    t0 := 100000
    r := NewHeartbeat("ready", t0)
    hb := r[1]
    hb.Tick(t0 + 200)
    hb.Tick(t0 + 20000)              ; stand-still, reset
    TickRegularly(hb, t0 + 20000, Heartbeat.PONG_TIMEOUT_MS + 400)
    Assert.Equal(r[2].State("echo"), "hung")
}

StallBeforeTheFirstTick() {
    t0 := 100000
    r := NewHeartbeat("ready", t0)
    hb := r[1]
    hb.Arm(t0)                       ; the supervisor starts its timer
    hb.Tick(t0 + 9000)               ; frozen before the first tick ever ran
    Assert.Equal(r[2].State("echo"), "ready")
    Assert.Equal(r[3].Count("evt.process.hung"), 0)
}

TestRun.Finish()
