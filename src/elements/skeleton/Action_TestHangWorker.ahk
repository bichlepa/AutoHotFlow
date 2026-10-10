#Requires AutoHotkey v2.0
#Include ..\base\AhfElement.ahk
#Include ..\base\ElementRegistry.ahk

; Test element for the skeleton (WI-09, used in WI-11 and WI-15): never finishes. It loops over
; DllCall("Sleep") slices. AHK checks for window messages between script lines, so the worker still
; answers pings and cancel between slices. A slice of 100 ms keeps the cancel latency low (WI-11: 500 ms
; budget); a single 1000 ms slice measured 812 ms. Only an abort or a timeout from outside ends it.
class Action_TestHangWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: hang worker"
    static Category() => "Test"

    static Run(ctx, params) {
        while (true)
            DllCall("Sleep", "UInt", 100)
    }
}

ElementRegistry.Register(Action_TestHangWorker)
