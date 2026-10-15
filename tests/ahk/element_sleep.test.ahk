#Requires AutoHotkey v2.0
; Tests for the skeleton element Action_Sleep (WI-0009, doc/ELEMENT-API-V2.md section 4).
; The timing cases pump messages (Sleep() runs timers) and use wide tolerances: the timer is never
; early by design, but a loaded machine can delay it.
#Include lib\Assert.ahk
#Include ..\..\src\elements\base\ElementRunner.ahk
#Include ..\..\src\elements\skeleton\Action_Sleep.ahk

Recorder() {
    rec := {calls: 0, result: "", msg: ""}
    return rec
}

RecordFinish(rec, result, msg) {
    rec.calls += 1
    rec.result := result
    rec.msg := msg
}

MakeCtx(rec) {
    return ExecContext("flow1", "sleep1", "inst1", "t1", (c, r, m) => RecordFinish(rec, r, m))
}

WaitUntil(cond, timeoutMs := 3000) {
    deadline := Time.NowMs() + timeoutMs
    while (!cond()) {
        if (Time.NowMs() > deadline)
            return false
        Sleep(5)
    }
    return true
}

TestRun.Case("Sleep: 200 ms ends after about 200 ms", SleepEndsAfterDuration)
TestRun.Case("Sleep: Stop before the end gives no result", SleepStopGivesNoResult)
TestRun.Case("Sleep: Unit converts to milliseconds (default Seconds)", SleepUnitConversion)
TestRun.Case("Sleep: bad Duration or Unit throws ElementError", SleepBadParamsThrow)
TestRun.Case("Sleep: bad parameters end the run as exception", SleepBadParamsEndAsException)

SleepEndsAfterDuration() {
    rec := Recorder()
    ctx := MakeCtx(rec)
    start := Time.NowMs()
    ElementRunner.Run(Action_Sleep, ctx, {Duration: 200, Unit: "Milliseconds"})
    Assert.True(WaitUntil(() => rec.calls > 0), "sleep finished")
    elapsed := Time.NowMs() - start
    Assert.Equal(rec.result, "normal")
    Assert.True(elapsed >= 150, "not earlier than 150 ms, was " Round(elapsed) " ms")
    ; Measured 200 to 205 ms. The upper bound is wider than +-50 ms so that a loaded machine does not fail the test.
    Assert.True(elapsed <= 300, "not later than 300 ms, was " Round(elapsed) " ms")
}

SleepStopGivesNoResult() {
    rec := Recorder()
    ctx := MakeCtx(rec)
    ElementRunner.Run(Action_Sleep, ctx, {Duration: 300, Unit: "Milliseconds"})
    ElementRunner.Stop(Action_Sleep, ctx, {Duration: 300, Unit: "Milliseconds"})
    Sleep(400)
    Assert.Equal(rec.calls, 0, "a stopped sleep reports nothing")
}

SleepUnitConversion() {
    Assert.Equal(Action_Sleep.ToMs({Duration: 5, Unit: "Milliseconds"}), 5)
    Assert.Equal(Action_Sleep.ToMs({Duration: 2, Unit: "Seconds"}), 2000)
    Assert.Equal(Action_Sleep.ToMs({Duration: 1, Unit: "Minutes"}), 60000)
    Assert.Equal(Action_Sleep.ToMs({Duration: 2}), 2000, "missing Unit means Seconds")
    Assert.Equal(Action_Sleep.ToMs({Duration: "3", Unit: "Seconds"}), 3000, "numeric text is accepted")
}

SleepBadParamsThrow() {
    Assert.Throws(() => Action_Sleep.ToMs({}), ElementError, "missing Duration")
    Assert.Throws(() => Action_Sleep.ToMs({Duration: "abc"}), ElementError, "non-numeric Duration")
    Assert.Throws(() => Action_Sleep.ToMs({Duration: -1, Unit: "Seconds"}), ElementError, "negative Duration")
    Assert.Throws(() => Action_Sleep.ToMs({Duration: 1, Unit: "Hours"}), ElementError, "unknown Unit")
}

SleepBadParamsEndAsException() {
    rec := Recorder()
    ctx := MakeCtx(rec)
    ElementRunner.Run(Action_Sleep, ctx, {Unit: "Seconds"})
    Assert.Equal(rec.calls, 1)
    Assert.Equal(rec.result, "exception")
    Assert.True(InStr(rec.msg, "Duration") > 0, "message names the parameter")
}

TestRun.Finish()
