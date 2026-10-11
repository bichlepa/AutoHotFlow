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
        , "killAt", 0, "restartable", false)
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

ByeIsReadBeforeTheExitIsReported() {
    hub := FakeHub()
    s := NewSupervisor(hub)
    AddChild(s.children, "echo", "stopping", Time.NowMs())
    ; the bye was sent before the process ended, but lies unread in the pipe
    hub.pending.Push(() => s.children.OnBye("echo", true))
    s._Tick()
    ev := hub.Find("evt.process.exited")
    Assert.True(IsObject(ev), "evt.process.exited published")
    Assert.Equal(ev["payload"]["clean"], true, "clean, because the bye was read first")
}

ExitWithoutByeIsNotClean() {
    hub := FakeHub()
    s := NewSupervisor(hub)
    AddChild(s.children, "echo", "stopping", Time.NowMs())
    s._Tick()
    ev := hub.Find("evt.process.exited")
    Assert.True(IsObject(ev), "evt.process.exited published")
    Assert.Equal(ev["payload"]["clean"], false)
}

HubIsPumpedEveryTick() {
    hub := FakeHub()
    s := NewSupervisor(hub)
    s._Tick()
    s._Tick()
    Assert.Equal(hub.pumps, 2)
}

TestRun.Finish()
