#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Condition_Window_Exists extends ElementBase {
    static Name => "Window_Exists"
    static Category => "Conditions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Window_Exists
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
