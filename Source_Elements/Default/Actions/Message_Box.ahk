#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Message_Box extends ElementBase {
    static Name => "Message_Box"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Message_Box
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
