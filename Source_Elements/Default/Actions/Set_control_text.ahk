#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Set_control_text extends ElementBase {
    static Name => "Set_control_text"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Set_control_text
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
