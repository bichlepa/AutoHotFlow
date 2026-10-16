#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk
#Include ..\..\..\core\Lang.ahk

; The shared rules of the elements Set flow status (Action_Set_Flow_Status) and Flow enabled (Condition_Flow_Enabled),
; WI-0065, decision E0056: the choice of the triggers, the parameters that both have, and the one trigger of a choice
; Default or Specified. The stored values are those of v1 ("Any", "Default", "Specified"); the choices that v2 adds are
; named here as well. Each element chooses the scope of its choice (the scopes of FlowRecord.TriggersOf).
class FlowSwitchOps {
    ; A checkbox: 1, "1" and any other true value are on; 0, "0" and "" are off.
    static IsOn(value) => IsObject(value) ? false : (value ? true : false)

    ; The value of a parameter of params, or fallback when params has none.
    static Par(params, name, fallback) => (IsObject(params) && params.HasProp(name)) ? params.%name% : fallback

    ; The choice that the stored value names, as written in allowed (the comparison ignores case, as "=" does); "" if the
    ; value names none of them. An object (a list or a map) is never a choice.
    static Choice(value, allowed) {
        if (IsObject(value))
            return ""
        for name in allowed {
            if (value = name)
                return name
        }
        return ""
    }

    ; The one trigger of a choice "Default" (the default manual trigger of the flow) or "Specified" (triggerId). Throws
    ; ElementError with the texts of v1 when the flow has no default manual trigger, the trigger ID is empty, or the flow
    ; has no trigger with that ID.
    static OneTrigger(ctx, flowId, which, triggerId) {
        if (which = "Default") {
            found := ctx.DefaultTrigger(flowId)
            if (found = "")
                throw ElementError(Lang("Flow '%1%' does not have any manual trigger.", flowId))
            return found
        }
        found := String(triggerId)
        if (found = "")
            throw ElementError(Lang("Trigger ID is empty"))
        if (!ctx.HasTrigger(flowId, found))
            throw ElementError(Lang("Flow '%1%' does not have the trigger with ID '%2%'.", flowId, found))
        return found
    }

    ; The text of a parameter that is not valid (the v1 text of x_Parameter invalid).
    static InvalidParameter(name) => Lang("Unexpected Error!") " " Lang("Parameter '%1%' is invalid.", name)
}
