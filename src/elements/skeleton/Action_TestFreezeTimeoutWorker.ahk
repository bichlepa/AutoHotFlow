#Requires AutoHotkey v2.0
#Include ..\base\AhfElement.ahk
#Include ..\base\ElementRegistry.ahk

; Test element for WI-0027: like Action_TestFreezeWorker (blocks a minute in one call) but with a job deadline of
; 1500 ms. The engine ends the element with "worker timeout" and has the frozen worker killed.
class Action_TestFreezeTimeoutWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"
    static JobTimeoutMs := 1500

    static Name() => "Test: freeze worker with a job deadline"
    static Category() => "Test"

    static Run(ctx, params) {
        DllCall("Sleep", "UInt", 60000)
        ctx.Finish("normal")
    }
}

ElementRegistry.Register(Action_TestFreezeTimeoutWorker)
