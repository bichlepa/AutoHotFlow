#Requires AutoHotkey v2.0
#SingleInstance Off
; Unit tests for src/elements/Default/Triggers/Trigger_Time_Of_Day.ahk (WI-0131): the next time on the week days, the
; week day and time parameters, the error texts, and the timer callback (fires at the time, waits when the clock says
; it is not there yet). Fixed times are used where the result depends on the date; no real time is waited for.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\elements\Default\Triggers\Trigger_Time_Of_Day.ahk

; Parameters as the engine delivers them.
Prm(opts := {}) {
    p := {WeekDays: "1234567", Time: "20261101100000"}
    for key, value in opts.OwnProps()
        p.%key% := value
    return p
}

; The parts of the trigger context that Enable and the timer callback use. After keeps the callbacks; Fire counts.
class FakeTimeCtx {
    State := {}
    IsOpen => true
    fires := 0
    delays := []
    callbacks := []
    After(ms, fn) {
        this.delays.Push(ms)
        this.callbacks.Push(fn)
        return this.callbacks.Length
    }
    Fire(*) {
        this.fires += 1
    }
    Log(*) {
    }
}

Case1() {
    ; Sunday 2026-11-01 (WDay 1) at 09:30: today's 10:00 is the next time; at 10:00 the next one is the next day.
    Assert.Equal(Trigger_Time_Of_Day.NextTime("1234567", "100000", "20261101093000"), "20261101100000")
    Assert.Equal(Trigger_Time_Of_Day.NextTime("1234567", "100000", "20261101100000"), "20261102100000", "strictly after")
    Assert.Equal(Trigger_Time_Of_Day.NextTime("1234567", "235959", "20261101235958"), "20261101235959")
    ; Only Sunday (1): the next Sunday. Only Monday (2) from Sunday: the next day.
    Assert.Equal(Trigger_Time_Of_Day.NextTime("1", "100000", "20261101100000"), "20261108100000")
    Assert.Equal(Trigger_Time_Of_Day.NextTime("2", "100000", "20261101100000"), "20261102100000")
    ; Saturday and Sunday (1 and 7), from Monday 2026-11-02 at 09:00: Saturday 2026-11-07.
    Assert.Equal(Trigger_Time_Of_Day.NextTime("17", "100000", "20261102090000"), "20261107100000")
    ; Nothing selected or no time: no next time.
    Assert.Equal(Trigger_Time_Of_Day.NextTime("", "100000", "20261101093000"), "")
    Assert.Equal(Trigger_Time_Of_Day.NextTime("1234567", "", "20261101093000"), "")
}

Case2() {
    Assert.Equal(Trigger_Time_Of_Day.WeekDaysOf(Prm({WeekDays: "1234567"})), "1234567")
    Assert.Equal(Trigger_Time_Of_Day.WeekDaysOf(Prm({WeekDays: "5 1"})), "15", "ascending digits")
    Assert.Equal(Trigger_Time_Of_Day.WeekDaysOf(Prm({WeekDays: ""})), "")
    Assert.Equal(Trigger_Time_Of_Day.WeekDaysOf(Prm({WeekDays: 3})), "3")
    Assert.Equal(Trigger_Time_Of_Day.TimeOfDay("20261101093015"), "093015", "the time of a stamp")
    Assert.Equal(Trigger_Time_Of_Day.TimeOfDay("093015"), "093015", "a time text")
    e := Assert.Throws(() => Trigger_Time_Of_Day.TimeOfDay("20261101"), ElementError, "a date is no time")
    Assert.True(InStr(e.Message, "'Time'"), "the v1 text names the parameter")
    Assert.Throws(() => Trigger_Time_Of_Day.TimeOfDay("250000"), ElementError, "hour 25")
    Assert.Throws(() => Trigger_Time_Of_Day.TimeOfDay("206000"), ElementError, "minute 60")
}

Case3() {
    name := Trigger_Time_Of_Day.GenerateName(FakeTimeCtx(), Prm({Time: "20261101093015"}))
    Assert.Equal(name, "Time of day - 09:30:15 - Weekdays: '1234567'")
}

Case4() {
    ; Enable arms one timer; no week day is refused with the v1 text and nothing is armed.
    ctx := FakeTimeCtx()
    Trigger_Time_Of_Day.Enable(ctx, Prm({Time: "235959"}))
    Assert.Equal(ctx.delays.Length, 1, "one timer")
    Assert.True(ctx.delays[1] >= 1 && ctx.delays[1] <= 86400000, "the delay is a time of one day")
    ctx2 := FakeTimeCtx()
    e := Assert.Throws(() => Trigger_Time_Of_Day.Enable(ctx2, Prm({WeekDays: ""})), ElementError, "no week day")
    Assert.Equal(e.Message, "Can't calculate next trigger time")
    Assert.Equal(ctx2.delays.Length, 0, "nothing armed")
}

Case5() {
    ; The timer ran early (the time is a minute ahead): no fire, the timer is set again for the rest.
    ctx := FakeTimeCtx()
    ctx.State.weekDays := "1234567"
    ctx.State.hhmmss := "000000"
    ctx.State.target := DateAdd(A_Now, 60, "Seconds")
    Trigger_Time_Of_Day._Due(ctx)
    Assert.Equal(ctx.fires, 0, "no fire before the time")
    Assert.Equal(ctx.delays.Length, 1, "waits again")
    Assert.True(ctx.delays[1] > 30000, "the rest of the minute")
}

Case6() {
    ; The timer runs at or after the time: it fires once and the next time is set again (the time is in the past).
    ctx := FakeTimeCtx()
    ctx.State.weekDays := "1234567"
    ctx.State.hhmmss := SubStr(A_Now, -6)
    ctx.State.target := "20000101000000"
    Trigger_Time_Of_Day._Due(ctx)
    Assert.Equal(ctx.fires, 1, "fires once")
    Assert.Equal(ctx.delays.Length, 1, "the next time is set before the fire")
    Assert.True(ctx.State.target > A_Now, "the next time is after now")
}

TestRun.Case("NextTime: the next time on the week days, strictly after the given time", Case1)
TestRun.Case("WeekDaysOf, TimeOfDay: digits in order, times and the refused values", Case2)
TestRun.Case("GenerateName: the time and the week days of v1", Case3)
TestRun.Case("Enable: one timer; no week day is refused with the v1 text", Case4)
TestRun.Case("The timer callback waits when the time is not there yet", Case5)
TestRun.Case("The timer callback fires once and sets the next time", Case6)

TestRun.Finish()
