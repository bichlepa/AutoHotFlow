#Requires AutoHotkey v2.0
; Unit tests of the settings of an element (WI-0106, src/editor/EditorSettings.ahk and src/editor/ElementSettingsWindow.ahk):
; the changes that OK sends (EditorSettings.Changes), the equality of parameter values, the choice values of a string result
; (ElementForm.ChoiceValues), and the window built for every field type of the test element WITHOUT showing it (Build with
; show false): the rows, the controls of every kind, the sync of the values, the enabled state and the warnings after a
; change, the slider of the scroll area and the structure change (SetChoices) that builds the window again. No window is shown.
; The test element is Test.Action_TestForm (tests/elements/Test/Actions/Action_TestForm.ahk), which has every field type.
; Must stand before the first include.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\editor\EditorSettings.ahk
#Include ..\..\src\editor\ElementSettingsWindow.ahk
#Include ..\..\src\elements\Default\_includes_engine.ahk
#Include ..\elements\Test\_includes_engine.ahk

; The model of the controller in these tests: only the notices are used (EditorSettings.OpenNew needs no draft).
class SettingsTestModel {
    Notice(textKey, args*) {
    }
}

TestRun.Init()

TestRun.Case("Settings: Changes gives only the parameters and the name that the user changed", ChangesOnlyTheUserChanges)
TestRun.Case("Settings: a list or a map is equal by its text, a number and its text are equal", SameValues)
TestRun.Case("Settings: a string result gives the texts of its choices as values", StringChoiceValues)
TestRun.Case("Settings: OpenNew without a window keeps the session and Cancel sends nothing", OpenNewAndCancel)
TestRun.Case("Settings: the window is built for every field type of the test element", WindowHasEveryType)
TestRun.Case("Settings: the window shows the values of the element and a change reaches the form", WindowValuesAndChange)
TestRun.Case("Settings: a disabled field is disabled in the window after a change", WindowDisabledAfterChange)
TestRun.Case("Settings: a change of the choices builds the window again", WindowRebuildsOnChoices)
TestRun.Case("Settings: a long form gets a scroll area and a slider", WindowScrollArea)
TestRun.Case("Settings: an unknown class is shown read only", WindowUnknownClass)
TestRun.Case("Settings: a class of the same kind is taken and the window follows, another kind is refused", ClassChange)

; Opens the settings of the test element for a new element (no window): the controller with a session.
OpenTestElement(pars := "") {
    settings := EditorSettings(SettingsTestModel())
    Assert.True(settings.OpenNew("action", "Test.Action_TestForm", 0, 0, "", ""), "the settings open")
    if (pars != "")
        for key, value in pars
            settings.SetValue(key, value)
    return settings
}

AssertNot(v, msg := "") => Assert.True(!v, msg)

; The control of the field of a parameter in the window (an entry of the window's list), or "".
EntryOf(window, id) {
    for entry in window.entries {
        if (entry["id"] = id)
            return entry
    }
    return ""
}

ChangesOnlyTheUserChanges() {
    initial := Map("pars", Map("Sentence", "hello", "Count", "2"), "name", "Test", "standardName", false)
    final := Map("pars", Map("Sentence", "hello", "Count", "3", "Extra", "x"), "name", "Test", "standardName", false)
    fields := EditorSettings.Changes(initial, final)
    Assert.True(fields.Has("pars"), "the parameters changed")
    Assert.Equal(fields["pars"].Count, 2, "the changed parameter and the new one, not the unchanged one")
    Assert.Equal(fields["pars"]["Count"], "3")
    Assert.Equal(fields["pars"]["Extra"], "x")
    AssertNot(fields.Has("name"), "the name did not change")
    AssertNot(fields.Has("StandardName"))
    final["name"] := "Renamed"
    final["standardName"] := true
    fields := EditorSettings.Changes(initial, final)
    Assert.Equal(fields["name"], "Renamed")
    Assert.Equal(fields["StandardName"], 1, "the standard name is sent as 1 or 0")
    Assert.Equal(EditorSettings.Changes(initial, initial).Count, 0, "nothing changed: nothing is sent")
}

SameValues() {
    Assert.True(EditorSettings.Same(1, "1"), "a number and its text")
    AssertNot(EditorSettings.Same("a", "b"))
    Assert.True(EditorSettings.Same(["a", "b"], ["a", "b"]), "lists by their text")
    AssertNot(EditorSettings.Same(["a"], "a"), "a list and a text")
}

StringChoiceValues() {
    form := ElementForm(Test.Action_TestForm, Map())
    Assert.Equal(form.ChoiceValues("Drop")[2], "b", "result string: the texts")
    Assert.Equal(form.ChoiceValues("Choice")[2], "Two", "enum values still win")
    Assert.Equal(form.ChoiceValues("Position")[2], 2, "result number: the index")
}

OpenNewAndCancel() {
    settings := OpenTestElement()
    Assert.True(settings.Busy)
    Assert.True(settings.Form.name != "", "the defaults give the name")
    AssertNot(settings.OpenNew("action", "Test.Action_TestForm", 0, 0, "", ""), "a second one is refused")
    Assert.True(settings.Cancel()["ok"])
    AssertNot(settings.Busy, "cancel closes the settings")
}

WindowHasEveryType() {
    settings := OpenTestElement()
    window := ElementSettingsWindow(0)
    window.Build(settings, "", false)
    kinds := Map()
    for entry in window.entries
        kinds[entry["kind"]] := true
    for kind in ["edit", "multilineedit", "checkbox", "radio", "slider", "dropdown", "combobox", "hotkey", "button"
            , "file", "folder", "weekdays", "dateandtime", "listbox"]
        Assert.True(kinds.Has(kind), "a control of the type " kind)
    Assert.True(window.gui.Hwnd != 0, "the window was built")
    window.Hide()
    settings.Discard()
    AssertNot(settings.Busy)
}

WindowValuesAndChange() {
    settings := OpenTestElement()
    window := ElementSettingsWindow(0)
    settings.window := window          ; the controller tells the window of every change (Sync)
    window.Build(settings, "", false)
    sentence := EntryOf(window, "Sentence")
    Assert.Equal(sentence["ed"].Value, "hello", "the value of the element is in the edit")
    settings.SetValue("Sentence", "changed")
    Assert.Equal(sentence["ed"].Value, "changed", "a change of the form reaches the window")
    choice := EntryOf(window, "Choice")
    Assert.Equal(choice["ctls"][1].Value + choice["ctls"][2].Value, 1, "one radio of the group is on")
    window.Hide()
    settings.Discard()
}

WindowDisabledAfterChange() {
    settings := OpenTestElement(Map("UseSlider", 0))
    window := ElementSettingsWindow(0)
    settings.window := window
    window.Build(settings, "", false)
    level := EntryOf(window, "Level")
    AssertNot(level["ctls"][1].Enabled, "the slider is disabled by CheckSettings")
    settings.SetValue("UseSlider", 1)
    Assert.True(level["ctls"][1].Enabled, "the slider is enabled again after the change")
    window.Hide()
    settings.Discard()
}

WindowRebuildsOnChoices() {
    settings := OpenTestElement()
    window := ElementSettingsWindow(0)
    settings.window := window
    window.Build(settings, "", false)
    before := window.signature
    settings.session["form"].SetChoices("Drop", ["x", "y", "z", "w"])
    window.Sync()
    Assert.True(window.signature != before, "the new choices give a new structure")
    Assert.Equal(EntryOf(window, "Drop")["field"].choices.Length, 4, "the window is built again with the new choices")
    window.Hide()
    settings.Discard()
}

WindowScrollArea() {
    settings := OpenTestElement()
    window := ElementSettingsWindow(0)
    window.Build(settings, "", false)
    Assert.True(IsObject(window.slider) = (window.maxOff > 0), "a slider exactly when the form is longer than the area")
    window._Scroll(99999)
    Assert.Equal(window.offset, window.maxOff, "the offset stops at the end")
    window._Scroll(-5)
    Assert.Equal(window.offset, 0, "the offset stays in the range")
    window.Hide()
    settings.Discard()
}

WindowUnknownClass() {
    settings := EditorSettings(SettingsTestModel())
    settings.session := Map("mode", "edit", "id", "element1", "kind", "action", "classId", "Default.Action_Gone"
        , "cls", "", "migration", [], "x", 0, "y", 0, "connect", "", "done", "", "placeholder", "unknown class"
        , "unknown", true, "stored", Map("Duration", "3"), "form", "", "initial", Map())
    window := ElementSettingsWindow(0)
    window.Build(settings, "", false)
    Assert.Equal(window.entries.Length, 0, "no fields for an unknown class")
    window.Sync()
    window.Hide()
    settings.session := ""
}

ClassChange() {
    settings := OpenTestElement()
    window := ElementSettingsWindow(0)
    settings.window := window
    window.Build(settings, "", false)
    AssertNot(settings.ChangeClass("Default.Condition_Expression"), "another kind is refused")
    Assert.True(settings.ChangeClass("Test.Action_TestForm"), "the same class is no change")
    Assert.True(settings.ChangeClass("Default.Action_Do_nothing"), "a class of the same kind is taken")
    Assert.Equal(settings.session["classId"], "Default.Action_Do_nothing")
    window.Hide()
    settings.Discard()
}

TestRun.Finish()
