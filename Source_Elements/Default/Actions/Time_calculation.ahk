#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Time_calculation extends ElementBase {
    static Name => "Time_calculation"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Time_calculation
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
