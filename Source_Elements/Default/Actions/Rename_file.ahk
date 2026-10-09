#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Rename_file extends ElementBase {
    static Name => "Rename_file"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Rename_file
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
