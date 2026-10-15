#Requires AutoHotkey v2.0
#Include ..\base\TestExprParamsKit.ahk
#Include ..\base\AhfElement.ahk
#Include ..\base\ElementRegistry.ahk

; Test element of WI-0039 and WI-0042: one parameter of each content type of v1.
;
; WI-0039 (loading with the conversion of expression texts):
;   Expr, Num, PosNum, Int, PosInt, PosIntOrZero, NeededExpr   expression content types: converted on load
;   Either              content selectable by the user (EitherType holds "string" or "expression")
;   Text, Json, Needed, VarName, NeededVar, Raw, NeededRaw     not expressions: stay as they are
;   File, NeededFile, Folder                                   paths
;   Script, Condition   evaluated by the element itself: named in V1Syntax
;
; WI-0042 (parameter evaluation): Run evaluates the parameters with ctx.EvalParams and stores the result in the global
; variable global_evalresult_<Tag> (JSON text: id -> {"type": AutoHotkey type, "value": value}), so that a test can
; read it (through the engine, or through the variable files). Skip (ids with commas) is passed as the skip list of
; EvalParams, More (ids with commas) is evaluated afterwards with EvalMoreParams. An error ends the element with
; "exception" and the text of v1. Action_TestExprParamsWorker is the same in a worker.
class Action_TestExprParams extends AhfElement {
    static Mode := "inline"
    static Level := "Programmer"
    static Stability := "Experimental"

    static V1Syntax := Map("Script", "script", "Condition", "expression")

    static Name() => "Test: parameters of every content type"
    static Category() => "Test"

    static Parameters(ctx) => TestExprParamsKit.Parameters(ctx)

    static Run(ctx, params) {
        p := TestExprParamsKit.Evaluate(ctx, params)
        ctx.SetVar(TestExprParamsKit.ResultName(params), TestExprParamsKit.Report(p))
        ctx.Finish("normal")
    }
}

ElementRegistry.Register(Action_TestExprParams)
