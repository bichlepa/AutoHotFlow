#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk

; Test element of WI-0067 (REQ-TRG-010): blocks the ENGINE process for Duration ms (default 3000), then finishes. The
; engine cannot take another command or start another instance while it sleeps, so a test can see whether the trigger
; host keeps its timers on schedule and whether the engine processes the queued events after the busy time.
; Mode "inline": it runs in the engine. This is a deliberate block, which no product element may do.
class Action_TestBlockInline extends AhfElement {
    static Mode := "inline"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: block the engine"
    static Category() => "Test"

    static Run(ctx, params) {
        ms := 3000
        if (params.HasProp("Duration") && IsInteger(params.Duration))
            ms := Integer(params.Duration)
        Sleep(ms)
        ctx.Finish("normal")
    }
}
