#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Trigger_User_Idle_Time extends ElementBase {
    static Name => "User_Idle_Time"
    static Category => "Triggers"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for User_Idle_Time
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
