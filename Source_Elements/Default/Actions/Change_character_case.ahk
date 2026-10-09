#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Change_character_case extends ElementBase {
    static Name => "Change_character_case"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Change_character_case
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
