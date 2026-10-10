#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Read_From_Ini extends ElementBase {
    static Name => "Read_From_Ini"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Read_From_Ini
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
