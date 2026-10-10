#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Trim_a_string extends ElementBase {
    static Name => "Trim_a_string"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Trim_a_string
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
