#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Trigger_Hotkey extends ElementBase {
    static Name => "Hotkey"
    static Category => "Triggers"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Hotkey
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
