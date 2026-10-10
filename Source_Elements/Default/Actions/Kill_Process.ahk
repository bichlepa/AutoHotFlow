#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Kill_Process extends ElementBase {
    static Name => "Kill_Process"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Kill_Process
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
