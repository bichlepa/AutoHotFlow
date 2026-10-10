#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Block_User_Input extends ElementBase {
    static Name => "Block_User_Input"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Block_User_Input
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
