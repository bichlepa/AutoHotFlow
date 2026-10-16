#Requires AutoHotkey v2.0
; Unit tests for src/elements/base/DialogWindow.ahk (WI-0056): the handlers of the debug window run under _Guard, so a
; failed request of the view (a timeout, a stopped instance: ElementError in the worker) reaches the status line of the
; window and does not end the thread inside the GUI event. The window itself is not opened here (gui tests).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\core\Errors.ahk
#Include ..\..\src\elements\base\DialogWindow.ahk

; A control with the one property the handlers use.
class FakeControl {
    Value := ""
}

; A view whose requests fail as the worker's do when the engine does not answer.
class FailingView {
    ReadOnly := false
    Rows() {
        throw ElementError("engine did not answer (variable request)")
    }
}

TestRun.Init()

TestRun.Case("_Guard: a failing request ends in the status line, not in the thread", () => (
    c := Map("status", FakeControl(), "view", FailingView(), "names", [], "name", ""),
    DialogWindow._Guard(c, "_Fill", ""),
    Assert.True(InStr(c["status"].Value, "engine did not answer") > 0, "the status line shows the error"),
    Assert.True(InStr(c["status"].Value, "Error: ") = 1, "the error is marked as an error")))

TestRun.Case("_Guard: a handler that works leaves the status line alone", () => (
    c := Map("status", FakeControl(), "name", "", "names", [], "edit", FakeControl()),
    c["status"].Value := "",
    DialogWindow._Guard(c, "_ShowText"),
    Assert.Equal(c["status"].Value, "")))

TestRun.Finish()
