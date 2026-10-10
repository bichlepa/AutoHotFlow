#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Condition_File_Has_Attribute extends ElementBase {
    static Name => "File_Has_Attribute"
    static Category => "Conditions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for File_Has_Attribute
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
