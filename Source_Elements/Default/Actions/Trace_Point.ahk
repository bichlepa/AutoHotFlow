#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Trace_Point extends ElementBase {
    static Name => "Trace_Point"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Trace_Point
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
