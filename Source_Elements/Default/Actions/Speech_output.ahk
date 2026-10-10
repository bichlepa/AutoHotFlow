#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Speech_output extends ElementBase {
    static Name => "Speech_output"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Speech_output
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
