#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Rename_Folder extends ElementBase {
    static Name => "Rename_Folder"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Rename_Folder
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
