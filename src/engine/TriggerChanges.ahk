#Requires AutoHotkey v2.0
#Include ..\core\Json.ahk
#Include core\FlowDefinition.ahk

; The change of the triggers that a patch makes (WI-0094, PROTOCOL 4.2 "Triggers", E0092). Pure: compares two
; definitions of one flow and says which trigger was added, removed or changed. The effects (arming, enabled state,
; events) are the engine's (Engine._ApplyTriggerChanges).
;
; A trigger is changed when its class, its package, its parameters or followsFlow differ. The position, the name and
; StandardName are not part of the comparison. The parameters are compared as text with their keys sorted (Json.Stringify)
; and case-sensitively: "Hello" and "hello" are different parameters.
class TriggerChanges {
    ; Returns Map("added", Array, "removed", Array, "changed", Array) of trigger IDs, each in the order of the flow.
    static Diff(before, after) {
        out := Map("added", [], "removed", [], "changed", [])
        for triggerId in before.Triggers() {
            if (after.ElementKind(triggerId) != "trigger")
                out["removed"].Push(triggerId)
        }
        for triggerId in after.Triggers() {
            if (before.ElementKind(triggerId) != "trigger")
                out["added"].Push(triggerId)
            else if (TriggerChanges.Differs(before, after, triggerId))
                out["changed"].Push(triggerId)
        }
        return out
    }

    ; True if the trigger, which is a trigger in both definitions, differs in one of the compared parts.
    static Differs(before, after, triggerId) {
        if (before.ElementClass(triggerId) != after.ElementClass(triggerId))
            return true
        if (TriggerChanges._PackageOf(before, triggerId) != TriggerChanges._PackageOf(after, triggerId))
            return true
        if (before.FollowsFlow(triggerId) != after.FollowsFlow(triggerId))
            return true
        return Json.Stringify(TriggerChanges._ParsOf(before, triggerId)) !== Json.Stringify(TriggerChanges._ParsOf(after, triggerId))
    }

    ; The package of an element; a missing one is "Default" (E0045), as the registry reads it.
    static _PackageOf(def, triggerId) {
        package := def.ElementPackage(triggerId)
        return package = "" ? "Default" : package
    }

    static _ParsOf(def, triggerId) {
        elem := def.Element(triggerId)
        return (elem is Map) ? elem.Get("pars", Map()) : Map()
    }
}
