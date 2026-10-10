#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Rounding_a_number extends ElementBase {
    static Name => "Rounding_a_number"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Rounding_a_number
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
