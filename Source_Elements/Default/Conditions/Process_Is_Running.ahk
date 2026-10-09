#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Condition_Process_Is_Running extends ElementBase {
    static Name => "Process_Is_Running"
    static Category => "Conditions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Process_Is_Running
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
