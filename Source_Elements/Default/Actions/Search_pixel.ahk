#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Search_pixel extends ElementBase {
    static Name => "Search_pixel"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Search_pixel
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
