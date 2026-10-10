#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Loop_Loop_Through_Files extends ElementBase {
    static Name => "Loop_Through_Files"
    static Category => "Loops"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Loop_Through_Files
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
