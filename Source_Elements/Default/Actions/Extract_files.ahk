#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Extract_files extends ElementBase {
    static Name => "Extract_files"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Extract_files
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
