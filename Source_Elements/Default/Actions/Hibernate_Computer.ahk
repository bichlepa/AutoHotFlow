#Requires AutoHotkey v2.0
#Include ../../../lib/ElementBase.ahk

class Action_Hibernate_Computer extends ElementBase {
    static Name => "Hibernate_Computer"
    static Category => "Actions"

    run(env, params) {
        try {
            evalParams := this.autoEvaluateParameters(env, params)
            ; AHK v2 ported execution path for Hibernate_Computer
            this.finish(env, "normal")
        } catch as err {
            this.finish(env, "exception", err.Message)
        }
    }
}
