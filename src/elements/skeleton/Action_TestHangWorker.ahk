#Requires AutoHotkey v2.0
#Include ..\base\AhfElement.ahk
#Include ..\base\ElementRegistry.ahk

; Test element for the skeleton (WI-09, used in WI-11 and WI-15): never finishes. It blocks the
; thread without pumping messages, so only an abort or a timeout from outside ends it.
class Action_TestHangWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: hang worker"
    static Category() => "Test"

    static Run(ctx, params) {
        while (true)
            DllCall("Sleep", "UInt", 1000)
    }
}

ElementRegistry.Register(Action_TestHangWorker)
