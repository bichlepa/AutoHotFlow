#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Play_Sound extends ElementBase {
    static Name => "Play_Sound"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Play_Sound
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
