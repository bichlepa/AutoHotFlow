#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Condition_String_Contains_Text extends ElementBase {
    static Name => "String_Contains_Text"
    static Category => "Conditions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for String_Contains_Text
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
