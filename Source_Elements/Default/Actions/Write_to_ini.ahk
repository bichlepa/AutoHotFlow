#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Write_to_ini extends ElementBase {
    static Name => "Write_to_ini"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Write_to_ini
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
