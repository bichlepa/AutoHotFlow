#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Convert_list_to_string extends ElementBase {
    static Name => "Convert_list_to_string"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Convert_list_to_string
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
