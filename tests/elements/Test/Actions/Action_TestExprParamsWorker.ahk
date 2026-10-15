#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk
#Include ..\lib\TestExprParamsKit.ahk

; Test element of WI-0042: Action_TestExprParams in a worker (same parameters). The engine evaluates the parameters
; before the job (E0026); Run takes them with ctx.EvalParams (skip list Skip, then EvalMoreParams for More) and exports
; the same JSON text as the inline element, as global_evalresult_<Tag>: the engine sets an export where its name says,
; so the test finds both results in the same place.
class Action_TestExprParamsWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static V1Syntax := Map("Script", "script", "Condition", "expression")

    static Name() => "Test: parameters of every content type, in a worker"
    static Category() => "Test"

    static Parameters(ctx) => TestExprParamsKit.Parameters(ctx)

    static Run(ctx, params) {
        p := TestExprParamsKit.Evaluate(ctx, params)
        ctx.Export(TestExprParamsKit.ResultName(params), TestExprParamsKit.Report(p))
        ctx.Finish("normal")
    }
}
