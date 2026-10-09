#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Run extends ElementBase {
    static Name => "Run"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Run
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
