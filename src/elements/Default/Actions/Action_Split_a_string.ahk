#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Split a string of the package Default (WI-0119): splits a string at its delimiter characters into a list, which
; is written to a variable. Fields are cut of the omit characters at both ends; empty fields are fields (as in v1 and
; in the Loop Parse element). Specification: the help text of v1 (help/en/Actions/Split_a_string.md). Class ID,
; parameter IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Split_a_string.ahk).
;
; The list has the keys 1, 2, ... (an empty input gives an empty list). The split itself is TextOps.Split.
class Action_Split_a_string extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Split a string")
    static Category() => Lang("Text")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output list name")},
        {type: "Edit", id: "Varname", default: "NewList", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input string")},
        {type: "Edit", id: "VarValue", default: "Hello real world, Hello virtual world", content: ["String", "Expression"], contentID: "expression", contentDefault: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Delimiter characters")},
        {type: "Edit", id: "Delimiters", default: ",", content: "String"},
        {type: "Label", label: Lang("Omit characters")},
        {type: "Edit", id: "OmitChars", default: "%a_space%%a_tab%%a_lf%%a_cr%", content: "String"}
    ]

    static GenerateName(ctx, params) {
        return Lang("Split a string") " - " TextOps.Par(params, "Varname") " - " TextOps.Par(params, "VarValue")
            . " - " TextOps.Par(params, "Delimiters") " - " TextOps.Par(params, "OmitChars")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        text := TextOps.Text(p.VarValue, params.VarValue)
        fields := TextOps.Split(text, String(p.Delimiters), String(p.OmitChars))
        if (!ctx.SetVar(p.Varname, fields))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
