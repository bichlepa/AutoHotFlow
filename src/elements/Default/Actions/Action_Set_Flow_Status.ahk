#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FlowSwitchOps.ahk

; Action Set flow status of the package Default (WI-0065, decision E0056): enables or disables triggers of a flow.
; Specification: the help text of v1 (help/en/Actions/Set_Flow_Status.html). Class ID, parameter IDs and the language
; keys of the v1 names are those of v1 (Source_Elements/Default/Actions/Set_Flow_Status.ahk).
;
;   Enable          "Enable" or "Disable"
;   ThisFlow        1: the flow of this element; 0: the flow flowID (the ID of a flow, its file name)
;   WhichTrigger    "Any" (label "The flow"): the triggers that switch with the flow, as cmd.flow.enable/disable (v1: every
;                   trigger, as every trigger of a v1 flow switches with the flow)
;                   "All" (new): every trigger, those that switch on their own included; disabling with it is the complete
;                   switch-off (the element never asks, the manager does)
;                   "Independent" (new): every trigger that does not switch with the flow
;                   "Default" and "Specified": one trigger, of either kind
;   triggerID       the ID of the trigger for "Specified"
;
; A choice that matches no trigger (e.g. "Independent" in a flow without one) ends the element with "normal" and an f1
; log entry. A flow or trigger that does not exist, or a trigger ID that is no trigger of the flow, ends it with
; "exception". The switch is saved and armed by the engine (ctx.SetTriggers); a running instance is not affected, also
; not the instance of the trigger that the element switches (REQ-EXE-070). A flow whose state cannot be read (E0063) ends
; the element with "exception" and changes nothing.
class Action_Set_Flow_Status extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Set_Flow_Status")
    static Category() => Lang("Flow_control")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("New state")},
        {type: "Radio", id: "Enable", default: "Enable", result: "enum", choices: [Lang("Enable"), Lang("Disable")]
            , enum: ["Enable", "Disable"]},
        {type: "Label", label: Lang("Which flow")},
        {type: "Checkbox", id: "ThisFlow", default: 1, label: Lang("This flow (%1%)", IsObject(ctx) ? ctx.flowId : "")},
        {type: "DropDown", id: "flowID", default: "", result: "enum", choices: [], enum: []},
        {type: "Label", label: Lang("Which trigger")},
        {type: "Radio", id: "WhichTrigger", default: "Any", result: "enum"
            , choices: [Lang("The flow"), Lang("All triggers"), Lang("Triggers of their own"), Lang("Default trigger")
                , Lang("Specified trigger")]
            , enum: ["Any", "All", "Independent", "Default", "Specified"]},
        {type: "DropDown", id: "triggerID", default: "", result: "enum", choices: [], enum: []}
    ]

    static Choices := ["Any", "All", "Independent", "Default", "Specified"]

    ; "Set flow status: Enable - <flow> - <triggers>" (v1 name). The editor has no access to the other flows (S0007),
    ; so the ID of the flow stands for its name.
    static GenerateName(ctx, params) {
        enableText := (FlowSwitchOps.Par(params, "Enable", "Enable") = "Disable") ? Lang("Disable") : Lang("Enable")
        flowLabel := FlowSwitchOps.IsOn(FlowSwitchOps.Par(params, "ThisFlow", 1)) ? Lang("This flow")
            : String(FlowSwitchOps.Par(params, "flowID", ""))
        which := FlowSwitchOps.Choice(FlowSwitchOps.Par(params, "WhichTrigger", "Any"), this.Choices)
        switch which {
            case "Any": triggerLabel := Lang("The flow")
            case "All": triggerLabel := Lang("All triggers")
            case "Independent": triggerLabel := Lang("Triggers of their own")
            case "Default": triggerLabel := Lang("Default trigger")
            case "Specified": triggerLabel := String(FlowSwitchOps.Par(params, "triggerID", ""))
            default: triggerLabel := ""
        }
        return Lang("Set_Flow_Status") " - " enableText ": " flowLabel " - " triggerLabel
    }

    ; v1: the flow list is off for "This flow", the trigger list is off unless "Specified" is chosen. Filling the lists of
    ; flows and triggers needs the editor (S0007).
    static CheckSettings(form, params, staticValues) {
        form.Enable("flowID", !FlowSwitchOps.IsOn(FlowSwitchOps.Par(params, "ThisFlow", 1)))
        form.Enable("triggerID", FlowSwitchOps.Par(params, "WhichTrigger", "Any") = "Specified")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        switch String(p.Enable) {
            case "Enable": enable := true
            case "Disable": enable := false
            default: throw ElementError(FlowSwitchOps.InvalidParameter("Enable"))
        }
        flowId := FlowSwitchOps.IsOn(p.ThisFlow) ? ctx.flowId : String(p.flowID)
        if (!ctx.FlowExists(flowId))
            throw ElementError(Lang("Flow '%1%' does not exist", flowId))
        which := FlowSwitchOps.Choice(p.WhichTrigger, this.Choices)
        if (which = "")
            throw ElementError(FlowSwitchOps.InvalidParameter("WhichTrigger"))
        if (which = "Default" || which = "Specified") {
            triggerId := FlowSwitchOps.OneTrigger(ctx, flowId, which, p.triggerID)
            ctx.SetTriggerEnabled(flowId, triggerId, enable)
            ctx.Finish("normal")
            return
        }
        scope := (which = "Any") ? "following" : (which = "All") ? "all" : "independent"
        if (ctx.SetTriggers(flowId, scope, enable) = 0)
            ctx.Log("f1", "no trigger of flow '" flowId "' matches the choice '" which "'; nothing changed")
        ctx.Finish("normal")
    }
}
