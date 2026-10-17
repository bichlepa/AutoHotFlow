#Requires AutoHotkey v2.0
; Unit tests for src/ui_common/UiDialogs.ahk (WI-0069): the claim of one dialog per kind and owner, the check of an input
; value, and the answer that goes once to the callback. No window is created here (the dialogs are in the gui tier).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\core\Log.ahk
#Include ..\..\src\ui_common\UiDialogs.ahk

Log.Configure(Log.Memory)

; A dialog state as UiDialogs._Begin makes it, without a window.
NewState(owner, kind, calls) {
    cb := (ok, value) => calls.Push([ok, value])
    return Map("gui", "", "hwnd", 0, "lay", "", "status", "", "owner", owner, "kind", kind,
        "callback", cb, "done", false)
}

; Functions that throw (a throw is a statement, so a lambda cannot throw in one expression).
BrokenCheck(v) {
    throw ValueError("broken check")
}

BrokenCallback(ok, value) {
    throw ValueError("callback broke")
}

TestRun.Init()

TestRun.Case("Claim: one dialog of a kind per owner", () => (
    UiDialogs._open.Clear(),
    Assert.True(UiDialogs._Claim(7, "confirm"), "the first one is claimed"),
    Assert.True(!UiDialogs._Claim(7, "confirm"), "a second one of the same kind is refused"),
    Assert.True(UiDialogs.IsOpen(7, "confirm"), "the claim is visible"),
    UiDialogs._Release(7, "confirm"),
    Assert.True(!UiDialogs.IsOpen(7, "confirm"), "released"),
    Assert.True(UiDialogs._Claim(7, "confirm"), "after the release it is claimable again")))

TestRun.Case("Claim: kinds and owners are independent", () => (
    UiDialogs._open.Clear(),
    Assert.True(UiDialogs._Claim(7, "confirm")),
    Assert.True(UiDialogs._Claim(7, "input"), "another kind of the same owner is free"),
    Assert.True(UiDialogs._Claim(8, "confirm"), "the same kind of another owner is free"),
    Assert.True(UiDialogs._Claim(0, "confirm"), "owner 0 (no owner) is its own owner")))

TestRun.Case("CheckInput: no check accepts everything", () => (
    Assert.Equal(UiDialogs.CheckInput("", "anything"), ""),
    Assert.Equal(UiDialogs.CheckInput(0, "anything"), "")))

TestRun.Case("CheckInput: the check decides, an empty result accepts", () => (
    check := (v) => (InStr(v, "/") ? "Forbidden character: /" : ""),
    Assert.Equal(UiDialogs.CheckInput(check, "flow one"), ""),
    Assert.Equal(UiDialogs.CheckInput(check, "flow/one"), "Forbidden character: /")))

TestRun.Case("CheckInput: a check that throws refuses the value with its message", () => (
    res := UiDialogs.CheckInput(BrokenCheck, "x"),
    Assert.True(InStr(res, "broken check") > 0, "the message is in the result: " res)))

TestRun.Case("Answer: the first answer goes once to the callback", () => (
    UiDialogs._open.Clear(),
    calls := [],
    st := NewState(3, "input", calls),
    UiDialogs._Claim(3, "input"),
    UiDialogs.Answer(st, true, "first"),
    UiDialogs.Answer(st, false, "second"),
    Assert.Equal(calls.Length, 1, "one call"),
    Assert.Equal(calls[1][2], "first", "the first value"),
    Assert.True(calls[1][1], "the first ok"),
    Assert.True(!UiDialogs.IsOpen(3, "input"), "the answer released the kind")))

TestRun.Case("Answer: a close answer carries close and does not end the thread", () => (
    UiDialogs._open.Clear(),
    calls := [],
    st := NewState(0, "confirm", calls),
    UiDialogs._Claim(0, "confirm"),
    UiDialogs.Answer(st, false, "close"),
    Assert.Equal(calls[1][2], "close"),
    Assert.True(!calls[1][1])))

TestRun.Case("Answer: an error in the callback is logged, the answer is kept", () => (
    UiDialogs._open.Clear(),
    Log.memoryLines := [],
    st := Map("gui", "", "hwnd", 0, "lay", "", "status", "", "owner", 4, "kind", "choose",
        "callback", BrokenCallback, "done", false),
    UiDialogs._Claim(4, "choose"),
    UiDialogs.Answer(st, true, "x"),
    Assert.True(st["done"], "the answer is kept"),
    Assert.True(!UiDialogs.IsOpen(4, "choose"), "released despite the error"),
    Assert.True(HasLog("a0", "callback broke"), "the error is logged")))

TestRun.Finish()

HasLog(level, part) {
    for line in Log.memoryLines {
        if (line["level"] = level && InStr(line["text"], part))
            return true
    }
    return false
}
