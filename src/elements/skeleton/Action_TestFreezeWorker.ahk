#Requires AutoHotkey v2.0
#Include ..\base\AhfElement.ahk
#Include ..\base\ElementRegistry.ahk

; Test element for WI-27: blocks for a minute in ONE call. The worker answers no ping and no cancel meanwhile
; (a MsgBox or a long DllCall in a real element behaves like this). Only a kill from outside ends it: the
; engine's cancel is not confirmed within 2 s, so it has the supervisor kill the process (ARCHITEKTUR 6.4).
class Action_TestFreezeWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: freeze worker"
    static Category() => "Test"

    static Run(ctx, params) {
        DllCall("Sleep", "UInt", 60000)
        ctx.Finish("normal")
    }
}

ElementRegistry.Register(Action_TestFreezeWorker)
