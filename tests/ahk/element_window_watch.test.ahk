#Requires AutoHotkey v2.0
#SingleInstance Off
; Unit tests for the window and process triggers (WI-0132): the shared poll (WatchPoll: the period, one timer per
; interval, the subscribers), the process list (ProcessSnapshot: this process is in it, the filter), and the arming
; checks of the six classes (the v1 texts of a bad interval and of a missing window, the variables of an event).
; The integration tests of the same classes are in tests/integration/test_window_triggers.py and test_process_triggers.py.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\elements\Default\Triggers\Trigger_Window_Opens.ahk
#Include ..\..\src\elements\Default\Triggers\Trigger_Window_Closes.ahk
#Include ..\..\src\elements\Default\Triggers\Trigger_Window_Gets_Active.ahk
#Include ..\..\src\elements\Default\Triggers\Trigger_Window_Gets_Inactive.ahk
#Include ..\..\src\elements\Default\Triggers\Trigger_Process_starts.ahk
#Include ..\..\src\elements\Default\Triggers\Trigger_Process_Closes.ahk

; The parts of a trigger context that the arming and the poll use: the key, the state, Guard, Fire and IsOpen.
class FakeWatchCtx {
    State := {}
    triggerKey := "flow/element"
    IsOpen => true
    fires := []
    Guard(fn) => fn
    Fire(data := "") {
        this.fires.Push(data)
    }
    Log(*) {
    }
}

; Parameters as the engine delivers them (evaluated texts).
WinPrm(opts := {}) {
    p := {Wintitle: "AHF unit window", TitleMatchMode: 3, interval: "500", NotTriggerOnEnable: "1"
        , excludeTitle: "", winText: "", ExcludeText: "", ahk_class: "", ahk_exe: "", ahk_id: "", ahk_pid: ""
        , FindHiddenText: "0", FindHiddenWindow: "0", GetWindowInformation: ""}
    for key, value in opts.OwnProps()
        p.%key% := value
    return p
}

ProcPrm(opts := {}) {
    p := {ProcessName: "", interval: "1000", NotTriggerOnEnable: "1"}
    for key, value in opts.OwnProps()
        p.%key% := value
    return p
}

Case1() {
    ; The period: milliseconds as they are, rounded, at least 1; a value that is not a number above 0 is refused.
    Assert.Equal(WatchPoll.PeriodMs("500"), 500)
    Assert.Equal(WatchPoll.PeriodMs(0.4), 1, "below the timer resolution: 1 ms")
    Assert.Equal(WatchPoll.PeriodMs(2.6), 3, "rounded")
    for bad in ["0", "-5", "abc", ""]
        RefusedPeriod(bad)
}

; One refused interval: an ElementError whose text names the parameter.
RefusedPeriod(value) {
    e := Assert.Throws(() => WatchPoll.PeriodMs(value), ElementError, "bad interval '" value "'")
    Assert.True(InStr(e.Message, "interval"), e.Message)
}

Case2() {
    ; One timer per interval, shared by its subscribers; the timer stops with the last subscriber.
    before := WatchPoll.Counts()
    a := FakeWatchCtx()
    b := FakeWatchCtx()
    b.triggerKey := "flow/other"
    c := FakeWatchCtx()
    c.triggerKey := "flow/third"
    WatchPoll.Subscribe(a, 60000, () => 0)
    WatchPoll.Subscribe(b, 60000, () => 0)
    WatchPoll.Subscribe(c, 70000, () => 0)
    during := WatchPoll.Counts()
    Assert.Equal(during["timers"] - before["timers"], 2, "two intervals, two timers")
    Assert.Equal(during["subscribers"] - before["subscribers"], 3, "three subscribers")
    WatchPoll.Unsubscribe(a, 60000)
    WatchPoll.Unsubscribe(b, 60000)
    WatchPoll.Unsubscribe(c, 70000)
    after := WatchPoll.Counts()
    Assert.Equal(after["timers"], before["timers"], "the timers stop with their last subscriber")
    Assert.Equal(after["subscribers"], before["subscribers"])
}

Case3() {
    ; A subscriber is removed only by its own context (a new arming with the same key does not remove the old one).
    before := WatchPoll.Counts()
    a := FakeWatchCtx()
    other := FakeWatchCtx()
    WatchPoll.Subscribe(a, 61000, () => 0)
    WatchPoll.Unsubscribe(other, 61000)
    Assert.Equal(WatchPoll.Counts()["subscribers"] - before["subscribers"], 1, "another context leaves it")
    WatchPoll.Unsubscribe(a, 61000)
    Assert.Equal(WatchPoll.Counts()["timers"], before["timers"])
}

Case4() {
    ; The process list has this process (the test runner), and the filter matches by name (not case-sensitive), by ID,
    ; and everything for an empty filter.
    snap := ProcessSnapshot.Take()
    own := ProcessExist()
    Assert.True(snap.Has(own), "this process is in the list")
    Assert.True(StrLen(snap[own]) > 0, "with its base name")
    name := snap[own]
    Assert.True(ProcessSnapshot.Matching(snap, name).Has(own), "by name")
    Assert.True(ProcessSnapshot.Matching(snap, StrUpper(name)).Has(own), "the name is not case-sensitive")
    Assert.True(ProcessSnapshot.Matching(snap, String(own)).Has(own), "by process ID")
    Assert.Equal(ProcessSnapshot.Matching(snap, "").Count, snap.Count, "empty matches all")
    Assert.Equal(ProcessSnapshot.Matching(snap, "ahf-no-such-process.exe").Count, 0)
}

Case5() {
    ; The arming checks of the window triggers: no window is refused with the v1 text, and an interval that is not
    ; above 0 is refused with the v1 text. Nothing is subscribed when they fail.
    before := WatchPoll.Counts()["subscribers"]
    ctx := FakeWatchCtx()
    e := Assert.Throws(() => Trigger_Window_Opens.Enable(ctx, WinPrm({Wintitle: ""})), ElementError, "no window")
    Assert.Equal(e.Message, Lang("No window specified"))
    e := Assert.Throws(() => Trigger_Window_Closes.Enable(ctx, WinPrm({interval: "0"})), ElementError, "interval 0")
    Assert.True(InStr(e.Message, "interval"), e.Message)
    e := Assert.Throws(() => Trigger_Window_Gets_Active.Enable(ctx, WinPrm({interval: "x"})), ElementError, "interval x")
    Assert.True(InStr(e.Message, "interval"), e.Message)
    Assert.Equal(WatchPoll.Counts()["subscribers"], before, "a refused arming subscribes nothing")
    Assert.Equal(ctx.State.HasProp("subscribed"), false)
    e := Assert.Throws(() => Trigger_Process_starts.Enable(ctx, ProcPrm({interval: "-1"})), ElementError, "process interval")
    Assert.True(InStr(e.Message, "interval"), e.Message)
    e := Assert.Throws(() => Trigger_Process_Closes.Enable(ctx, ProcPrm({interval: "0"})), ElementError, "process close")
    Assert.True(InStr(e.Message, "interval"), e.Message)
    Assert.Equal(WatchPoll.Counts()["subscribers"], before)
}

Case6() {
    ; The variables of an event: the window ID as A_WindowID, the process as A_ProcessID and A_ProcessName; a start by
    ; the engine (no data) sets none.
    Assert.Equal(Trigger_Window_Opens.TriggerVariables(WinPrm(), Map("windowID", 77))["A_WindowID"], 77)
    Assert.Equal(Trigger_Window_Gets_Inactive.TriggerVariables(WinPrm(), "").Count, 0, "no data, no variable")
    vars := Trigger_Process_Closes.TriggerVariables(ProcPrm(), Map("processID", 4242, "processName", "x.exe"))
    Assert.Equal(vars["A_ProcessID"], 4242)
    Assert.Equal(vars["A_ProcessName"], "x.exe")
    Assert.Equal(Trigger_Process_starts.TriggerVariables(ProcPrm(), "").Count, 0)
}

Case7() {
    ; The names of the elements: the v1 class texts and the name with the identification and the process name.
    Assert.Equal(Trigger_Window_Opens.GenerateName(FakeWatchCtx(), WinPrm()), "Window opens: " WindowIdent.Name(WinPrm()))
    Assert.Equal(Trigger_Process_starts.GenerateName(FakeWatchCtx(), ProcPrm({ProcessName: "x.exe"})), "Process starts`nx.exe")
    Assert.Equal(Trigger_Process_Closes.GenerateName(FakeWatchCtx(), ProcPrm({ProcessName: "y.exe"})), "Process closes`ny.exe")
}

TestRun.Init()
TestRun.Case("WatchPoll.PeriodMs: the period and the refused intervals", Case1)
TestRun.Case("WatchPoll: one timer per interval, shared by its subscribers", Case2)
TestRun.Case("WatchPoll: a subscriber is removed by its own context only", Case3)
TestRun.Case("ProcessSnapshot: this process, the filter by name, ID and empty", Case4)
TestRun.Case("The arming checks of the window and process triggers (v1 texts)", Case5)
TestRun.Case("TriggerVariables of the window and process events", Case6)
TestRun.Case("GenerateName of the window and process triggers", Case7)

TestRun.Finish()
