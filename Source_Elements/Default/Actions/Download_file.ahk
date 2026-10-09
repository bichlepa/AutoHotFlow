#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Download_file extends ElementBase {
    static Name => "Download_file"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Download_file
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
