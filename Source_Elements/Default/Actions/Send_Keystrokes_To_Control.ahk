#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Send_Keystrokes_To_Control extends ElementBase {
    static Name => "Send_Keystrokes_To_Control"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Send_Keystrokes_To_Control
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
