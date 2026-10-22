#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk
#Include ..\lib\TestSystemKit.ahk

; Test trigger of WI-0117 (E0103): calls one function of SystemOps in the trigger host, in Enable, when it is armed.
; The parameters are those of Action_TestSystemWorker (Function, Arg1, Arg2). The record of the call (role triggerhost)
; is what the tests check; the answer is not used. A scripted error makes Enable fail and the trigger is not armed.
class Trigger_TestSystemCall extends AhfElement {
    static Mode := "trigger"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: trigger that calls a system function"
    static Category() => "Test"
    static Parameters(ctx) => [{id: "Function", content: "String"}, {id: "Arg1", content: "String"},
        {id: "Arg2", content: "String"}]     ; a trigger gets its parameters only when Parameters() declares them (seen in the log of a failing run)

    static Enable(ctx, params) {
        function := params.HasProp("Function") ? params.Function : ""
        arg1 := params.HasProp("Arg1") ? params.Arg1 : ""
        arg2 := params.HasProp("Arg2") ? params.Arg2 : ""
        TestSystemKit.Call(function, arg1, arg2)
    }

    static Disable(ctx) {
    }
}
