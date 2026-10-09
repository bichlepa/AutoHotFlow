#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Trigger_Time_of_Day extends ElementBase {
    static Name => "Time_of_Day"
    static Category => "Triggers"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Time_of_Day
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
