#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Trigger_Periodic_Timer extends ElementBase {
    static Name => "Periodic_Timer"
    static Category => "Triggers"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Periodic_Timer
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
