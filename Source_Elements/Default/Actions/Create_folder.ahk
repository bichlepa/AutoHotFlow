#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Create_folder extends ElementBase {
    static Name => "Create_folder"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Create_folder
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
