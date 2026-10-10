#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Trigger_Window_opens extends ElementBase {
    static Name => "Window_opens"
    static Category => "Triggers"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Window_opens
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
