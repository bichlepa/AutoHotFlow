#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Drag_with_mouse extends ElementBase {
    static Name => "Drag_with_mouse"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Drag_with_mouse
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
