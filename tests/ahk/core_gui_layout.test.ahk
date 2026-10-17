#Requires AutoHotkey v2.0
; Unit tests for src/core/GuiLayout.ahk (REQ-USE-090; moved from DialogWindow in WI-0069): the scaling of the sizes, the
; check that a remembered position is on a monitor, and the measured height of a text. No window is shown here (the windows
; are in the gui tier); a hidden Gui is only the DC for the measurement.
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

; TextHeight measures the text as a Text control wraps it (F-9000*): a long text is more lines than one, a newline adds a
; line, and a narrower width gives more lines. A hidden Gui is enough (nothing is shown).
TestRun.Case("TextHeight: a wrapped text counts every line, not only its newlines", () => (
    g := Gui("-DPIScale"),
    one := GuiLayout.TextHeight(g, "Ag", 356),
    long := GuiLayout.TextHeight(g, "Delete the flow Flow X? This is final: the flow, its enabled state and its static variables are removed.", 356),
    g.Destroy(),
    Assert.True(one > 0 && one < 25, "one line is a line (got " one ")"),
    Assert.True(long >= 2 * one, "the wrapped text needs two lines or more (got " long ", one line " one ")")))

TestRun.Case("TextHeight: each newline is a line", () => (
    g := Gui("-DPIScale"),
    one := GuiLayout.TextHeight(g, "Ag", 356),
    three := GuiLayout.TextHeight(g, "a`nb`nc", 356),
    g.Destroy(),
    Assert.True(three >= 3 * one, "three lines (got " three ", one line " one ")")))

TestRun.Case("TextHeight: a narrower width gives more lines", () => (
    g := Gui("-DPIScale"),
    wide := GuiLayout.TextHeight(g, "one two three four five six seven eight nine ten eleven twelve", 356),
    narrow := GuiLayout.TextHeight(g, "one two three four five six seven eight nine ten eleven twelve", 120),
    g.Destroy(),
    Assert.True(narrow > wide, "the narrow text is taller (" narrow " > " wide ")")))

TestRun.Finish()
