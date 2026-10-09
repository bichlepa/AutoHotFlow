#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_activate_Window extends ElementBase {
    static Name => "activate_Window"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for activate_Window
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
