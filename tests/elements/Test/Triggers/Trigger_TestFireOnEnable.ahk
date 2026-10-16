#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk

; Test trigger of WI-0061, the pattern of Trigger_Start_up: it fires inside Enable, and only when it is armed with the
; start context "ahfStartup". Its data says so (startup: 1).
class Trigger_TestFireOnEnable extends AhfElement {
    static Mode := "trigger"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: trigger that fires on enable"
    static Category() => "Test"

    static Enable(ctx, params) {
        if (ctx.context = "ahfStartup")
            ctx.Fire(Map("startup", 1))
    }

    static Disable(ctx) {
    }
}
