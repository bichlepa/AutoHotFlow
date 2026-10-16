#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Execute flow of the package Default (WI-0055): starts a flow, this one or another, at its default manual trigger
; or at a chosen trigger. Specification: the help text of v1 (help/en/Actions/Execute_Flow.html). Class ID, parameter
; IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Execute_Flow.ahk).
;
;   ThisFlow         1: the flow of this element; 0: the flow flowID (the ID of a flow, its file name)
;   WhichTrigger     "Default": the default manual trigger of the flow; "Specified": the trigger triggerID
;   SendLocalVars    1: the called instance starts with a copy of the instance variables of this instance
;   WaitToFinish     1: the element waits until the called instance has ended
;   ReturnVariables  1 (with WaitToFinish): the instance variables of the called instance at its end are set in this
;                    instance (a variable of the same name is overwritten)
;   SkipDisabled     1: a disabled trigger ends the element with "normal" instead of "exception"
;
; The help says that the trigger must be enabled. Until the triggers have a state of their own (S0003) a trigger is
; enabled when its flow is enabled (ctx.IsTriggerEnabled). The execution policy of the called flow decides about the
; start (skip: "exception"; wait: the instance is queued; stop: its running instances are stopped first, also this one
; when it is of the same flow). While the element waits, the engine runs on: the end of the called instance comes as a
; callback (ctx.CallFlow). The result is "normal" when the called instance finished, "exception" when one of its threads
; ended with an unhandled exception or when it was stopped (MIGRATION M-0063). When this element is stopped while it
; waits, the called instance runs on, as in v1.
class Action_Execute_Flow extends AhfElement {
    static Mode := "inline"
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Execute_Flow")
    static Category() => Lang("Flow_control")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Which flow")},
        {type: "Checkbox", id: "ThisFlow", default: 1, label: Lang("This flow (%1%)", IsObject(ctx) ? ctx.flowId : "")},
        {type: "DropDown", id: "flowID", default: "", result: "enum", choices: [], enum: []},
        {type: "Label", label: Lang("Which trigger")},
        {type: "Radio", id: "WhichTrigger", default: "Default", result: "enum"
            , choices: [Lang("Default trigger"), Lang("Specified trigger")], enum: ["Default", "Specified"]},
        {type: "DropDown", id: "triggerID", default: "", result: "enum", choices: [], enum: []},
        {type: "Label", label: Lang("Options")},
        {type: "Checkbox", id: "SendLocalVars", default: 1, label: Lang("Send local variables")},
        {type: "Checkbox", id: "WaitToFinish", default: 0, label: Lang("Wait for called flow to finish")},
        {type: "Checkbox", id: "ReturnVariables", default: 0, label: Lang("Return local variables to the calling flow")},
        {type: "Checkbox", id: "SkipDisabled", default: 0, label: Lang("Skip disabled flows without error")}
    ]

    ; "Execute flow: <flow> - <trigger>" (v1 Element_GenerateName). v1 showed the names of the flow and the trigger; the
    ; editor has no access to other flows yet (S0007), so the IDs stand for them.
    static GenerateName(ctx, params) {
        flowLabel := this.IsOn(this.Par(params, "ThisFlow", 1)) ? Lang("This flow") : this.Par(params, "flowID", "")
        if (this.WhichOf(this.Par(params, "WhichTrigger", "Default")) = "specified")
            triggerLabel := this.Par(params, "triggerID", "")
        else
            triggerLabel := Lang("Default trigger")
        return Lang("Execute_Flow") ": " flowLabel " - " triggerLabel
    }

    ; v1: the flow list is off for "This flow", the trigger list is off for the default trigger, and the returned
    ; variables need the wait. Filling the lists of flows and triggers needs the editor (S0007).
    static CheckSettings(form, params, staticValues) {
        form.Enable("flowID", !this.IsOn(this.Par(params, "ThisFlow", 1)))
        form.Enable("triggerID", this.WhichOf(this.Par(params, "WhichTrigger", "Default")) = "specified")
        form.Enable("ReturnVariables", this.IsOn(this.Par(params, "WaitToFinish", 0)))
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        flowId := this.IsOn(p.ThisFlow) ? ctx.flowId : String(p.flowID)
        if (!ctx.FlowExists(flowId))
            throw ElementError(Lang("Flow '%1%' does not exist", flowId))
        switch this.WhichOf(p.WhichTrigger) {
            case "default":
                triggerId := ctx.DefaultTrigger(flowId)
                if (triggerId = "")
                    throw ElementError(Lang("Flow '%1%' does not have any manual trigger.", flowId))
            case "specified":
                triggerId := String(p.triggerID)
                if (triggerId = "")
                    throw ElementError(Lang("Trigger ID is empty"))
                if (!ctx.HasTrigger(flowId, triggerId))
                    throw ElementError(Lang("Flow '%1%' does not have the trigger with ID '%2%'.", flowId, triggerId))
            default:
                throw ElementError(Lang("Unexpected Error!") " " Lang("Parameter '%1%' is invalid.", "WhichTrigger"))
        }
        if (!ctx.IsTriggerEnabled(flowId, triggerId)) {
            ; v1 wrote this message with two variables that were never set (the names were empty)
            message := Lang("Trigger '%1%' in '%2%' is disabled", triggerId, flowId)
            if (!this.IsOn(p.SkipDisabled))
                throw ElementError(message)
            ctx.Finish("normal", message)
            return
        }
        vars := this.IsOn(p.SendLocalVars) ? ctx.ExportInstanceVars() : ""
        if (!this.IsOn(p.WaitToFinish)) {
            ctx.CallFlow(flowId, triggerId, vars)
            ctx.Finish("normal")
            return
        }
        returnVars := this.IsOn(p.ReturnVariables)
        ; The element finishes when the called instance has ended (Ended); the engine runs on meanwhile.
        ctx.CallFlow(flowId, triggerId, vars, (outcome) => this.Ended(ctx, flowId, returnVars, outcome), returnVars)
    }

    ; The called instance has ended (the outcome of ctx.CallFlow).
    static Ended(ctx, flowId, returnVars, outcome) {
        if (returnVars && outcome["vars"] is Map)
            ctx.ImportInstanceVars(outcome["vars"])
        switch outcome["result"] {
            case "normal":
                ctx.Finish("normal")
            case "exception":
                ctx.Finish("exception", "The called flow '" flowId "' ended with an exception: " outcome["message"])
            default:
                ctx.Finish("exception", "The called flow '" flowId "' was stopped (" outcome["reason"] ").")
        }
    }

    ; "default" or "specified" for the stored value of WhichTrigger ("Default", "specified" in any case, or the index of
    ; the choice 1 or 2 that an old flow may hold); "" for anything else.
    static WhichOf(value) {
        if (IsObject(value))
            return ""
        if (value = "Default" || value == 1 || value == "1")
            return "default"
        if (value = "Specified" || value == 2 || value == "2")
            return "specified"
        return ""
    }

    ; A checkbox: 1, "1" and any other true value are on; 0, "0" and "" are off.
    static IsOn(value) => IsObject(value) ? false : (value ? true : false)

    static Par(params, name, fallback) => (IsObject(params) && params.HasProp(name)) ? params.%name% : fallback
}
