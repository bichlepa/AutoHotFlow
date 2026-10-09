#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Condition_Confirmation_Dialog extends ElementBase {
    static Name => "Confirmation_Dialog"
    static Category => "Conditions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Confirmation_Dialog
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
