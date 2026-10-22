#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Substring of the package Default (WI-0119): writes a part of a string to a variable: the leftmost or the
; rightmost characters, or the characters from a position to the right or to the left of it (or to the end).
; Specification: the help text of v1 (help/en/Actions/Substring.md). Class ID, parameter IDs, defaults and language
; keys are those of v1 (Source_Elements/Default/Actions/Substring.ahk).
;
;   WhereToBegin  FromLeft / FromRight: the Length leftmost / rightmost characters.
;                 Position: from StartPos, to the right (GoRight) or to the left (GoLeft, the characters that end at
;                 StartPos; v1 StringMid with L). UntilTheEnd takes all characters up to the end (right) or the start (left).
;   A count of 0 or less gives the empty text (v1 gave the empty text too).
class Action_Substring extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Substring")
    static Category() => Lang("Text")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable_name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input string")},
        {type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true},
        {type: "Label", label: Lang("Start position")},
        {type: "Radio", id: "WhereToBegin", default: "FromLeft", choices: [Lang("Start from left"), Lang("Start from right"), Lang("Start from following position")], result: "enum", enum: ["FromLeft", "FromRight", "Position"]},
        {type: "Edit", id: "StartPos", default: 1, content: "Number", WarnIfEmpty: true},
        {type: "Label", label: Lang("Count of characters")},
        {type: "CheckBox", id: "UntilTheEnd", default: 0, label: Lang("Until the end")},
        {type: "Edit", id: "Length", default: 5, content: "Number", WarnIfEmpty: true},
        {type: "Radio", id: "LeftOrRight", default: "GoRight", choices: [Lang("Go left"), Lang("Go right")], result: "enum", enum: ["GoLeft", "GoRight"]}
    ]

    static GenerateName(ctx, params) {
        return Lang("Substring") " - " TextOps.Par(params, "Varname") " - " TextOps.Par(params, "VarValue")
    }

    static CheckSettings(form, params, staticValues) {
        if (params.WhereToBegin = "Position") {
            form.Enable("StartPos")
            form.Enable("LeftOrRight")
            form.Enable("UntilTheEnd")
            form.Disable("Length", params.UntilTheEnd)
        } else {
            form.Disable("StartPos")
            form.Disable("LeftOrRight")
            form.Disable("UntilTheEnd")
            form.SetValue("UntilTheEnd", 0)
        }
        if (params.WhereToBegin = "FromRight")
            form.SetValue("LeftOrRight", "GoLeft")
        else if (params.WhereToBegin = "FromLeft")
            form.SetValue("LeftOrRight", "GoRight")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "StartPos,Length")
        text := TextOps.Text(p.VarValue, params.VarValue)
        switch p.WhereToBegin {
            case "FromLeft":
                p := ctx.EvalMoreParams(p, params, "Length")
                result := TextOps.Left(text, TextOps.Count(p.Length))
            case "FromRight":
                p := ctx.EvalMoreParams(p, params, "Length")
                result := TextOps.Right(text, TextOps.Count(p.Length))
            case "Position":
                p := ctx.EvalMoreParams(p, params, "StartPos")
                start := TextOps.Count(p.StartPos)
                count := ""
                if (!p.UntilTheEnd) {
                    p := ctx.EvalMoreParams(p, params, "Length")
                    count := TextOps.Count(p.Length)
                }
                result := (p.LeftOrRight = "GoLeft") ? TextOps.MidLeft(text, start, count) : TextOps.Mid(text, start, count)
            default:
                throw ElementError("Substring: unknown start position '" p.WhereToBegin "'")
        }
        if (!ctx.SetVar(p.Varname, result))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
