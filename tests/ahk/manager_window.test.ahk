#Requires AutoHotkey v2.0
; Unit test of the redraw decision of src/manager/ManagerWindow.ahk (WI-0073, owner decision 2026-10-17): the window is redrawn
; only while it is visible and only when something changed since the last redraw. No window is created here.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\manager\ManagerWindow.ahk

TestRun.Init()

TestRun.Case("Redraw only when visible and changed", () => (
    Assert.True(ManagerWindow.ShouldRedraw(true, true)),
    Assert.True(!ManagerWindow.ShouldRedraw(true, false), "nothing changed"),
    Assert.True(!ManagerWindow.ShouldRedraw(false, true), "hidden"),
    Assert.True(!ManagerWindow.ShouldRedraw(false, false))))

; The Yes/No order of every question of the manager is "Yes" left, "No" right (owner request, 2026-10-17). The questions
; preselected "No" (importCopies, autostartV1, importWarning) keep that order and only move the default button to No.
ConfirmOrderIsYesThenNo() {
    for kind in ["independent", "force", "delete", "categoryDelete", "rename", "importCopies", "autostartV1",
        "importWarning"] {
        buttons := ManagerWindow.ConfirmButtons(kind)
        Assert.Equal(buttons[1][1], "yes", kind ": Yes is the first (left) button")
        Assert.Equal(buttons[2][1], "no", kind ": No is the second (right) button")
    }
}

ConfirmDefaultFollowsPreselection() {
    for kind in ["importCopies", "autostartV1", "importWarning"]
        Assert.Equal(UiDialogs.DefaultIndex(ManagerWindow.ConfirmButtons(kind)), 2, kind ": the default is No")
    for kind in ["independent", "force", "delete", "categoryDelete", "rename"]
        Assert.Equal(UiDialogs.DefaultIndex(ManagerWindow.ConfirmButtons(kind)), 1, kind ": the default is Yes")
}

TestRun.Case("Confirm: Yes is left of No in every question of the manager", ConfirmOrderIsYesThenNo)
TestRun.Case("Confirm: a question preselected No has No as default, the others Yes", ConfirmDefaultFollowsPreselection)

TestRun.Finish()
