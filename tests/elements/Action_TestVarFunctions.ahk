#Requires AutoHotkey v2.0
#Include TestVarFunctionsKit.ahk
#Include ..\..\src\elements\base\AhfElement.ahk
#Include ..\..\src\elements\base\ElementRegistry.ahk

; Test element of WI-0050 (inline): calls every variable function of the context in a fixed order and writes a report of
; what each call returned (or the text of the error it threw) into the global variable global_varreport_<Tag>. Its twin
; Action_TestVarFunctionsWorker runs the same Exercise in a worker, where every call goes to the engine
; (cmd.engine.var.*): the two reports must be equal (tests/integration/test_worker_vars.py).
;
; The report has one line per call: "<label> = <Type>:<JSON of the value>" or "<label> ! <error text>". Lists of names
; are filtered to the names this element makes, so variables of other tests (global ones) do not show.
class Action_TestVarFunctions extends AhfElement {
    static Mode := "inline"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: every variable function"
    static Category() => "Test"

    static Run(ctx, params) {
        report := TestVarFunctionsKit.Exercise(ctx)
        ctx.SetVar("global_varreport_" params.Tag, report)
        ctx.Finish("normal")
    }
}

ElementRegistry.Register(Action_TestVarFunctions)
