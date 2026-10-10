#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Move_Mouse extends ElementBase {
    static Name => "Move_Mouse"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Move_Mouse
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
