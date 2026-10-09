#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Get_index_of_element_in_list extends ElementBase {
    static Name => "Get_index_of_element_in_list"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Get_index_of_element_in_list
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
