#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\LoopOps.ahk

; Loop Condition of the package Default (WI-0054): evaluates an expression before each pass and continues while the
; result is true. Specification: the help text of v1 (help/en/Loops/condition.html). Class ID, parameter IDs, defaults
; and language keys are those of v1 (Source_Elements/Default/Loops/Condition.ahk). The entry points and the loop
; variables: lib/LoopOps.ahk.
;
;   Expression               the condition. False is the empty result, 0 and a text that is a number with the value 0
;   EvaluateOnFirstIteration if not set, the first pass is made without checking the condition
;
; Loop variable: A_Index (1 in the first pass). The condition of a pass is evaluated with the A_Index of that pass, so
; "a_index <= 10" makes 10 passes, as the help says. v1 set A_Index only after the first check, so the first check saw
; no A_Index (MIGRATION M-0059).
;
; The expression is evaluated here and not by ctx.EvalParams, as v1 did (it evaluated the raw text itself): with
; WarnIfEmpty the parameter evaluation would turn an empty result into an error, but an empty result is false.
; Its text is in the expression syntax of the new language (the loader converts a v1 text, Parameters() names the
; content type).
class Loop_Condition extends AhfElement {
    static Mode := "inline"
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Condition")
    static Category() => Lang("Variable")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Condition")},
        {type: "Edit", id: "Expression", default: "a_index <= 5", content: "Expression", WarnIfEmpty: true},
        {type: "Checkbox", id: "EvaluateOnFirstIteration", default: 1, label: Lang("Evaluate on first iteration")}
    ]

    static GenerateName(ctx, params) => Lang("Condition") " - " (params.HasProp("Expression") ? params.Expression : "")

    static Run(ctx, params) {
        entry := LoopOps.Entry(ctx)
        if (entry = "break") {
            ctx.Finish("tail")
            return
        }
        text := params.HasProp("Expression") ? params.Expression : ""
        if (entry = "head") {
            index := 1
            LoopOps.SetIndex(ctx, index)
            ; a flow file without the checkbox has the default (v1 filled the defaults in when it loaded the flow)
            check := !params.HasProp("EvaluateOnFirstIteration") || LoopOps.IsTrue(params.EvaluateOnFirstIteration)
            go := !check || LoopOps.Condition(ctx, text)
        } else {
            index := LoopOps.SetIndex(ctx, LoopOps.NextIndex(ctx))
            go := LoopOps.Condition(ctx, text)
        }
        ctx.Finish(go ? "head" : "tail")
    }
}
