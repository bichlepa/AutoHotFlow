#Requires AutoHotkey v2.0
#SingleInstance Off
; Unit tests for src/elements/Default/lib/WindowIdent.ahk (WI-0064, E0060): the window identification of the window
; elements and triggers. The windows are hidden windows of this process (no window shows, no focus changes).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\elements\Default\lib\WindowIdent.ahk

; A hidden test window with a unique title; returns the Gui (keep it alive while the case runs).
HiddenWindow(title) {
    g := Gui("+AlwaysOnTop -Caption", title)
    g.Show("Hide")
    return g
}

; The parameters as the engine delivers them: an object with the names of the parameters.
P(opts := {}) {
    prm := {TitleMatchMode: 1, Wintitle: "", excludeTitle: "", winText: "", ExcludeText: "", ahk_class: "", ahk_exe: ""
        , ahk_id: "", ahk_pid: "", FindHiddenText: 0, FindHiddenWindow: 0}
    for key, value in opts.OwnProps()
        prm.%key% := value
    return prm
}

Case1() {
    spec := WindowIdent.Spec(P({Wintitle: "Notepad", ahk_class: "Edit", ahk_exe: "notepad.exe"}))
    Assert.Equal(spec["winString"], "Notepad ahk_class Edit ahk_exe notepad.exe")
    Assert.Equal(spec["TitleMatchMode"], 1)
    Assert.Equal(spec["FindHiddenWindow"], 0)
    spec2 := WindowIdent.Spec(P({winText: "Save"}))
    Assert.Equal(spec2["winString"], "")
    Assert.Equal(spec2["winText"], "Save")
}

Case2() {
    e := Assert.Throws(() => WindowIdent.Spec(P()), ElementError, "no window")
    Assert.Equal(e.Message, "No window specified")
    Assert.Throws(() => WindowIdent.Spec(P({FindHiddenWindow: "maybe"})), ElementError, "checkbox value")
    Assert.Throws(() => WindowIdent.Spec(P({TitleMatchMode: 7, Wintitle: "x"})), ElementError, "match mode")
}

Case3() {
    title := "AhfWindowIdentTest-A-" A_TickCount
    g := HiddenWindow(title)
    hidden := WindowIdent.Spec(P({Wintitle: title, FindHiddenWindow: 1}))
    Assert.True(WindowIdent.Find(hidden) != 0, "a hidden window is found when detection is on")
    Assert.Equal(WindowIdent.Find(WindowIdent.Spec(P({Wintitle: title}))), 0, "a hidden window is not found by default")
    Assert.True(!WindowIdent.IsActive(hidden), "a hidden window is never the active one")
    g.Destroy()
}

Case4() {
    title := "AhfWindowIdentTest-B-" A_TickCount
    g := HiddenWindow(title)
    partial := WindowIdent.Spec(P({Wintitle: "AhfWindowIdentTest-B", TitleMatchMode: 3, FindHiddenWindow: 1}))
    Assert.Equal(WindowIdent.Find(partial), 0, "exact match does not find a longer title")
    midTitle := WindowIdent.Spec(P({Wintitle: "AhfWindowIdentTest-B", TitleMatchMode: 2, FindHiddenWindow: 1}))
    Assert.True(WindowIdent.Find(midTitle) != 0, "contains anywhere finds the title")
    beginning := WindowIdent.Spec(P({Wintitle: "AhfWindowIdentTest-B", TitleMatchMode: 1, FindHiddenWindow: 1}))
    Assert.True(WindowIdent.Find(beginning) != 0, "start with finds the title")
    excluded := WindowIdent.Spec(P({Wintitle: "AhfWindowIdentTest-B", excludeTitle: title, FindHiddenWindow: 1}))
    Assert.Equal(WindowIdent.Find(excluded), 0, "an exclude title removes the window")
    g.Destroy()
}

Case5() {
    ; The window ID of the hidden window identifies it exactly (ahk_id), and the process ID of this process matches it.
    title := "AhfWindowIdentTest-C-" A_TickCount
    g := HiddenWindow(title)
    id := g.Hwnd
    byId := WindowIdent.Spec(P({ahk_id: id, FindHiddenWindow: 1}))
    Assert.True(WindowIdent.Find(byId) != 0, "ahk_id finds the window")
    byPid := WindowIdent.Spec(P({Wintitle: title, ahk_pid: ProcessExist(), FindHiddenWindow: 1}))
    Assert.True(WindowIdent.Find(byPid) != 0, "ahk_pid of this process matches")
    wrongPid := WindowIdent.Spec(P({Wintitle: title, ahk_pid: 0, FindHiddenWindow: 1}))
    Assert.Equal(WindowIdent.Find(wrongPid), 0, "another process ID does not match")
    g.Destroy()
}

Case6() {
    ; The parameter list: the excludes are left out with noExcludes (UseWindow of a hotkey, v1 option).
    withEx := WindowIdent.AddIdentificationParameters([], {})
    noEx := WindowIdent.AddIdentificationParameters([], {noExcludes: true})
    Assert.True(HasId(withEx, "excludeTitle") && HasId(withEx, "ExcludeText"), "excludes are listed by default")
    Assert.True(!HasId(noEx, "excludeTitle") && !HasId(noEx, "ExcludeText"), "noExcludes leaves them out")
    Assert.True(HasId(noEx, "GetWindowInformation") && HasId(noEx, "FindHiddenWindow"), "other parameters stay")
}

HasId(list, id) {
    for item in list {
        if (item.HasProp("id") && item.id = id)
            return true
    }
    return false
}

TestRun.Case("Spec: the WinExist text of the parameters and the defaults", Case1)
TestRun.Case("Spec: no window and invalid values are refused with the v1 texts", Case2)
TestRun.Case("Find: a hidden window is found only with hidden detection and is never active", Case3)
TestRun.Case("Find: title match modes and the exclude title", Case4)
TestRun.Case("Find: ahk_id and ahk_pid", Case5)
TestRun.Case("Parameters: the excludes follow the noExcludes option", Case6)

TestRun.Finish()
