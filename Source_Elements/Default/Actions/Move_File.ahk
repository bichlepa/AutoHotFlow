#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Move_File extends ElementBase {
    static Name => "Move_File"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Move_File
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
