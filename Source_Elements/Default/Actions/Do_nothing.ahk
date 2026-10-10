#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Do_nothing extends ElementBase {
    static Name => "Do_nothing"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Do_nothing
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
