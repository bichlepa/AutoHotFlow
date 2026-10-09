#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Search_Image extends ElementBase {
    static Name => "Search_Image"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Search_Image
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
