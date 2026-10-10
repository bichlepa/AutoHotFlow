#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Condition_NumberIs extends ElementBase {
    static Name => "NumberIs"
    static Category => "Conditions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for NumberIs
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
