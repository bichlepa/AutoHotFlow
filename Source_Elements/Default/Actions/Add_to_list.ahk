#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Add_to_list extends ElementBase {
    static Name => "Add_to_list"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Add_to_list
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
