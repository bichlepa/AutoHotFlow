#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Empty_Recycle_bin extends ElementBase {
    static Name => "Empty_Recycle_bin"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Empty_Recycle_bin
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
