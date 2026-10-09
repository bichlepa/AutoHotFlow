#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Trigger_Clipboard_Changes extends ElementBase {
    static Name => "Clipboard_Changes"
    static Category => "Triggers"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Clipboard_Changes
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
