#Requires AutoHotkey v2.0
; Unit tests for the model of the settings dialog (WI-0078, REQ-SET-010, REQ-LNG-020): src/manager/SettingsForm.ahk (the keys
; of the dialog, the check of the values the controls give) and LangTable.Languages (the languages of the program, the list
; of the language drop-down). No window is created here.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\core\LangTable.ahk
#Include ..\..\src\manager\SettingsForm.ahk

; The keys of the dialog are settings of the model; the window positions, start with Windows and run as administrator are not
; in the dialog (WI-0079 comes with them).
DialogKeys() {
    for key in SettingsForm.Keys()
        Assert.True(SettingsModel.Has(key), key ": a key of the dialog is a setting")
    for key in ["windowPositions", "startWithWindows", "runAsAdmin"]
        Assert.True(SettingsForm.FieldOf(key) = "", key ": not in the dialog")
    Assert.Equal(SettingsForm.FieldsOf("general").Length + SettingsForm.FieldsOf("flow").Length
        + SettingsForm.FieldsOf("debug").Length, SettingsForm.Keys().Length, "every field is on a tab")
}

; A valid set of the controls: the texts are checked into the values of the model (numbers, 1/0, the language in lower case).
ValidSetIsChecked() {
    raw := Map("workers", "4", "logLevelApp", "3", "notifyUnhandledErrors", 0, "language", "DE", "executionPolicy", "skip"
        , "maxExecutionsPerMinute", "0", "userLevel", "Advanced")
    res := SettingsForm.Collect(raw)
    Assert.True(res["ok"], "all values are valid")
    Assert.Equal(res["partial"]["workers"], 4)
    Assert.Equal(res["partial"]["logLevelApp"], 3)
    Assert.Equal(res["partial"]["notifyUnhandledErrors"], 0)
    Assert.Equal(res["partial"]["language"], "de")
    Assert.Equal(res["partial"]["executionPolicy"], "skip")
    Assert.Equal(res["partial"]["maxExecutionsPerMinute"], 0, "0 is no limit")
    Assert.Equal(res["partial"]["userLevel"], "Advanced")
    Assert.Equal(res["partial"].Count, 7, "only the keys that were given")
}

; A refused value names its key and carries the message of the check; the other values are refused too (nothing is sent).
RefusedValuesAreNamed() {
    res := SettingsForm.Collect(Map("workers", "17", "logLevelFlow", "7", "executionPolicy", "sometimes", "userLevel", "Beginner"))
    Assert.True(!res["ok"], "a refused value refuses the set")
    Assert.Equal(res["errors"].Count, 3, "every refused value is listed")
    Assert.True(InStr(res["errors"]["workers"], "1 to 16") > 0, "the message names the range: " res["errors"]["workers"])
    Assert.True(InStr(res["errors"]["logLevelFlow"], "0 to 3") > 0, res["errors"]["logLevelFlow"])
    Assert.True(InStr(res["errors"]["executionPolicy"], "parallel") > 0, res["errors"]["executionPolicy"])
    Assert.True(!res["errors"].Has("userLevel"), "a valid value is not listed")
}

; A key the dialog does not show is refused by name, not sent: the autostart keys belong to WI-0079.
NotADialogKeyIsRefused() {
    res := SettingsForm.Collect(Map("startWithWindows", 1))
    Assert.True(!res["ok"])
    Assert.True(InStr(res["errors"]["startWithWindows"], "not a setting of the dialog") > 0, res["errors"]["startWithWindows"])
    Assert.True(!SettingsForm.Collect("text")["ok"], "the values must be a Map")
}

; The error text: one line per refused value, with the label of the key.
ErrorTextHasOneLinePerValue() {
    errors := Map("workers", "must be a whole number from 1 to 16", "language", "must be empty or a language code of 2 or 3 letters")
    text := SettingsForm.ErrorText(errors, (key) => "<" key ">")
    Assert.Equal(text, "<language>: must be empty or a language code of 2 or 3 letters`n<workers>: must be a whole number from 1 to 16",
        "the lines follow the order of the dialog")
}

; The language list: the codes of the folder basic with the names of their [language_info] lines, sorted by code.
; The files are written by the test (UTF-16 as the files of v1 are); a missing name line gives the code.
LanguagesAreListedWithTheirNames() {
    dir := A_Temp "\ahf_settings_form_test_" DllCall("GetCurrentProcessId")
    if (DirExist(dir))
        DirDelete(dir, true)
    DirCreate(dir "\basic")
    FileAppend("[language_info]`r`nenname=German`r`nname=Deutsch`r`n[common]`r`nX=y`r`n", dir "\basic\de.ini", "UTF-16")
    FileAppend("[language_info]`r`nenname=English`r`n[common]`r`nX=y`r`n", dir "\basic\en.ini", "UTF-16")
    FileAppend("[common]`r`nX=y`r`n", dir "\basic\ru.ini", "UTF-16")
    LangTable.Dir := dir
    LangTable.PackagesDir := dir "\no_packages"
    try {
        list := LangTable.Languages()
        Assert.Equal(list.Length, 3)
        Assert.Equal(list[1][1], "de")
        Assert.Equal(list[1][2], "Deutsch", "the name= line, not enname=")
        Assert.Equal(list[2][1], "en")
        Assert.Equal(list[2][2], "en", "no name line: the code")
        Assert.Equal(list[3][1], "ru")
    } finally {
        LangTable.Dir := ""
        LangTable.PackagesDir := ""
        DirDelete(dir, true)
    }
}

TestRun.Init()
TestRun.Case("The keys of the dialog are the settings, without the positions and the autostart", DialogKeys)
TestRun.Case("A valid set of the controls is checked into the values of the model", ValidSetIsChecked)
TestRun.Case("A refused value names its key and its message; nothing is accepted", RefusedValuesAreNamed)
TestRun.Case("A key the dialog does not show is refused by name", NotADialogKeyIsRefused)
TestRun.Case("The error text has one line per refused value", ErrorTextHasOneLinePerValue)
TestRun.Case("The language list has the codes of folder basic with their names", LanguagesAreListedWithTheirNames)
TestRun.Finish()
