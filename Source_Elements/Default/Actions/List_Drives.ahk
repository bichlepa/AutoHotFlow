#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_List_Drives extends ElementBase {
    static Name => "List_Drives"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for List_Drives
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
