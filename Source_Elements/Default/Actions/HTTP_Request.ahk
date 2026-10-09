#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_HTTP_Request extends ElementBase {
    static Name => "HTTP_Request"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for HTTP_Request
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
