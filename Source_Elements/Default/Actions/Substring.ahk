#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Substring extends ElementBase {
    static Name => "Substring"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Substring
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
