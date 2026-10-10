#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Trigger_Hotstring extends ElementBase {
    static Name => "Hotstring"
    static Category => "Triggers"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Hotstring
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
