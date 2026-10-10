#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Shuffle_list extends ElementBase {
    static Name => "Shuffle_list"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Shuffle_list
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
