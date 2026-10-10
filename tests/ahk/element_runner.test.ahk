#Requires AutoHotkey v2.0
; Unit tests for src/elements/base/ExecContext.ahk, VarStore.ahk and ElementRunner.ahk (WI-09,
; doc/ELEMENT-API-V2.md section 3). Timer cases use the message loop: Sleep() runs timers.
#Include lib\Assert.ahk
#Include ..\..\src\elements\base\ElementRunner.ahk
#Include ..\..\src\elements\skeleton\Action_Do_nothing.ahk
#Include ..\..\src\elements\skeleton\Action_TestThrow.ahk

; Element classes used only by these tests. They are not registered.
class Test_DoubleFinish extends AhfElement {
    static Mode := "inline"
    static Run(ctx, params) {
        ctx.Finish("normal")
        ctx.Finish("no", "second call")
    }
}

class Test_TimerThenFinish extends AhfElement {
    static Mode := "inline"
    static Run(ctx, params) {
        ctx.State.hits := 0
        ctx.After(30, () => ctx.State.hits += 1)
        ctx.Finish("normal")
    }
}

class Test_TimerPending extends AhfElement {
    static Mode := "inline"
    static Run(ctx, params) {
        ctx.State.hits := 0
        ctx.After(100, () => ctx.State.hits += 1)
    }
}

class Test_Busy extends AhfElement {
    static Mode := "inline"
    static Run(ctx, params) {
        start := Time.NowMs()
        while (Time.NowMs() - start < 400) {
        }
        ctx.Finish("normal")
    }
}

class Test_LateThrow extends AhfElement {
    static Mode := "inline"
    static Run(ctx, params) {
        ctx.After(20, ThrowLate)
    }
}

ThrowLate() {
    throw ElementError("late")
}

Noop() {
}

; Plain object that records what the engine callback received.
Recorder() {
    rec := {calls: 0, result: "", msg: ""}
    return rec
}

RecordFinish(rec, result, msg) {
    rec.calls += 1
    rec.result := result
    rec.msg := msg
}

RecordSlow(rec, classId, ms) {
    rec.calls += 1
    rec.id := classId
    rec.ms := ms
}

MakeCtx(rec, vars := "") {
    return ExecContext("flow1", "e1", "inst1", "t1", (c, r, m) => RecordFinish(rec, r, m), vars)
}

; Pumps messages (so timers run) until cond() is true or the time is up. Returns true if cond held.
WaitUntil(cond, timeoutMs := 3000) {
    deadline := Time.NowMs() + timeoutMs
    while (!cond()) {
        if (Time.NowMs() > deadline)
            return false
        Sleep(5)
    }
    return true
}

TestRun.Case("Runner: an exception in Run ends the run as exception with its message", ExceptionBecomesException)
TestRun.Case("Runner: a second Finish is ignored and the first result stays", SecondFinishIgnored)
TestRun.Case("Runner: a quick element is not reported as slow", QuickRunNotSlow)
TestRun.Case("Runner: a Run longer than 250 ms is reported to onSlow", SlowRunIsReported)
TestRun.Case("Runner: a timer is cancelled when the run finishes", TimerCancelledByFinish)
TestRun.Case("Runner: Stop cancels pending timers and reports nothing", StopCancelsTimers)
TestRun.Case("Runner: an exception in a timer callback ends the run as exception", TimerExceptionEndsRun)
TestRun.Case("Context: Finish rejects an unknown result", FinishRejectsUnknownResult)
TestRun.Case("Context: After rejects a non-function callback", AfterRejectsNonFunction)
TestRun.Case("Context: After rejects a negative delay", AfterRejectsNegativeDelay)
TestRun.Case("Context: After after Finish schedules nothing", AfterAfterFinishIsNoop)
TestRun.Case("Context: variables in thread and instance scope", VariablesScopes)
TestRun.Case("Context: thread variable shadows instance variable", ThreadShadowsInstance)
TestRun.Case("Context: unsupported variable scope throws", UnsupportedScopeThrows)

ExceptionBecomesException() {
    rec := Recorder()
    ctx := MakeCtx(rec)
    ElementRunner.Run(Action_TestThrow, ctx, {})
    Assert.Equal(rec.calls, 1, "callback called once")
    Assert.Equal(rec.result, "exception")
    Assert.Equal(rec.msg, "test")
    Assert.True(ctx.finished)
}

SecondFinishIgnored() {
    rec := Recorder()
    ctx := MakeCtx(rec)
    ElementRunner.Run(Test_DoubleFinish, ctx, {})
    Assert.Equal(rec.calls, 1, "callback called once")
    Assert.Equal(rec.result, "normal")
    Assert.Equal(rec.msg, "")
    Assert.Equal(ctx.Finish("yes"), false, "a later Finish returns false")
}

QuickRunNotSlow() {
    rec := Recorder()
    ctx := MakeCtx(rec)
    slow := Recorder()
    ElementRunner.Run(Action_Do_nothing, ctx, {}, (id, ms) => RecordSlow(slow, id, ms))
    Assert.Equal(slow.calls, 0, "no slow report")
    Assert.Equal(rec.result, "normal")
}

SlowRunIsReported() {
    rec := Recorder()
    ctx := MakeCtx(rec)
    slow := Recorder()
    ElementRunner.Run(Test_Busy, ctx, {}, (id, ms) => RecordSlow(slow, id, ms))
    Assert.Equal(slow.calls, 1, "one slow report")
    Assert.Equal(slow.id, "Test_Busy", "report names the class")
    Assert.True(slow.ms >= 250, "reported time is at least the threshold")
    Assert.Equal(rec.result, "normal")
}

TimerCancelledByFinish() {
    rec := Recorder()
    ctx := MakeCtx(rec)
    ElementRunner.Run(Test_TimerThenFinish, ctx, {})
    Assert.Equal(rec.result, "normal")
    Sleep(150)
    Assert.Equal(ctx.State.hits, 0, "the timer did not fire after Finish")
    Assert.Equal(rec.calls, 1)
}

StopCancelsTimers() {
    rec := Recorder()
    ctx := MakeCtx(rec)
    ElementRunner.Run(Test_TimerPending, ctx, {})
    ElementRunner.Stop(Test_TimerPending, ctx, {})
    Sleep(250)
    Assert.Equal(ctx.State.hits, 0, "the timer did not fire after Stop")
    Assert.Equal(rec.calls, 0, "Stop does not finish the run")
}

TimerExceptionEndsRun() {
    rec := Recorder()
    ctx := MakeCtx(rec)
    ElementRunner.Run(Test_LateThrow, ctx, {})
    Assert.True(WaitUntil(() => rec.calls > 0), "callback arrives")
    Assert.Equal(rec.result, "exception")
    Assert.Equal(rec.msg, "late")
}

FinishRejectsUnknownResult() {
    rec := Recorder()
    ctx := MakeCtx(rec)
    Assert.Throws(() => ctx.Finish("maybe"), ElementError)
    Assert.Equal(rec.calls, 0)
    Assert.Equal(ctx.finished, false)
}

AfterRejectsNonFunction() {
    ctx := MakeCtx(Recorder())
    Assert.Throws(() => ctx.After(10, "nope"), ElementError)
}

AfterRejectsNegativeDelay() {
    ctx := MakeCtx(Recorder())
    Assert.Throws(() => ctx.After(-1, Noop), ElementError)
}

AfterAfterFinishIsNoop() {
    ctx := MakeCtx(Recorder())
    ctx.Finish("normal")
    Assert.Equal(ctx.After(10, Noop), 0)
}

VariablesScopes() {
    vars := VarStore()
    ctx := MakeCtx(Recorder(), vars)
    ctx.SetVar("Counter", 5)
    Assert.Equal(ctx.GetVar("counter"), 5, "names are case-insensitive")
    Assert.Equal(ctx.GetVar("missing", "dflt"), "dflt")
    ctx.SetVar("shared", "x", "instance")

    other := ExecContext("flow1", "e2", "inst1", "t2", "", VarStore(vars.instance))
    Assert.Equal(other.GetVar("shared"), "x", "instance scope is shared")
    Assert.Equal(other.GetVar("Counter", "none"), "none", "thread scope is not shared")
}

ThreadShadowsInstance() {
    ctx := MakeCtx(Recorder())
    ctx.SetVar("v", "inst", "instance")
    Assert.Equal(ctx.GetVar("v"), "inst")
    ctx.SetVar("v", "thr")
    Assert.Equal(ctx.GetVar("v"), "thr")
}

UnsupportedScopeThrows() {
    ctx := MakeCtx(Recorder())
    Assert.Throws(() => ctx.SetVar("x", 1, "loop"), ElementError)
    Assert.Throws(() => ctx.vars.Get("global", "x"), ElementError)
}

TestRun.Finish()
