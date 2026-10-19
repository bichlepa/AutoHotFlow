#Requires AutoHotkey v2.0
#SingleInstance Off
; Unit tests of the settings dialog and the about window of the manager (WI-0078) with real controls, never shown: the windows
; are made and read, the model is a fake that records what the OK button sends. The window is not shown (no user is needed),
; the look is checked by the gui test and the manual check (doc/MANUAL-CHECKS.md, section 6).
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
        win.Fill(model.settings)
        CtlOf(win, "workers").Value := "4"
        CtlOf(win, "logLevelThread").Choose(4)            ; All logs
        win.OnOk()
        Assert.Equal(model.sent["workers"], 4)
        Assert.Equal(model.sent["logLevelThread"], 3)
        Assert.Equal(model.sent.Count, SettingsForm.Keys().Length, "every field of the dialog is sent, checked")
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
TestRun.Case("OK with a refused value stays open, names the value and sends nothing", RefusedValueStaysAndSendsNothing)
TestRun.Case("OK with valid values sends the checked set and closes the dialog", ValidValuesAreSentAndTheDialogCloses)
TestRun.Case("A refusal of the engine stays in the dialog with its message", EngineRefusalStaysInTheDialog)
TestRun.Case("A change of the language keeps the values the user typed", RelabelKeepsTheTypedValues)
TestRun.Case("The language list starts with the language of Windows", LanguageListHasWindowsLanguageFirst)
TestRun.Case("The about window has the versions, the license and the project site", AboutShowsVersionsLicenseAndSite)
TestRun.Finish()
