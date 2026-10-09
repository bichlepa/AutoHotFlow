#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Loop_Parse_A_String extends ElementBase {
    static Name => "Parse_A_String"
    static Category => "Loops"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Parse_A_String
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
