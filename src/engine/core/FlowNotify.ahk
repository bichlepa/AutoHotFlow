#Requires AutoHotkey v2.0
#Include ..\..\core\Json.ahk

; The per-flow switch of the notices of unhandled exceptions (WI-0109, PROTOCOL 4.2 flow settings, REQ-USE-080). The key is
; flowSettings.notifyUnhandledErrors: JSON true or false decides for the flow, the value "default" or a missing key takes the
; global setting notifyUnhandledErrors (WI-0077). A value of another form counts as the default, as the limits do (4.2).
; Pure: no window, no state. The notice itself is sent by the engine (Engine.FlowException).
class FlowNotify {
    static KEY := "notifyUnhandledErrors"

    ; True when the notices of the flow are on. def: FlowDefinition (its Raw). globalOn: the global setting (true or false).
    static On(def, globalOn) {
        settings := def.Raw.Get("flowSettings", "")
        if (!(settings is Map) || !settings.Has(FlowNotify.KEY))
            return globalOn ? true : false
        v := settings[FlowNotify.KEY]
        if (v == Json.True || (!IsObject(v) && (v = 1 || v = "1" || v = "true")))
            return true
        if (v == Json.False || (!IsObject(v) && (v = 0 || v = "0" || v = "false")))
            return false
        return globalOn ? true : false
    }
}
