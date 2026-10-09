#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Condition_Flow_Running extends ElementBase {
    static Name => "Flow_Running"
    static Category => "Conditions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Flow_Running
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
