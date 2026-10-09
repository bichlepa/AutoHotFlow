#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Stop_Flow extends ElementBase {
    static Name => "Stop_Flow"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Stop_Flow
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
