#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Loop_Work_through_a_list extends ElementBase {
    static Name => "Work_through_a_list"
    static Category => "Loops"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Work_through_a_list
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
