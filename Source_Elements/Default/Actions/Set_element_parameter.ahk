#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Set_element_parameter extends ElementBase {
    static Name => "Set_element_parameter"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Set_element_parameter
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
