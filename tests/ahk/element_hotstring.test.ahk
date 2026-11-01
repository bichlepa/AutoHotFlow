#Requires AutoHotkey v2.0
#SingleInstance Off
; Unit tests for src/elements/Default/Triggers/Trigger_Hotstring.ahk (WI-0131): the hotstring text with its options, the
; replacement text (raw mode), the send mode, the window condition, the variables of a press and the errors of Enable.
; No text is typed here (input tests: test_hotkey_input.py); the hotstrings registered here use unusual texts.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\elements\Default\Triggers\Trigger_Hotstring.ahk

; Parameters as the engine delivers them.
Prm(opts := {}) {
    p := {hotstring: "ahfunit", RequireEndingCharacter: 1, OmitEndingCharacter: 0, TriggerInsideAnotherWord: 0
        , CaseSensitive: 0, AutomaticBackspacing: 1, ResetRecognizer: 0, RawMode: 0, KeysToSend: "", SendMode: "Input"
        , UseWindow: "Everywhere", TitleMatchMode: 1, Wintitle: "", excludeTitle: "", winText: "", ExcludeText: ""
        , ahk_class: "", ahk_exe: "", ahk_id: "", ahk_pid: "", FindHiddenText: 0, FindHiddenWindow: 0}
    for key, value in opts.OwnProps()
        p.%key% := value
    return p
}

; The parts of the trigger context that Enable and Disable use.
class FakeHotCtx {
    State := {}
    Guard(fn) => fn
    Fire(*) => ""
}

Case1() {
    ; The options in the order of the v1 code: * (no ending character), ?, C, B0, Z.
    Assert.Equal(Trigger_Hotstring.FullText(Prm()), ":" ":" "ahfunit")
    Assert.Equal(Trigger_Hotstring.FullText(Prm({RequireEndingCharacter: 0})), ":*:ahfunit")
    Assert.Equal(Trigger_Hotstring.FullText(Prm({TriggerInsideAnotherWord: 1, CaseSensitive: 1})), ":?C:ahfunit")
    Assert.Equal(Trigger_Hotstring.FullText(Prm({AutomaticBackspacing: 0})), ":B0:ahfunit")
    Assert.Equal(Trigger_Hotstring.FullText(Prm({ResetRecognizer: 1, RequireEndingCharacter: 0})), ":*Z:ahfunit")
    Assert.Equal(Trigger_Hotstring.FullText(Prm({RequireEndingCharacter: "false"})), ":*:ahfunit", "false is off")
    e := Assert.Throws(() => Trigger_Hotstring.FullText(Prm({hotstring: ""})), ElementError, "empty text")
    Assert.True(InStr(e.Message, "cannot be set"), "the v1 text")
}

Case2() {
    Assert.Equal(Trigger_Hotstring.KeysOf(Prm({KeysToSend: "by the way"})), "by the way")
    Assert.Equal(Trigger_Hotstring.KeysOf(Prm({KeysToSend: "{Enter}", RawMode: 1})), "{Raw}{Enter}", "raw mode")
    Assert.Equal(Trigger_Hotstring.KeysOf(Prm({KeysToSend: ""})), "", "nothing is sent")
    Assert.Equal(Trigger_Hotstring.SendModeOf(Prm({SendMode: "Event"})), "Event")
    Assert.Equal(Trigger_Hotstring.SendModeOf(Prm({SendMode: "Play"})), "Play")
    Assert.Throws(() => Trigger_Hotstring.SendModeOf(Prm({SendMode: "Post"})), ElementError, "unknown send mode")
}

Case3() {
    Assert.Equal(Trigger_Hotstring.ModeOf(Prm({UseWindow: "WindowIsActive"})), "WindowIsActive")
    Assert.Equal(Trigger_Hotstring.ModeOf(Prm({UseWindow: 1})), "Everywhere", "v1 radio index")
    Assert.Throws(() => Trigger_Hotstring.ModeOf(Prm({UseWindow: "Somewhere"})), ElementError, "unknown UseWindow")
}

Case4() {
    v := Trigger_Hotstring.TriggerVariables(Prm({hotstring: "btw"}), Map("endChar", " "))
    Assert.Equal(v["A_EndChar"], " ")
    Assert.Equal(v["A_Hotstring"], "btw")
    Assert.Equal(Trigger_Hotstring.TriggerVariables(Prm({hotstring: "btw"}), "")["A_EndChar"], "", "no data")
    Assert.Equal(Trigger_Hotstring.GenerateName(FakeHotCtx(), Prm({hotstring: "btw", KeysToSend: "by the way"})),
        "Hotstring - btw - by the way")
}

Case5() {
    ; Enable with a bad window value is refused before anything is registered; Disable after that is harmless.
    ctx := FakeHotCtx()
    Assert.Throws(() => Trigger_Hotstring.Enable(ctx, Prm({UseWindow: "Somewhere"})), ElementError, "bad window")
    Trigger_Hotstring.Disable(ctx)
    Assert.Equal(Trigger_Hotstring._regs.Count, 0, "nothing registered")
}

Case6() {
    ; Two triggers with the same hotstring share one registration; the last Disable turns it off.
    a := FakeHotCtx()
    b := FakeHotCtx()
    p := Prm({hotstring: "ahfsharetest", KeysToSend: "one"})
    Trigger_Hotstring.Enable(a, p)
    Trigger_Hotstring.Enable(b, Prm({hotstring: "ahfsharetest", KeysToSend: "two"}))
    key := a.State.regKey
    Assert.Equal(Trigger_Hotstring._regs.Count, 1, "one registration")
    Assert.Equal(Trigger_Hotstring._regs[key]["entries"].Length, 2, "both triggers armed on it")
    Trigger_Hotstring.Disable(a)
    Assert.Equal(Trigger_Hotstring._regs[key]["entries"].Length, 1, "the other one stays")
    Trigger_Hotstring.Disable(b)
    Assert.Equal(Trigger_Hotstring._regs.Has(key), false, "the last Disable removes the registration")
}

TestRun.Case("FullText: the options in the order of v1; an empty text is refused", Case1)
TestRun.Case("KeysOf, SendModeOf: the raw prefix and the send modes", Case2)
TestRun.Case("ModeOf: the window values", Case3)
TestRun.Case("TriggerVariables and GenerateName", Case4)
TestRun.Case("Enable: an unknown window value is refused and nothing is registered", Case5)
TestRun.Case("Registration: two triggers on one hotstring share it; the last Disable removes it", Case6)

TestRun.Finish()
