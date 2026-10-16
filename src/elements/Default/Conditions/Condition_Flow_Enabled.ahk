#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FlowSwitchOps.ahk

; Condition Flow enabled of the package Default (WI-0065, decision E0056): "yes" if the chosen triggers of a flow are
; enabled, else "no". Specification: the help text of v1 (help/en/Conditions/Flow_Enabled.html). Class ID, parameter IDs
; and the language keys of the v1 names are those of v1 (Source_Elements/Default/Conditions/Flow_Enabled.ahk).
;
;   ThisFlow        1: the flow of this element; 0: the flow flowID (the ID of a flow, its file name)
;   WhichTrigger    "Any" (label "The flow is active"): at least one trigger that switches with the flow is enabled (the
;                   v1 meaning, and the flow is active in the sense of evt.flow.state)
;                   "AnyTrigger" (new): at least one trigger is enabled, those that switch on their own included
;                   "AllTriggers" (new): every trigger is enabled (a flow without triggers gives "no")
;                   "AnyIndependent" (new): at least one trigger that does not switch with the flow is enabled
;                   "Default" and "Specified": the target state of that trigger (not whether it is armed)
;   triggerID       the ID of the trigger for "Specified"
;
; The state asked for is the target state (E0056, WI-0060), not the arming (WI-0062). A choice that matches no trigger
; gives "no" and an f1 log entry. A flow or trigger that does not exist ends the element with "exception", as in v1.
class Condition_Flow_Enabled extends AhfElement {
    static Mode := "inline"
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Flow_Enabled")
    static Category() => Lang("Flow_control")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Which flow")},
        {type: "Checkbox", id: "ThisFlow", default: 1, label: Lang("This flow (%1%)", IsObject(ctx) ? ctx.flowId : "")},
        {type: "DropDown", id: "flowID", default: "", result: "enum", choices: [], enum: []},
        {type: "Label", label: Lang("Which trigger")},
        {type: "Radio", id: "WhichTrigger", default: "Any", result: "enum"
            , choices: [Lang("The flow is active"), Lang("Any trigger"), Lang("All triggers"), Lang("Triggers of their own")
                , Lang("Default trigger"), Lang("Specified trigger")]
            , enum: ["Any", "AnyTrigger", "AllTriggers", "AnyIndependent", "Default", "Specified"]},
        {type: "DropDown", id: "triggerID", default: "", result: "enum", choices: [], enum: []}
    ]

    static Choices := ["Any", "AnyTrigger", "AllTriggers", "AnyIndependent", "Default", "Specified"]

    ; "Flow enabled: <flow> - <triggers>" (v1 name). The editor has no access to the other flows (S0007), so the ID of the
    ; flow stands for its name.
    static GenerateName(ctx, params) {
        flowLabel := FlowSwitchOps.IsOn(FlowSwitchOps.Par(params, "ThisFlow", 1)) ? Lang("This flow")
            : String(FlowSwitchOps.Par(params, "flowID", ""))
        which := FlowSwitchOps.Choice(FlowSwitchOps.Par(params, "WhichTrigger", "Any"), this.Choices)
        switch which {
            case "Any": triggerLabel := Lang("The flow is active")
            case "AnyTrigger": triggerLabel := Lang("Any trigger")
            case "AllTriggers": triggerLabel := Lang("All triggers")
            case "AnyIndependent": triggerLabel := Lang("Triggers of their own")
            case "Default": triggerLabel := Lang("Default trigger")
            case "Specified": triggerLabel := String(FlowSwitchOps.Par(params, "triggerID", ""))
            default: triggerLabel := ""
        }
        return Lang("Flow_Enabled") ": " flowLabel " - " triggerLabel
    }

    ; v1: the flow list is off for "This flow", the trigger list is off unless "Specified" is chosen. Filling the lists of
    ; flows and triggers needs the editor (S0007).
    static CheckSettings(form, params, staticValues) {
        form.Enable("flowID", !FlowSwitchOps.IsOn(FlowSwitchOps.Par(params, "ThisFlow", 1)))
        form.Enable("triggerID", FlowSwitchOps.Par(params, "WhichTrigger", "Any") = "Specified")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        flowId := FlowSwitchOps.IsOn(p.ThisFlow) ? ctx.flowId : String(p.flowID)
        if (!ctx.FlowExists(flowId))
            throw ElementError(Lang("Flow '%1%' does not exist", flowId))
        which := FlowSwitchOps.Choice(p.WhichTrigger, this.Choices)
        switch which {
            case "Default", "Specified":
                triggerId := FlowSwitchOps.OneTrigger(ctx, flowId, which, p.triggerID)
                ctx.Finish(ctx.IsTriggerEnabled(flowId, triggerId) ? "yes" : "no")
                return
            case "Any":
                scope := "following"
            case "AnyTrigger", "AllTriggers":
                scope := "all"
            case "AnyIndependent":
                scope := "independent"
            default:
                throw ElementError(FlowSwitchOps.InvalidParameter("WhichTrigger"))
        }
        counts := ctx.CountTriggers(flowId, scope)
        if (counts["total"] = 0)
            ctx.Log("f1", "flow '" flowId "' has no trigger for the choice '" which "'; the answer is 'no'")
        if (which = "AllTriggers")
            yes := counts["total"] > 0 && counts["enabled"] = counts["total"]
        else
            yes := counts["enabled"] > 0
        ctx.Finish(yes ? "yes" : "no")
    }
}
