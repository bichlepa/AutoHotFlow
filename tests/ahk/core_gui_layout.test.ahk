#Requires AutoHotkey v2.0
; Unit tests for src/core/GuiLayout.ahk (REQ-USE-090; moved from DialogWindow in WI-0069): the scaling of the sizes and
; the check that a remembered position is on a monitor. No window is created here (the windows are in the gui tier).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\core\GuiLayout.ahk

TestRun.Init()

TestRun.Case("Scale: 100 % is unchanged", () => (
    lay := Map("dpi", 96),
    Assert.Equal(GuiLayout.Scale(lay, 260), 260)))

TestRun.Case("Scale: 150 % (144 dpi) gives 1.5 times the size", () => (
    lay := Map("dpi", 144),
    Assert.Equal(GuiLayout.Scale(lay, 260), 390),
    Assert.Equal(GuiLayout.Scale(lay, 0), 0)))

TestRun.Case("Scale: 225 % (216 dpi) rounds to whole pixels", () => (
    lay := Map("dpi", 216),
    Assert.Equal(GuiLayout.Scale(lay, 110), 248),
    Assert.Equal(GuiLayout.Scale(lay, 12), 27)))

TestRun.Case("OnScreen: a point at the top left of the primary monitor is on a monitor", () => (
    MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b),
    Assert.True(GuiLayout.OnScreen(l + 40, t + 40), "the primary work area holds its own top left")))

TestRun.Case("OnScreen: a far away point is not on a monitor", () => (
    Assert.True(!GuiLayout.OnScreen(-30000, -30000), "no monitor at -30000,-30000")))

TestRun.Finish()
