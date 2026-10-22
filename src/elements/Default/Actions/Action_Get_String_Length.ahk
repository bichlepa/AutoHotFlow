#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Get string length of the package Default (WI-0119): writes the number of characters of a string to a variable.
; Specification: the help text of v1 (help/en/Actions/Get_string_Length.md). Class ID, parameter IDs, defaults and
; language keys are those of v1 (Source_Elements/Default/Actions/Get_string_Length.ahk).
class Action_Get_String_Length extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Get String Length")
    static Category() => Lang("Text")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "StringLength", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input string")},
        {type: "Edit", id: "VarValue", default: "Hello World", content: ["String", "Expression"], contentID: "expression", contentDefault: "string", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        return Lang("Get String Length") "`n" TextOps.Par(params, "Varname") " = "
            . Lang("Length of %1%", TextOps.Par(params, "VarValue"))
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        length := StrLen(TextOps.Text(p.VarValue, params.VarValue))
        if (!ctx.SetVar(p.Varname, length))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
