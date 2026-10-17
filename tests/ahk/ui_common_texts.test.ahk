#Requires AutoHotkey v2.0
; Unit tests for src/ui_common/UiTexts.ahk and the memory of UiWindow (WI-0069): a registered text follows a change of
; the language (Reload), a forgotten owner keeps its texts, a control that no longer exists is dropped. No window is
; created here: the controls are fake objects with a Text and a Title property.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\ui_common\UiWindow.ahk

; A control with the properties that UiTexts sets.
class FakeControl {
    Text := ""
    Title := ""
}

; A control that is gone: setting its text fails, as a destroyed Gui control does.
class GoneControl {
    Text {
        set {
            throw Error("control is gone")
        }
    }
}

; Language folders with two texts each, written by the test (A_Temp, removed at the end).
MakeLanguages() {
    dir := A_Temp "\ahf_ui_texts_test_" DllCall("GetCurrentProcessId")
    if (DirExist(dir))
        DirDelete(dir, true)
    DirCreate(dir "\basic")
    FileAppend("[language_info]`nname=en`n[common]`nUi_test_key=Hello`nUi_args_%1%=Value %1%`n", dir "\basic\en.ini", "UTF-8")
    FileAppend("[language_info]`nname=de`n[common]`nUi_test_key=Hallo`nUi_args_%1%=Wert %1%`n", dir "\basic\de.ini", "UTF-8")
    LangTable.Dir := dir
    LangTable.PackagesDir := dir "\no_packages"
    return dir
}

TestRun.Init()
dir := MakeLanguages()
LangTable.Code := "en"
LangTable.Load()

TestRun.Case("Register: the control gets the translated text of the key", () => (
    UiTexts._items := [],
    ctl := FakeControl(),
    UiTexts.Register(1, ctl, "Ui_test_key"),
    Assert.Equal(ctl.Text, "Hello"),
    Assert.Equal(UiTexts.Count(1), 1)))

TestRun.Case("Register: arguments fill the text, the property can be another one", () => (
    UiTexts._items := [],
    ctl := FakeControl(),
    UiTexts.Register(1, ctl, "Ui_args_%1%", "Title", "X"),
    Assert.Equal(ctl.Title, "Value X")))

TestRun.Case("Reload: the registered texts follow a change of the language", () => (
    UiTexts._items := [],
    ctl := FakeControl(),
    UiTexts.Register(1, ctl, "Ui_test_key"),
    LangTable.Code := "de",
    UiTexts.Reload(),
    Assert.Equal(ctl.Text, "Hallo"),
    LangTable.Code := "en",
    UiTexts.Reload()))

TestRun.Case("Forget: the texts of an owner are removed and not set again", () => (
    UiTexts._items := [],
    a := FakeControl(),
    b := FakeControl(),
    UiTexts.Register(1, a, "Ui_test_key"),
    UiTexts.Register(2, b, "Ui_test_key"),
    UiTexts.Forget(1),
    Assert.Equal(UiTexts.Count(1), 0, "owner 1 is gone"),
    Assert.Equal(UiTexts.Count(2), 1, "owner 2 is kept"),
    LangTable.Code := "de",
    UiTexts.Reload(),
    Assert.Equal(a.Text, "Hello", "the forgotten control keeps its text"),
    Assert.Equal(b.Text, "Hallo"),
    LangTable.Code := "en",
    UiTexts.Reload()))

TestRun.Case("Reload: a control that is gone is dropped and does not stop the others", () => (
    UiTexts._items := [],
    gone := GoneControl(),
    ctl := FakeControl(),
    UiTexts.Register(1, ctl, "Ui_test_key"),
    UiTexts._items.InsertAt(1, Map("owner", 1, "ctl", gone, "prop", "Text", "key", "Ui_test_key", "args", [])),
    LangTable.Code := "de",
    UiTexts.Reload(),
    Assert.Equal(UiTexts.Count(1), 1, "the gone control is dropped, the live one stays"),
    Assert.Equal(ctl.Text, "Hallo"),
    LangTable.Code := "en",
    UiTexts.Reload()))

TestRun.Case("UiWindow.Recall: a name that was never shown has no remembered place", () => (
    UiWindow.ClearMemory(),
    Assert.True(UiWindow.Recall("ui.test.never") = "", "nothing remembered")))

DirDelete(dir, true)
TestRun.Finish()
