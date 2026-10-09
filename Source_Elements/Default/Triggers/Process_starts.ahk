#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Trigger_Process_starts extends ElementBase {
    static Name => "Process_starts"
    static Category => "Triggers"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Process_starts
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
