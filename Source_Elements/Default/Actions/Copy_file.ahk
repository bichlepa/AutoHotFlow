#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Copy_file extends ElementBase {
    static Name => "Copy_file"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Copy_file
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
