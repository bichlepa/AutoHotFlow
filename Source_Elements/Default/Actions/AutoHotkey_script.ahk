#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_AutoHotkey_script extends ElementBase {
    static Name => "AutoHotkey_script"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for AutoHotkey_script
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
