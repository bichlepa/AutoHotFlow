#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Close_Window extends ElementBase {
    static Name => "Close_Window"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Close_Window
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
