#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Loop_SimpleLoop extends ElementBase {
    static Name => "SimpleLoop"
    static Category => "Loops"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for SimpleLoop
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
