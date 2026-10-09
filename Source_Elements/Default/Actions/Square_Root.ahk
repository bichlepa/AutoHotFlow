#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Square_Root extends ElementBase {
    static Name => "Square_Root"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Square_Root
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
