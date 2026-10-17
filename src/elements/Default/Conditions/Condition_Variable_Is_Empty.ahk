#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Condition Variable is empty of the package Default (WI-0052): "yes" if a variable does not exist or holds the empty
; text. Specification: the help text of v1 (help/en/Conditions/Variable_is_empty.html). Parameter IDs, defaults and
; language keys are those of v1 (Source_Elements/Default/Conditions/Variable_Is_Empty.ahk).
;
; A variable that holds the number 0 or a list (also an empty one) is not empty. (The help of v1 has leftover warnings
; about a new AutoHotkey thread and loss of data that do not apply to this condition; they are not carried over.)
class Condition_Variable_Is_Empty extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Variable_Is_Empty")
    static Category() => Lang("Variable")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Variable name")},
        {type: "Edit", id: "VarName", default: "Varname", content: "VariableName", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        return Lang("Variable_Is_Empty") " - " (params.HasProp("VarName") ? params.VarName : "")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        value := ctx.GetVar(p.VarName, "")
        ctx.Finish((!IsObject(value) && String(value) = "") ? "yes" : "no")
    }
}
