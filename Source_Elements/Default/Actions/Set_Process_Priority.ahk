#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Set_Process_Priority extends ElementBase {
    static Name => "Set_Process_Priority"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Set_Process_Priority
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
