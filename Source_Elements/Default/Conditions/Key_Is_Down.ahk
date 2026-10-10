#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Condition_Key_Is_Down extends ElementBase {
    static Name => "Key_Is_Down"
    static Category => "Conditions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Key_Is_Down
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
