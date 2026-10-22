#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Get clipboard of the package Default (WI-0123): copies the text of the Windows clipboard into a variable.
; Specification: the help text of v1 (help/en/Actions/Get_Clipboard.md). Class ID, parameter IDs, defaults and language
; keys are those of v1 (Source_Elements/Default/Actions/Get_clipboard.ahk).
;
; Worker element. The clipboard is the real one (no seam: other programs use it too; the tests save and restore it).
; Only text is read: other formats give the empty text (as v1, MIGRATION M-0121).
class Action_Get_Clipboard extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Get Clipboard")
    static Category() => Lang("Variable")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output Variable name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("Get Clipboard") "`n" TextOps.Par(params, "Varname")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        text := A_Clipboard
        if (!ctx.SetVar(p.Varname, text))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
