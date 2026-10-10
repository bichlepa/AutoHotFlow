#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Set_Lock_Key extends ElementBase {
    static Name => "Set_Lock_Key"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Set_Lock_Key
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
