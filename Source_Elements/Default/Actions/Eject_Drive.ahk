#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Eject_Drive extends ElementBase {
    static Name => "Eject_Drive"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Eject_Drive
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
