#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk

; Test trigger of WI-0061: Enable throws. The arming is answered with ok false and the trigger is not armed.
class Trigger_TestFail extends AhfElement {
    static Mode := "trigger"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: trigger whose Enable fails"
    static Category() => "Test"

    static Enable(ctx, params) {
        throw ElementError("test trigger fails on purpose")
    }

    static Disable(ctx) {
    }
}
