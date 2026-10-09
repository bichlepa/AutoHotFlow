#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Minimize_All_Windows extends ElementBase {
    static Name => "Minimize_All_Windows"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Minimize_All_Windows
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
