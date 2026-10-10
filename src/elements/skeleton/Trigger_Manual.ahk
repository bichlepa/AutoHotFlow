#Requires AutoHotkey v2.0
#Include ..\base\AhfElement.ahk
#Include ..\base\ElementRegistry.ahk

; Walking-skeleton version of the v1 trigger "Manual": it fires only when the engine sends a command.
; It has no logic of its own (Enable and Disable do nothing). Phase 2 only.
class Trigger_Manual extends AhfElement {
    static Mode := "trigger"
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => "Manual"
    static Category() => "User_interaction"

    static Enable(ctx, params) => ""
    static Disable(ctx) {
    }

    ; Pure function, runs in the engine: the thread variables after the event.
    static TriggerVariables(params, data) => Map()
}

ElementRegistry.Register(Trigger_Manual)
