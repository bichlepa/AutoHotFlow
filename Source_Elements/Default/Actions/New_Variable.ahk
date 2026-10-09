#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_New_Variable extends ElementBase {
    static Name => "New_Variable"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for New_Variable
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
