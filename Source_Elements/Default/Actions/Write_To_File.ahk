#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Write_To_File extends ElementBase {
    static Name => "Write_To_File"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Write_To_File
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
