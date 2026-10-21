#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk

; Test element of WI-0105 (tests/ahk/editor_form.test.ahk): one field of every type of the settings form, an edit field
; whose content type the user chooses (Value, chosen in ValueContent), a radio with enum values and one with index values,
; and two switches for CheckSettings:
;   UseSlider     0 disables the slider Level (form.Disable)
;   ThrowInCheck  1: CheckSettings throws (the form shows a warning and goes on)
; The standard name is "Test form: <Sentence>"; a Sentence of "boom" makes GenerateName throw.
; staticValues counts the calls of CheckSettings ("checks") and the calls with FirstCall true ("firstCalls").
class Action_TestForm extends AhfElement {
    static Mode := "inline"
    static Level := "Programmer"
    static Stability := "Experimental"
    static ActsOnSystem := false

    static Name() => "Test: settings form with every field type"
    static Category() => "Test"

    static Parameters(ctx) => [
        {type: "Label", label: "Sentence"},
        {type: "Edit", id: "Sentence", default: "hello", content: "String", WarnIfEmpty: true},
        {type: "Edit", id: "Value", default: "1", content: ["String", "Expression", "Integer"]
            , contentID: "ValueContent", contentDefault: "string"},
        {type: "Edit", id: "VarName", default: "MyVar", content: "VariableName", WarnIfEmpty: true},
        {type: "Edit", id: "Count", default: "2", content: "PositiveInteger"},
        {type: "multilineEdit", id: "Notes", default: "line one`nline two", content: "String"},
        {type: "Checkbox", id: "UseSlider", default: 1, label: "Use the slider"},
        {type: "Radio", id: "Choice", default: "One", result: "enum", choices: ["First", "Second"], enum: ["One", "Two"]},
        {type: "Radio", id: "Position", default: 2, result: "number", choices: ["Left", "Right"]},
        {type: "Slider", id: "Level", default: 50, content: "Number"},
        {type: "DropDown", id: "Drop", default: "b", result: "string", choices: ["a", "b", "c"]},
        {type: "ComboBox", id: "Combo", default: "free", content: "String", choices: ["free", "fixed"]},
        {type: "Hotkey", id: "Key", default: "^a"},
        {type: "Button", id: "Pick", label: "Pick"},
        {type: "File", id: "FilePath", default: ""},
        {type: "Folder", id: "FolderPath", default: ""},
        {type: "weekdays", id: "Days", default: "1,2,3"},
        {type: "DateAndTime", id: "When", default: "20260101"},
        {type: "listbox", id: "Items", default: "a,b", choices: ["a", "b", "c"]},
        {type: "Checkbox", id: "ThrowInCheck", default: 0, label: "Throw in CheckSettings"}
    ]

    static GenerateName(ctx, params) {
        if (params.Sentence = "boom")
            throw ElementError("GenerateName of Test.Action_TestForm throws on purpose")
        return "Test form: " params.Sentence
    }

    static CheckSettings(form, params, staticValues) {
        staticValues["checks"] := staticValues.Get("checks", 0) + 1
        if (form.FirstCall)
            staticValues["firstCalls"] := staticValues.Get("firstCalls", 0) + 1
        form.Disable("Level", params.UseSlider = 0)
        if (params.ThrowInCheck = 1)
            throw ElementError("CheckSettings of Test.Action_TestForm throws on purpose")
    }

    static Run(ctx, params) {
        ctx.Finish("normal")
    }
}
