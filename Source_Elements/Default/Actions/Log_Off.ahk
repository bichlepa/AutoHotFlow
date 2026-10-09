#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Log_Off extends ElementBase {
    static Name => "Log_Off"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Log_Off
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
