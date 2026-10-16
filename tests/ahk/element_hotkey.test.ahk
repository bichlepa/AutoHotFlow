#Requires AutoHotkey v2.0
#SingleInstance Off
; Unit tests for src/elements/Default/Triggers/Trigger_Hotkey.ahk (WI-0064): the hotkey text of the options, the
; window condition of each UseWindow value, the errors of Enable, and the shared registration. Keys are hook hotkeys
; ($vk9x), which several test processes can hold at the same time; no key is pressed here (input tests: test_hotkey_input.py).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\elements\Default\Triggers\Trigger_Hotkey.ahk

; Parameters as the engine delivers them.
Prm(opts := {}) {
    p := {hotkey: "vk97", BlockKey: 1, Wildcard: 0, WhenRelease: 0, UseWindow: "Everywhere", TitleMatchMode: 1
        , Wintitle: "", excludeTitle: "", winText: "", ExcludeText: "", ahk_class: "", ahk_exe: "", ahk_id: ""
        , ahk_pid: "", FindHiddenText: 0, FindHiddenWindow: 0}
    for key, value in opts.OwnProps()
        p.%key% := value
    return p
}

; A context as the trigger host gives it (the parts that Enable and Disable use).
NewCtx() {
    return FakeCtx()
}

; The parts of the trigger context that Enable and Disable use, as methods (a stored lambda would get the object too).
class FakeCtx {
    State := {}
    Guard(fn) => fn
    Fire(*) => ""
}

HiddenWindow(title) {
    g := Gui("+AlwaysOnTop -Caption", title)
    g.Show("Hide")
    return g
}

Case1() {
    ; The combinations of the three options, in the order of v1 (~ first, then UP, then the wildcard).
    expect := [["vk97", 1, 0, 0], ["~vk97", 0, 0, 0], ["vk97 UP", 1, 1, 0], ["~vk97 UP", 0, 1, 0]
        , ["*vk97", 1, 0, 1], ["*~vk97", 0, 0, 1], ["*vk97 UP", 1, 1, 1], ["*~vk97 UP", 0, 1, 1]]
    for row in expect {
        got := Trigger_Hotkey.FullText(Prm({hotkey: "vk97", BlockKey: row[2], WhenRelease: row[3], Wildcard: row[4]}))
        Assert.Equal(got, row[1], "options " row[2] row[3] row[4])
    }
    Assert.Equal(Trigger_Hotkey.FullText(Prm({hotkey: "^!a", BlockKey: "0", WhenRelease: "0", Wildcard: "1"})), "*~^!a")
    Assert.Equal(Trigger_Hotkey.FullText(Prm({hotkey: "F1", BlockKey: "false"})), "~F1")
}

Case2() {
    e := Assert.Throws(() => Trigger_Hotkey.FullText(Prm({hotkey: ""})), ElementError, "empty hotkey")
    Assert.True(InStr(e.Message, "not set"), "the v1 text of an empty hotkey")
    Assert.Throws(() => Trigger_Hotkey.FullText(Prm({hotkey: ""})), ElementError, "again")
}

Case3() {
    Assert.Equal(Trigger_Hotkey.ModeOf(Prm({UseWindow: "Everywhere"})), "Everywhere")
    Assert.Equal(Trigger_Hotkey.ModeOf(Prm({UseWindow: "WindowNotExists"})), "WindowNotExists")
    Assert.Throws(() => Trigger_Hotkey.ModeOf(Prm({UseWindow: "Somewhere"})), ElementError, "unknown UseWindow")
}

Case4() {
    ; The criterion of each window value on a hidden window (exists, not active) and on a window that does not exist.
    title := "AhfHotkeyTest-A-" A_TickCount
    g := HiddenWindow(title)
    spec := WindowIdent.Spec(Prm({Wintitle: title, FindHiddenWindow: 1}))
    absent := WindowIdent.Spec(Prm({Wintitle: title "-absent", FindHiddenWindow: 1}))
    Assert.True(Trigger_Hotkey.Condition("WindowExists", spec).Call("vk97"), "exists: the hidden window exists")
    Assert.True(!Trigger_Hotkey.Condition("WindowNotExists", spec).Call("vk97"), "not exists: the window exists")
    Assert.True(!Trigger_Hotkey.Condition("WindowExists", absent).Call("vk97"), "exists: no such window")
    Assert.True(Trigger_Hotkey.Condition("WindowNotExists", absent).Call("vk97"), "not exists: no such window")
    Assert.True(!Trigger_Hotkey.Condition("WindowIsActive", spec).Call("vk97"), "active: a hidden window is never active")
    Assert.True(Trigger_Hotkey.Condition("WindowIsNotActive", spec).Call("vk97"), "not active: the hidden window")
    Assert.Equal(Trigger_Hotkey.Condition("Everywhere", spec), "", "Everywhere has no criterion")
    g.Destroy()
}

Case5() {
    ; Enable refuses an unknown key name with the v1 text, and a window condition with no window.
    ctx := NewCtx()
    Assert.Throws(() => Trigger_Hotkey.Enable(ctx, Prm({hotkey: "NoSuchKey!!"})), ElementError, "invalid key")
    Assert.Throws(() => Trigger_Hotkey.Enable(ctx, Prm({UseWindow: "WindowExists"})), ElementError, "no window")
    ; Disable after the failed Enable: nothing is registered, nothing happens, no error.
    Trigger_Hotkey.Disable(ctx)
    Assert.Equal(Trigger_Hotkey._regs.Count, 0, "no registration left")
}

Case6() {
    ; Two triggers with the same hotkey and the same condition share one registration; disabling one keeps the other.
    a := NewCtx()
    b := NewCtx()
    msgA := Trigger_Hotkey.Enable(a, Prm({hotkey: "$vk9E"}))
    Assert.True(InStr(msgA, "vk9E") || InStr(msgA, "9E"), "the message names the hotkey")
    Trigger_Hotkey.Enable(b, Prm({hotkey: "$vk9E"}))
    Assert.Equal(Trigger_Hotkey._regs.Count, 1, "one registration for both")
    key := a.State.regKey
    Assert.Equal(Trigger_Hotkey._regs[key]["entries"].Length, 2, "both are in the list")
    Trigger_Hotkey.Disable(a)
    Assert.Equal(Trigger_Hotkey._regs.Count, 1, "the hotkey stays on for the other trigger")
    Assert.Equal(Trigger_Hotkey._regs[key]["entries"].Length, 1, "one entry left")
    Trigger_Hotkey.Disable(b)
    Assert.Equal(Trigger_Hotkey._regs.Count, 0, "the last Disable turns the hotkey off and drops it")
}

Case7() {
    ; Different window conditions on the same key are separate registrations (AHK keeps one variant per criterion).
    title := "AhfHotkeyTest-B-" A_TickCount
    g := HiddenWindow(title)
    a := NewCtx()
    b := NewCtx()
    Trigger_Hotkey.Enable(a, Prm({hotkey: "$vk9D", UseWindow: "WindowExists", Wintitle: title, FindHiddenWindow: 1}))
    Trigger_Hotkey.Enable(b, Prm({hotkey: "$vk9D", UseWindow: "WindowNotExists", Wintitle: title, FindHiddenWindow: 1}))
    Assert.Equal(Trigger_Hotkey._regs.Count, 2, "two conditions, two registrations")
    Trigger_Hotkey.Disable(a)
    Assert.Equal(Trigger_Hotkey._regs.Count, 1, "the other condition stays")
    Trigger_Hotkey.Disable(b)
    Assert.Equal(Trigger_Hotkey._regs.Count, 0, "all off")
    g.Destroy()
}

Case8() {
    ; The variables and the names of the element.
    v := Trigger_Hotkey.TriggerVariables(Prm({hotkey: "^!a"}), Map())
    Assert.Equal(v["A_Hotkey"], "^!a")
    Assert.Equal(Trigger_Hotkey.GenerateName(NewCtx(), Prm({hotkey: "F2"})), "Hotkey - F2")
}

TestRun.Case("FullText: the options give the text of v1 in its order", Case1)
TestRun.Case("FullText: an empty hotkey is refused with the v1 text", Case2)
TestRun.Case("ModeOf: the window values, an unknown one is refused", Case3)
TestRun.Case("Condition: each window value on a hidden window and on a missing one", Case4)
TestRun.Case("Enable: invalid key and missing window are refused; Disable after that is harmless", Case5)
TestRun.Case("Registration: two triggers on one hotkey share it; the last Disable turns it off", Case6)
TestRun.Case("Registration: other window conditions are other registrations", Case7)
TestRun.Case("TriggerVariables and GenerateName", Case8)

TestRun.Finish()
