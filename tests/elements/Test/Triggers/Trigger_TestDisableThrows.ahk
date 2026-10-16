#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk

; Test trigger of WI-0061: Enable schedules one event 300 ms later, Disable throws. A disarm must drop the trigger
; anyway and cancel that event.
class Trigger_TestDisableThrows extends AhfElement {
    static Mode := "trigger"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: trigger whose Disable fails"
    static Category() => "Test"

    static Enable(ctx, params) {
        ctx.After(300, () => ctx.Fire(Map("late", 1)))
    }

    static Disable(ctx) {
        throw ElementError("test trigger: Disable fails on purpose")
    }
}
