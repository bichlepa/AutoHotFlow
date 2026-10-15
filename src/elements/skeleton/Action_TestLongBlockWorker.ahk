#Requires AutoHotkey v2.0
#Include ..\base\AhfElement.ahk
#Include ..\base\ElementRegistry.ahk

; Test element for WI-0027: blocks in ONE call for 7.5 s (longer than the supervisor's pong timeout of 6 s), then
; finishes "normal". The worker answers no ping and no cancel meanwhile. It shows that a busy worker is not
; declared hung (ARCHITECTURE 6.4).
class Action_TestLongBlockWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: block worker for 7.5 s in one call"
    static Category() => "Test"

    static Run(ctx, params) {
        DllCall("Sleep", "UInt", 7500)
        ctx.Finish("normal")
    }
}

ElementRegistry.Register(Action_TestLongBlockWorker)
