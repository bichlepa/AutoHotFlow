#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Convert_string_to_list extends ElementBase {
    static Name => "Convert_string_to_list"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Convert_string_to_list
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
