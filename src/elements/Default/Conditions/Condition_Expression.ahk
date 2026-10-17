#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Condition Expression of the package Default (WI-0052): evaluates an expression; "yes" if the result is not 0 and not
; empty, else "no". Specification: the help text of v1 (help/en/Conditions/Expression.html). Parameter IDs, defaults and
; language keys are those of v1 (Source_Elements/Default/Conditions/Expression.ahk).
;
; Truth is that of AutoHotkey v2: 0, 0.0, the empty text and a text that is a number with the value 0 ("0", "0.0") are
; false, everything else (any other text, a Map) is true.
;
; The expression is evaluated here and not by ctx.EvalParams: with WarnIfEmpty the parameter evaluation turns an empty
; RESULT into an error (v1 did so), but the help says that an empty result is "no" (MIGRATION M-0052). An empty
; expression TEXT is still an error. In strict mode (E0034) a type error ends the element with "exception"; in
; compatibility mode the failed part is the empty text (E0025), as everywhere.
class Condition_Expression extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Expression")
    static Category() => Lang("Variable")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Expression")},
        {type: "multilineEdit", id: "Expression", content: "Expression", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        return Lang("Expression") " - " (params.HasProp("Expression") ? params.Expression : "")
    }

    static Run(ctx, params) {
        text := params.HasProp("Expression") ? params.Expression : ""
        if (IsObject(text) || Trim(text, " `t`r`n") = "")
            throw ElementError(Lang("Parameter '%1%' is empty", "Expression"))
        try {
            value := ctx.EvaluateExpression(text)
        } catch ElementError as e {
            ; the text of ctx.EvalParams for the same error
            throw ElementError(Lang("An error occured while parsing expression '%1%'", text) "`n`n" e.Message)
        }
        ctx.Finish(value ? "yes" : "no")
    }
}
