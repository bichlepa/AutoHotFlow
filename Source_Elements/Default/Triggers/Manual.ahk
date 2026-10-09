#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Trigger_Manual extends ElementBase {
    static Name => "Manual"
    static Category => "Triggers"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Manual
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
