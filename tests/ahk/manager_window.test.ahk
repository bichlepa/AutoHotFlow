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

TestRun.Finish()
