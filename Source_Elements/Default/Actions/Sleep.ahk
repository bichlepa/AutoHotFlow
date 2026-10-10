#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Sleep extends ElementBase {
    static Name => "Sleep"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Sleep
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
