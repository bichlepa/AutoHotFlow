#Requires AutoHotkey v2.0
#Include ..\base\AhfElement.ahk
#Include ..\base\ElementRegistry.ahk

; Test element for the skeleton (WI-09, used in WI-11 and WI-15): blocks for 800 ms, then finishes. The optional
; parameter Duration (ms, WI-27) sets another time, so a pool test can keep several workers busy at once.
; Mode "worker": it may only run in a worker process, never in the engine.
class Action_TestBlockWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: block worker"
    static Category() => "Test"

    static Run(ctx, params) {
        ms := 800
        if (params.HasProp("Duration") && IsInteger(params.Duration))
            ms := Integer(params.Duration)
        Sleep(ms)
        ctx.Finish("normal")
    }
}

ElementRegistry.Register(Action_TestBlockWorker)
