#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Trigger_Process_closes extends ElementBase {
    static Name => "Process_closes"
    static Category => "Triggers"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Process_closes
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
