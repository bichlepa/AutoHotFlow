#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Absolute_Number extends ElementBase {
    static Name => "Absolute_Number"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Absolute_Number
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
