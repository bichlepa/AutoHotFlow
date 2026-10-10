#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Condition_Debug_dialog extends ElementBase {
    static Name => "Debug_dialog"
    static Category => "Conditions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Debug_dialog
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
