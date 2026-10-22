#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk
#Include ..\lib\TestSystemKit.ahk

; Test element of WI-0117 (E0103): calls one function of SystemOps in a worker and exports the answer. In the tests the
; provider is TestSystemProvider, which records the call and answers from the script of the test; nothing real runs.
;   Function  the name of the SystemOps function (TestSystemKit.Call lists them; one of each group in the tests)
;   Arg1      the first argument as text (Shutdown: the flags; Send: the keys)
;   Arg2      the second argument as text (Send: the mode, "" keeps the current one)
;   Tag       names the export: the global variable global_system_<Tag>_result holds the answer as text
; The element finishes "normal"; an error of the call (a scripted error, an unknown function) ends it with "exception".
class Action_TestSystemWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: call a system function in a worker"
    static Category() => "Test"

    static Run(ctx, params) {
        function := params.HasProp("Function") ? params.Function : ""
        arg1 := params.HasProp("Arg1") ? params.Arg1 : ""
        arg2 := params.HasProp("Arg2") ? params.Arg2 : ""
        tag := params.HasProp("Tag") ? params.Tag : "x"
        ctx.Export("global_system_" tag "_result", TestSystemKit.Call(function, arg1, arg2))
        ctx.Finish("normal")
    }
}
