#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Shutdown extends ElementBase {
    static Name => "Shutdown"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Shutdown
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
