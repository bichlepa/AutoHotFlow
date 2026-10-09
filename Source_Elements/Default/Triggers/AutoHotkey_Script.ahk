#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Trigger_AutoHotkey_Script extends ElementBase {
    static Name => "AutoHotkey_Script"
    static Category => "Triggers"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for AutoHotkey_Script
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
