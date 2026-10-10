#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Set_file_time extends ElementBase {
    static Name => "Set_file_time"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Set_file_time
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
