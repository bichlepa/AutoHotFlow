#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Script of the package Default (WI-0118, REQ-VAR-020): runs a few statements of the expression language (script
; form, EXPRESSION-LANGUAGE.md section 8). Specification: the help text of v1 (help/en/Actions/Script.md), which says the
; element is experimental. Class ID, parameter ID, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Script.ahk). The v1 element evaluated the script itself, so the parameter names its
; syntax (V1Syntax): the text is converted when the flow is loaded, as an expression would be.
;
;   Script  the statements, one per line; the variables are the flow's own (the names decide the scope)
;
; The result of the last line is not stored (v1 did not store it either). Errors end the element with exception.
class Action_Script extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Experimental"
    static Icon := "new Variable.png"
    static V1Syntax := Map("Script", "script")

    static Name() => Lang("Script")
    static Category() => Lang("Variable")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Script")},
        {type: "multilineEdit", id: "Script", content: "RawString", default: "", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        return Lang("Script") " - " (params.HasProp("Script") ? params.Script : "")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        ctx.EvaluateScript(p.Script)
        ctx.Finish("normal")
    }
}
