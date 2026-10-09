#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Time_difference extends ElementBase {
    static Name => "Time_difference"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Time_difference
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
