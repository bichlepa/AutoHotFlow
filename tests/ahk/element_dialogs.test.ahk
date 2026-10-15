#Requires AutoHotkey v2.0
; Tests for the dialog indirection Dialogs (WI-0051, E0038): every function hands its arguments to the registered
; provider unchanged and returns the answer of the provider. The real dialogs are not opened here (gui test in
; tests/integration/test_dialogs.py).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\elements\base\Dialogs.ahk

; A provider that records the calls and answers with fixed values.
class StubProvider {
    calls := []

    MsgBox(text, title, options) {
        this.calls.Push(["MsgBox", text, title, options])
        return "Yes"
    }

    InputBox(prompt, title, options, default) {
        this.calls.Push(["InputBox", prompt, title, options, default])
        return {Value: "typed", Result: "OK"}
    }

    ToolTip(text, x?, y?, which := 1) {
        this.calls.Push(["ToolTip", text, IsSet(x) ? x : "unset", IsSet(y) ? y : "unset", which])
    }

    FileSelect(options, root, title, filter) {
        this.calls.Push(["FileSelect", options, root, title, filter])
        return "C:\file.txt"
    }

    DirSelect(root, options, prompt) {
        this.calls.Push(["DirSelect", root, options, prompt])
        return "C:\dir"
    }
}

TestRun.Init()

TestRun.Case("every function passes its arguments on and returns the answer of the provider", () => (
    p := StubProvider(),
    Dialogs.UseProvider(p),
    Assert.Equal(Dialogs.MsgBox("t", "ti", "YesNo"), "Yes"),
    r := Dialogs.InputBox("p", "ti", "T5", "d"),
    Assert.Equal(r.Value, "typed"),
    Assert.Equal(r.Result, "OK"),
    Dialogs.ToolTip("hint", 10),
    Assert.Equal(Dialogs.FileSelect("M", "C:\", "pick", "*.txt"), "C:\file.txt"),
    Assert.Equal(Dialogs.DirSelect("C:\", 3, "dir?"), "C:\dir"),
    Assert.Equal(p.calls[1][4], "YesNo"),
    Assert.Equal(p.calls[2][5], "d"),
    Assert.Equal(p.calls[3][4], "unset", "an omitted y stays omitted"),
    Assert.Equal(p.calls[3][3], 10),
    Assert.Equal(p.calls[3][5], 1, "the default tooltip number"),
    Assert.Equal(p.calls[5][3], 3),
    Dialogs.UseProvider("")
))

TestRun.Case("a provider is replaced and removed again", () => (
    Dialogs.UseProvider(StubProvider()),
    Assert.True(IsObject(Dialogs.provider)),
    Dialogs.UseProvider(""),
    Assert.Equal(Dialogs.provider, "")
))

TestRun.Finish()
