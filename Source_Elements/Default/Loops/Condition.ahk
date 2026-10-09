#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Loop_Condition extends ElementBase {
    static Name => "Condition"
    static Category => "Loops"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Condition
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
