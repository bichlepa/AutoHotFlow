#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Split_path extends ElementBase {
    static Name => "Split_path"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Split_path
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
