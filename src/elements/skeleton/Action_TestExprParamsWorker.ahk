#Requires AutoHotkey v2.0
#Include ..\base\AhfElement.ahk
#Include ..\base\ElementRegistry.ahk
#Include Action_TestExprParams.ahk

; Test element of WI-42: Action_TestExprParams in a worker (same parameters). The engine evaluates the parameters
; before the job (E26); Run takes them with ctx.EvalParams (skip list Skip, then EvalMoreParams for More) and exports
; the same JSON text as the inline element, as global_evalresult_<Tag>: the engine sets an export where its name says,
; so the test finds both results in the same place.
class Action_TestExprParamsWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static V1Syntax := Map("Script", "script", "Condition", "expression")

    static Name() => "Test: parameters of every content type, in a worker"
    static Category() => "Test"

    static Parameters(ctx) => Action_TestExprParams.Parameters(ctx)

    static Run(ctx, params) {
        p := Action_TestExprParams.Evaluate(ctx, params)
        ctx.Export(Action_TestExprParams.ResultName(params), Action_TestExprParams.Report(p))
        ctx.Finish("normal")
    }
}

ElementRegistry.Register(Action_TestExprParamsWorker)
