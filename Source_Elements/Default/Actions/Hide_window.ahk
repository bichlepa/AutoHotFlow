#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Hide_window extends ElementBase {
    static Name => "Hide_window"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Hide_window
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
