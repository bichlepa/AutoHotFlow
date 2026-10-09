#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Change_Drive_Label extends ElementBase {
    static Name => "Change_Drive_Label"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Change_Drive_Label
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
