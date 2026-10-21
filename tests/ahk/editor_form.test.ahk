#Requires AutoHotkey v2.0
; Unit tests for the settings form model of an element (WI-0105, src/editor/form/, doc/ELEMENT-API-V2.md sections 2.1
; and 3): the fields of Parameters(), the defaults, the round trip pars -> form -> pars, the checks of the fields, the
; enabled state, CheckSettings with FirstCall and staticValues, the standard name, and the errors of element code (a
; warning and a log line, the form goes on). The core elements are the classes of the product package Default; the test
; element is Test.Action_TestForm (tests/elements/Test/Actions/Action_TestForm.ahk), which has every field type.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#SingleInstance Off
#Include lib\Assert.ahk
#Include ..\..\src\editor\form\ElementForm.ahk
#Include ..\..\src\elements\Default\_includes_engine.ahk
#Include ..\elements\Test\_includes_engine.ahk

; Element classes that are only used by these tests. They are not registered (not in a package).
class FormBrokenParameters extends AhfElement {
    static Parameters(ctx) {
        throw ElementError("Parameters of the test element throws on purpose")
    }
}

class FormUpperTypes extends AhfElement {
    static Parameters(ctx) => [{type: "EDIT", id: "Upper", default: "x", WarnIfEmpty: true},
        {type: "multiLINEedit", id: "Lines", default: "a"}]
}

TestRun.Init()

TestRun.Case("Form: every core element opens with its defaults and no form warning", CoreElementsOpen)
TestRun.Case("Form: every choice of every radio and drop-down of a core element passes CheckSettings", CoreChoicesPass)
TestRun.Case("Form: pars -> form -> pars gives the same parameters for every core element", CoreRoundTrip)
TestRun.Case("Form: the round trip keeps the types of the values and the parameters that no field shows", RoundTripKeepsTypes)
TestRun.Case("Form: the test element has a field of every type of the settings form", TestElementHasEveryType)
TestRun.Case("Form: the defaults of the test element fill the missing parameters", TestElementDefaults)
TestRun.Case("Form: a content type chosen by contentID decides the checks of the edit field", ContentTypeChoice)
TestRun.Case("Form: WarnIfEmpty and the variable name check give warnings, not refusals", EmptyAndVariableNameWarn)
TestRun.Case("Form: the number content types check a plain number", NumberContentChecks)
TestRun.Case("Form: a disabled field has no warnings", DisabledFieldHasNoWarning)
TestRun.Case("Form: Enable and Disable with a condition, the condition of CheckSettings", EnableAndDisable)
TestRun.Case("Form: FirstCall is true once and staticValues live as long as the form", FirstCallAndStaticValues)
TestRun.Case("Form: SetChoices, ChoiceValues and SetLabel", ChoicesAndLabel)
TestRun.Case("Form: GetValue of an unknown id is empty and does not throw", GetValueOfUnknownId)
TestRun.Case("Form: an object as pars is read like a Map", ObjectAsPars)
TestRun.Case("Form: an exception of CheckSettings is a warning and a log line, the form goes on", CheckSettingsThrows)
TestRun.Case("Form: GenerateName with the standard name; an exception keeps the last name", StandardNameAndErrors)
TestRun.Case("Form: an exception of Parameters leaves the form without fields and keeps the parameters", ParametersThrow)
TestRun.Case("Form: the type names are compared without regard to case", TypeNamesIgnoreCase)

; The core elements: the classes of the product package Default, sorted by their IDs.
CoreClasses() {
    out := []
    for cls in ElementRegistry.All() {
        if (ElementRegistry.PackageOf(ElementRegistry.IdOf(cls)) = "Default")
            out.Push(cls)
    }
    return out
}

; The warnings of the form itself (id "").
FormLevelWarnings(form) {
    out := []
    for warning in form.Warnings() {
        if (warning["id"] = "")
            out.Push(warning)
    }
    return out
}

; The texts of the warnings of one field.
FieldWarnings(form, id) {
    out := []
    for warning in form.Warnings() {
        if (warning["id"] = id)
            out.Push(warning["text"])
    }
    return out
}

; Two parameter Maps have the same keys and equal values (Assert.Equal compares the types too).
AssertSameParams(expected, actual, msg := "") {
    Assert.Equal(actual.Count, expected.Count, Assert.Join(msg, "number of parameters"))
    for key, value in expected {
        Assert.True(actual.Has(key), Assert.Join(msg, "missing parameter " key))
        Assert.Equal(actual[key], value, Assert.Join(msg, "parameter " key))
    }
}

; The number of the calls of a test (the entries of Log.Recent of level a0 that name the text).
LogHas(text) {
    for entry in Log.Recent() {
        if (entry["level"] = "a0" && InStr(entry["text"], text))
            return true
    }
    return false
}

CoreElementsOpen() {
    classes := CoreClasses()
    Assert.True(classes.Length >= 20, "the core set has its classes")
    for cls in classes {
        form := ElementForm(cls, Map())
        Assert.Equal(FormLevelWarnings(form).Length, 0, ElementRegistry.IdOf(cls))
    }
}

CoreChoicesPass() {
    checked := 0
    for cls in CoreClasses() {
        form := ElementForm(cls, Map())
        for field in form.fields {
            if (field.kind != "radio" && field.kind != "dropdown")
                continue
            id := field.ids[1]
            for value in form.ChoiceValues(id) {
                form.SetValue(id, value)
                Assert.Equal(FormLevelWarnings(form).Length, 0, ElementRegistry.IdOf(cls) " " id "=" value)
                checked++
            }
        }
    }
    Assert.True(checked > 0, "some choices were checked")
}

CoreRoundTrip() {
    for cls in CoreClasses() {
        first := ElementForm(cls, Map()).Result()
        second := ElementForm(cls, first["pars"], first["name"]).Result()
        AssertSameParams(first["pars"], second["pars"], ElementRegistry.IdOf(cls))
        Assert.Equal(second["name"], first["name"], ElementRegistry.IdOf(cls) " name")
    }
}

RoundTripKeepsTypes() {
    pars := Map("Sentence", "changed", "Level", "7", "UseSlider", 0, "Choice", "Two", "Unknown", "kept")
    result := ElementForm(Test.Action_TestForm, pars).Result()["pars"]
    Assert.Equal(result["Sentence"], "changed")
    Assert.Equal(result["Level"], "7", "a text stays a text")
    Assert.Equal(result["UseSlider"], 0, "a number stays a number")
    Assert.Equal(result["Choice"], "Two")
    Assert.Equal(result["Unknown"], "kept", "a parameter that no field shows is kept")
    Assert.Equal(result["Days"], "1,2,3", "a missing parameter gets its default")
    Assert.Equal(result.Count, 20, "19 parameters of the element and the content ID, and the unknown one; no label, no button")
}

TestElementHasEveryType() {
    form := ElementForm(Test.Action_TestForm, Map())
    kinds := Map()
    kinds.CaseSense := "Off"
    for field in form.fields
        kinds[field.kind] := true
    for kind in ["label", "edit", "multilineedit", "checkbox", "radio", "slider", "dropdown", "combobox", "hotkey",
        "button", "file", "folder", "weekdays", "dateandtime", "listbox"]
        Assert.True(kinds.Has(kind), "field type " kind)
    Assert.True(form.owners.Has("ValueContent"), "the content ID is owned by its edit field")
}

TestElementDefaults() {
    result := ElementForm(Test.Action_TestForm, Map()).Result()["pars"]
    Assert.Equal(result["Sentence"], "hello")
    Assert.Equal(result["Choice"], "One", "a radio stores its enum value")
    Assert.Equal(result["Position"], 2, "a radio with result number stores the index")
    Assert.Equal(result["Drop"], "b")
    Assert.Equal(result["ValueContent"], "string", "the content default")
    Assert.Equal(result["Days"], "1,2,3")
    Assert.Equal(result.Has("Pick"), false, "a button holds no value")
}

ContentTypeChoice() {
    form := ElementForm(Test.Action_TestForm, Map())
    field := form.owners["Value"]
    Assert.Equal(FormChecks.ContentType(field, form.values), "string")
    form.SetValue("Value", "2.5")
    Assert.Equal(FieldWarnings(form, "Value").Length, 0, "a string has no number check")
    form.SetValue("ValueContent", "Integer")
    Assert.Equal(FieldWarnings(form, "Value").Length, 1, "an integer rejects 2.5")
    form.SetValue("ValueContent", 3)
    Assert.Equal(FormChecks.ContentType(field, form.values), "integer", "the index of the entry works too")
    form.SetValue("ValueContent", "Expression")
    Assert.Equal(FieldWarnings(form, "Value").Length, 0, "an expression is not checked while typing")
}

EmptyAndVariableNameWarn() {
    form := ElementForm(Test.Action_TestForm, Map())
    Assert.Equal(FieldWarnings(form, "Sentence").Length, 0)
    form.SetValue("Sentence", "")
    Assert.Equal(FieldWarnings(form, "Sentence").Length, 1, "WarnIfEmpty")
    Assert.True(form.Result()["pars"].Has("Sentence"), "the warning does not change the value")
    form.SetValue("VarName", "1bad")
    Assert.Equal(FieldWarnings(form, "VarName").Length, 1, "a variable name must not start with a digit")
    form.SetValue("VarName", "good_name")
    Assert.Equal(FieldWarnings(form, "VarName").Length, 0)
    form.SetValue("VarName", "a%MyVar%b")
    Assert.Equal(FieldWarnings(form, "VarName").Length, 0, "%name% is allowed in a variable name")
}

NumberContentChecks() {
    form := ElementForm(Test.Action_TestForm, Map())
    form.SetValue("Count", "4")
    Assert.Equal(FieldWarnings(form, "Count").Length, 0)
    form.SetValue("Count", "-3")
    Assert.Equal(FieldWarnings(form, "Count").Length, 1, "a positive integer is not negative")
    form.SetValue("Count", "0")
    Assert.Equal(FieldWarnings(form, "Count").Length, 1, "a positive integer is at least 1")
    form.SetValue("Count", "2.5")
    Assert.Equal(FieldWarnings(form, "Count").Length, 1, "an integer is not 2.5")
    form.SetValue("Count", "2+3")
    Assert.Equal(FieldWarnings(form, "Count").Length, 0, "an expression is not checked here")
}

DisabledFieldHasNoWarning() {
    form := ElementForm(Test.Action_TestForm, Map())
    form.Disable("Sentence")
    form.SetValue("Sentence", "")
    Assert.Equal(FieldWarnings(form, "Sentence").Length, 0, "a disabled field is not checked")
    form.Enable("Sentence")
    Assert.Equal(FieldWarnings(form, "Sentence").Length, 1, "enabled again, the check runs again")
}

EnableAndDisable() {
    form := ElementForm(Test.Action_TestForm, Map())
    Assert.True(form.owners["Level"].isEnabled, "the slider is enabled by default")
    form.SetValue("UseSlider", 0)
    Assert.Equal(form.owners["Level"].isEnabled, false, "CheckSettings disables the slider with UseSlider 0")
    form.SetValue("UseSlider", 1)
    Assert.True(form.owners["Level"].isEnabled, "and enables it again")
    form.Disable("Sentence", false)
    Assert.True(form.owners["Sentence"].isEnabled, "Disable with false does nothing")
    form.Disable("Sentence")
    Assert.Equal(form.owners["Sentence"].isEnabled, false, "Disable with the default condition")
    form.Enable("Sentence", false)
    Assert.Equal(form.owners["Sentence"].isEnabled, false)
    form.Enable("Sentence")
    Assert.True(form.owners["Sentence"].isEnabled)
}

FirstCallAndStaticValues() {
    form := ElementForm(Test.Action_TestForm, Map())
    Assert.Equal(form.staticValues["checks"], 1, "CheckSettings ran once at the start")
    Assert.Equal(form.staticValues["firstCalls"], 1, "FirstCall was true in that call")
    Assert.Equal(form.FirstCall, false, "FirstCall is false after the start")
    form.SetValue("Sentence", "again")
    Assert.Equal(form.staticValues["checks"], 2, "a change runs CheckSettings again")
    Assert.Equal(form.staticValues["firstCalls"], 1, "FirstCall stays true only once")
}

ChoicesAndLabel() {
    form := ElementForm(Test.Action_TestForm, Map())
    Assert.Equal(form.ChoiceValues("Choice").Length, 2, "the enum values of the radio")
    Assert.Equal(form.ChoiceValues("Choice")[2], "Two")
    Assert.Equal(form.ChoiceValues("Position")[2], 2, "without enum values the index")
    form.SetChoices("Choice", ["X", "Y", "Z"], ["A", "B", "C"])
    Assert.Equal(form.ChoiceValues("Choice")[3], "C", "SetChoices sets the enum values")
    form.SetChoices("Position", ["p", "q"])
    Assert.Equal(form.ChoiceValues("Position").Length, 2)
    form.SetLabel("Sentence", "A label")
    Assert.Equal(form.owners["Sentence"].label, "A label")
}

GetValueOfUnknownId() {
    form := ElementForm(Test.Action_TestForm, Map())
    Assert.Equal(form.GetValue("NoSuchParameter"), "")
    Assert.Equal(form.GetValue("Pick"), "", "a button has no value")
    Assert.Equal(form.GetValue("Sentence"), "hello")
}

ObjectAsPars() {
    obj := {Sentence: "from an object", Count: 3}
    form := ElementForm(Test.Action_TestForm, obj)
    Assert.Equal(form.GetValue("Sentence"), "from an object")
    Assert.Equal(form.Result()["pars"]["Count"], 3)
}

CheckSettingsThrows() {
    form := ElementForm(Test.Action_TestForm, Map())
    checksBefore := form.staticValues["checks"]
    form.SetValue("ThrowInCheck", 1)
    Assert.Equal(FormLevelWarnings(form).Length, 1, "the exception is a warning of the form")
    Assert.True(InStr(FormLevelWarnings(form)[1]["text"], "throws on purpose"), "the text of the exception")
    Assert.True(LogHas("CheckSettings failed"), "and a log line")
    Assert.True(form.staticValues["checks"] > checksBefore, "the check ran")
    form.SetValue("Sentence", "still going")
    Assert.Equal(form.Result()["pars"]["Sentence"], "still going", "the form goes on")
    form.SetValue("ThrowInCheck", 0)
    Assert.Equal(FormLevelWarnings(form).Length, 0, "the warning goes away with the next check")
}

StandardNameAndErrors() {
    form := ElementForm(Test.Action_TestForm, Map(), "old name", true)
    Assert.Equal(form.Result()["name"], "Test form: hello", "the standard name comes from GenerateName")
    form.SetValue("Sentence", "boom")
    Assert.Equal(form.Result()["name"], "Test form: hello", "an exception of GenerateName keeps the last name")
    Assert.Equal(FormLevelWarnings(form).Length, 1, "and is a warning")
    form.SetStandardName(false)
    form.SetName("my own name")
    Assert.Equal(form.Result()["name"], "my own name")
    Assert.Equal(form.Result()["standardName"], false)
    form.SetValue("Sentence", "text")
    Assert.Equal(form.Result()["name"], "my own name", "the user's name stays without the standard name")
    form.SetStandardName(true)
    Assert.Equal(form.Result()["name"], "Test form: text")
    plain := ElementForm(Test.Action_TestForm, Map(), "plain", false)
    Assert.Equal(plain.Result()["name"], "plain", "without the standard name the name is the user's")
}

ParametersThrow() {
    form := ElementForm(FormBrokenParameters, Map("A", 1))
    Assert.Equal(form.fields.Length, 0)
    Assert.Equal(FormLevelWarnings(form).Length, 1)
    Assert.Equal(form.Result()["pars"]["A"], 1, "the parameters are kept")
}

TypeNamesIgnoreCase() {
    form := ElementForm(FormUpperTypes, Map())
    Assert.Equal(form.fields[1].kind, "edit")
    Assert.True(form.fields[1].isKnown)
    Assert.True(form.fields[2].isKnown, "multiLINEedit is a known type")
    form.SetValue("Upper", "")
    Assert.Equal(FieldWarnings(form, "Upper").Length, 1, "the type EDIT is an edit field with WarnIfEmpty")
}

TestRun.Finish()
