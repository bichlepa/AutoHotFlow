#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Trace_Point_Check extends ElementBase {
    static Name => "Trace_Point_Check"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Trace_Point_Check
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
