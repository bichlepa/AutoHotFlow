#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Get_shortcut_information extends ElementBase {
    static Name => "Get_shortcut_information"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Get_shortcut_information
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
