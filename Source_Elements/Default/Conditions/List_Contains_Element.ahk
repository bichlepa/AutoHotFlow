#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Condition_List_Contains_Element extends ElementBase {
    static Name => "List_Contains_Element"
    static Category => "Conditions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for List_Contains_Element
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
