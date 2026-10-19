#Requires AutoHotkey v2.0
#SingleInstance Off
; Unit tests of the settings dialog and the about window of the manager (WI-0078) with real controls, never shown: the windows
; are made and read, the model is a fake that records what the OK button sends. The window is not shown (no user is needed),
; the look is checked by the gui test and the manual check (doc/MANUAL-CHECKS.md, section 8).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\manager\SettingsWindow.ahk
#Include ..\..\src\manager\AboutWindow.ahk

; The model of the dialog: the settings of the engine and a SetSettings that answers at once (ok, or a refusal when refuse is set).
class FakeSettingsModel {
    settings := ""
    sent := ""
    refuse := false

    __New() {
        this.settings := SettingsModel.Defaults()
        this.settings["userLevel"] := "Beginner"
        this.settings["workers"] := 8
    }

    SetSettings(partial, done := "") {
        this.sent := partial
        answer := this.refuse ? Map("ok", false, "code", "internal", "message", "no write") : Map("ok", true, "code", "", "message", "")
        if (IsObject(done))
            done(answer)
    }
}

; Opens the dialog the way Show does, without showing it: the values of the engine, and the values at open (OK sends the changes).
OpenAt(win, model) {
    win.Fill(model.settings)
    win.opened := win.Read()
}

; The control of a key of the dialog.
CtlOf(win, key) => win.ctl[key]

OpensWithTheSettingsOfTheEngine() {
    model := FakeSettingsModel()
    win := SettingsWindow(model)
    try {
        win.Fill(model.settings)
        Assert.Equal(CtlOf(win, "workers").Value, "8", "the workers of the engine")
        Assert.Equal(CtlOf(win, "userLevel").Value, 1, "Beginner is the first item")
        Assert.Equal(CtlOf(win, "language").Value, 1, "the language of Windows is the first item")
        Assert.Equal(win.Read()["workers"], "8")
        Assert.Equal(win.Read()["language"], "")
        Assert.True(!win.Visible, "not shown by the test")
    } finally {
        win.Close()
    }
}

; The controls of one tab never overlap (at 100 % and at 225 %, the layout applied without a show), and a checkbox ends before
; the note column: a checkbox wider than its text painted over the note on hover.
ControlsOfATabDoNotOverlap() {
    model := FakeSettingsModel()
    win := SettingsWindow(model)
    try {
        for dpi in [96, 216] {
            GuiLayout.Apply(win.win.lay, dpi)
            for tab in SettingsForm.TABS {
                span := win.tabItems[tab["id"]]
                rects := []
                loop span[2] - span[1] + 1 {
                    ctl := win.win.lay["items"][span[1] + A_Index - 1][1]
                    ctl.GetPos(&x, &y, &w, &h)
                    rects.Push(Map("l", x, "t", y, "r", x + w, "b", y + h))
                }
                for a in rects {
                    for b in rects {
                        if (a != b && RectsOverlap(a, b))
                            Assert.True(false, "dpi " dpi ", tab " tab["id"] ": two controls overlap: " a["l"] "," a["t"] " "
                                . a["r"] "," a["b"] " and " b["l"] "," b["t"] " " b["r"] "," b["b"])
                    }
                }
            }
            noteX := GuiLayout.Scale(win.win.lay, SettingsWindow.NOTE_X)
            for key in ["notifyUnhandledErrors", "startWithWindows", "runAsAdmin"] {
                CtlOf(win, key).GetPos(&x, , &w)
                Assert.True(x + w <= noteX, "dpi " dpi ": the checkbox " key " ends before the note column: " (x + w) " > " noteX)
            }
        }
    } finally {
        win.Close()
    }
}

; True when two rectangles (Map l, t, r, b) share an area.
RectsOverlap(a, b) => a["l"] < b["r"] && b["l"] < a["r"] && a["t"] < b["b"] && b["t"] < a["b"]

; OK with a refused value keeps the dialog open, names the value in the status line and sends nothing.
RefusedValueStaysAndSendsNothing() {
    model := FakeSettingsModel()
    win := SettingsWindow(model)
    try {
        win.Fill(model.settings)
        CtlOf(win, "workers").Value := "17"
        win.OnOk()
        Assert.True(InStr(win.statusCtl.Text, "1 to 16") > 0, "the status names the range: " win.statusCtl.Text)
        Assert.True(InStr(win.statusCtl.Text, "Elements waiting at the same time") > 0, "the status names the value")
        Assert.True(model.sent = "", "nothing was sent")
        Assert.True(!win.done, "the dialog stays open")
    } finally {
        win.Close()
    }
}

; OK with valid values sends the checked set; a saved set closes the dialog.
ValidValuesAreSentAndTheDialogCloses() {
    model := FakeSettingsModel()
    win := SettingsWindow(model)
    try {
        OpenAt(win, model)
        CtlOf(win, "workers").Value := "4"
        CtlOf(win, "logLevelThread").Choose(4)            ; All logs
        win.OnOk()
        Assert.Equal(model.sent["workers"], 4)
        Assert.Equal(model.sent["logLevelThread"], 3)
        Assert.Equal(model.sent.Count, 2, "only the two keys the user changed are sent")
        Assert.True(win.done, "a saved set closes the dialog")
    } finally {
        win.Close()
    }
}

; A refusal of the engine stays in the dialog with its message.
EngineRefusalStaysInTheDialog() {
    model := FakeSettingsModel()
    model.refuse := true
    win := SettingsWindow(model)
    try {
        win.Fill(model.settings)
        win.OnOk()
        Assert.True(!win.done, "a refusal keeps the dialog")
        Assert.True(InStr(win.statusCtl.Text, "no write") > 0, win.statusCtl.Text)
    } finally {
        win.Close()
    }
}

; A change of the language makes the dialog again with the values the user typed.
RelabelKeepsTheTypedValues() {
    model := FakeSettingsModel()
    win := SettingsWindow(model)
    try {
        win.Fill(model.settings)
        CtlOf(win, "userLevel").Choose(3)                 ; Programmer
        CtlOf(win, "workers").Value := "5"
        win.Relabel()
        Assert.Equal(win.Read()["userLevel"], "Programmer", "the choice is kept")
        Assert.Equal(win.Read()["workers"], "5", "the typed value is kept")
        Assert.True(!win.done)
    } finally {
        win.Close()
    }
}

; OK without a change sends nothing and closes the dialog.
PlainOkSendsNothing() {
    model := FakeSettingsModel()
    win := SettingsWindow(model)
    try {
        OpenAt(win, model)
        win.OnOk()
        Assert.True(model.sent = "", "no key was changed: nothing is sent")
        Assert.True(win.done, "the dialog closes")
    } finally {
        win.Close()
    }
}

; A language code that the program does not list stays selected and is sent as it is.
UnlistedLanguageIsKept() {
    model := FakeSettingsModel()
    model.settings["language"] := "fr"
    win := SettingsWindow(model)
    try {
        OpenAt(win, model)
        Assert.Equal(win.Read()["language"], "fr", "the unlisted code is shown, not replaced by the language of Windows")
        CtlOf(win, "workers").Value := "5"
        win.OnOk()
        Assert.Equal(model.sent.Count, 1, "only the workers are sent")
        Assert.True(!model.sent.Has("language"), "the language is not part of the set")
    } finally {
        win.Close()
    }
}

; The refusal field shows every refused value on its own line; its height is the one of four measured lines.
RefusalFieldShowsEveryValue() {
    model := FakeSettingsModel()
    win := SettingsWindow(model)
    try {
        OpenAt(win, model)
        CtlOf(win, "workers").Value := "17"
        CtlOf(win, "maxParallelInstances").Value := "-1"
        win.OnOk()
        Assert.True(InStr(win.statusCtl.Text, "`r`n") > 0, "one line per value")
        Assert.True(InStr(win.statusCtl.Text, "1 to 16") > 0 && InStr(win.statusCtl.Text, "0 to 1000000") > 0, win.statusCtl.Text)
        for item in win.win.lay["items"] {
            if (item[1] = win.statusCtl)
                Assert.True(item[5] >= 40, "the field has the height of about four lines: " item[5])
        }
    } finally {
        win.Close()
    }
}

; The dialog is made in German with its texts measured: no error, the same values.
GermanDialogIsMade() {
    model := FakeSettingsModel()
    LangTable.Code := "de"
    LangTable.Load()
    try {
        win := SettingsWindow(model)
        try {
            OpenAt(win, model)
            Assert.Equal(win.Read()["workers"], "8", "the values are kept in German")
        } finally {
            win.Close()
        }
    } finally {
        LangTable.Code := "en"
        LangTable.Load()
    }
}

; An answer of the engine that comes after the close box is ignored: the window is gone.
AnswerAfterTheCloseBoxIsIgnored() {
    model := FakeSettingsModel()
    win := SettingsWindow(model)
    OpenAt(win, model)
    win.win.Close()                                    ; what the close box does (UiWindow), done stays false
    win._Answered(Map("ok", false, "code", "internal", "message", "late refusal"))
    win._Answered(Map("ok", true, "code", "", "message", ""))
    Assert.True(!win._Alive(), "the window is gone and nothing touched it")
}

; A change of the language keeps a refused value as typed and the refusal in the status line.
RelabelKeepsARefusedValueAndTheStatus() {
    model := FakeSettingsModel()
    win := SettingsWindow(model)
    try {
        win.Fill(model.settings)
        CtlOf(win, "workers").Value := "17"
        win.OnOk()
        win.Relabel()
        Assert.Equal(win.Read()["workers"], "17", "the typed value is not replaced by the default")
        Assert.True(InStr(win.statusCtl.Text, "1 to 16") > 0, "the refusal is still shown: " win.statusCtl.Text)
        Assert.True(model.sent = "", "still nothing was sent")
    } finally {
        win.Close()
    }
}

; The language list starts with the language of Windows and has the languages of the program.
LanguageListHasWindowsLanguageFirst() {
    model := FakeSettingsModel()
    win := SettingsWindow(model)
    try {
        Assert.Equal(win.codes[1], "", "the first code is the language of Windows")
        Assert.True(win.codes.Length >= 2, "the program has at least two languages")
    } finally {
        win.Close()
    }
}

; The about window shows the version of AutoHotFlow and of AutoHotkey, the license and the site (not shown).
AboutShowsVersionsLicenseAndSite() {
    win := AboutWindow()
    try {
        joined := ""
        for ctl in win.lines
            joined .= ctl.Text "`n"
        Assert.True(InStr(joined, AhfVersion.Current) > 0, "the version of AutoHotFlow")
        Assert.True(InStr(joined, A_AhkVersion) > 0, "the version of AutoHotkey")
        Assert.True(InStr(joined, "GNU General Public License 3") > 0, "the license")
        Assert.True(InStr(joined, AboutWindow.SITE) > 0, "the project site")
        Assert.True(!win.Visible, "not shown by the test")
    } finally {
        win.Close()
    }
}

TestRun.Init()
TestRun.Case("The dialog opens with the settings of the engine and the language of Windows first", OpensWithTheSettingsOfTheEngine)
TestRun.Case("The controls of a tab do not overlap, and a checkbox ends before the note column, at 100 % and 225 %", ControlsOfATabDoNotOverlap)
TestRun.Case("OK with a refused value stays open, names the value and sends nothing", RefusedValueStaysAndSendsNothing)
TestRun.Case("OK with valid values sends the checked set and closes the dialog", ValidValuesAreSentAndTheDialogCloses)
TestRun.Case("A refusal of the engine stays in the dialog with its message", EngineRefusalStaysInTheDialog)
TestRun.Case("A change of the language keeps the values the user typed", RelabelKeepsTheTypedValues)
TestRun.Case("OK without a change sends nothing and closes the dialog", PlainOkSendsNothing)
TestRun.Case("A language code the program does not list is kept", UnlistedLanguageIsKept)
TestRun.Case("The refusal field shows every refused value, four lines high", RefusalFieldShowsEveryValue)
TestRun.Case("The dialog is made in German with measured heights", GermanDialogIsMade)
TestRun.Case("An answer after the close box is ignored", AnswerAfterTheCloseBoxIsIgnored)
TestRun.Case("A change of the language keeps a refused value and the refusal in the status", RelabelKeepsARefusedValueAndTheStatus)
TestRun.Case("The language list starts with the language of Windows", LanguageListHasWindowsLanguageFirst)
TestRun.Case("The about window has the versions, the license and the project site", AboutShowsVersionsLicenseAndSite)
TestRun.Finish()
