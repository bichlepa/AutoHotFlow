#Requires AutoHotkey v2.0
#Include Action_TestVarFunctions.ahk

; Test element of WI-0050: Action_TestVarFunctions in a worker. Every variable function asks the engine
; (cmd.engine.var.*); the report goes to the same place (global_varreport_<Tag>, through SetVar in the engine), so the
; test compares the two reports.
class Action_TestVarFunctionsWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: every variable function, in a worker"
    static Category() => "Test"

    static Run(ctx, params) {
        report := Action_TestVarFunctions.Exercise(ctx)
        ctx.SetVar("global_varreport_" params.Tag, report)
        ctx.Finish("normal")
    }
}

ElementRegistry.Register(Action_TestVarFunctionsWorker)
