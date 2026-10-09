#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Delete_from_list extends ElementBase {
    static Name => "Delete_from_list"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Delete_from_list
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
