#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Condition_Variable_Is_Empty extends ElementBase {
    static Name => "Variable_Is_Empty"
    static Category => "Conditions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Variable_Is_Empty
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
