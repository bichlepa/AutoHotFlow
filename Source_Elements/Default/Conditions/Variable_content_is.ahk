#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Condition_Variable_content_is extends ElementBase {
    static Name => "Variable_content_is"
    static Category => "Conditions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Variable_content_is
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
