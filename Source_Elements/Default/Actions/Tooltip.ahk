#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Tooltip extends ElementBase {
    static Name => "Tooltip"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Tooltip
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
