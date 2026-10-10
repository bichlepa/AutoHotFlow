#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Trigger_Window_gets_inactive extends ElementBase {
    static Name => "Window_gets_inactive"
    static Category => "Triggers"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Window_gets_inactive
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
