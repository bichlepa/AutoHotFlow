#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Condition Flow executing of the package Default (WI-0055): "yes" if the flow is executing, else "no". Specification:
; the help text of v1 (help/en/Conditions/Flow_Running.html). Class ID, parameter ID and language keys are those of v1
; (Source_Elements/Default/Conditions/Flow_Running.ahk).
;
;   flowID   the ID of the flow (its file name)
;
; A flow is executing while it has an instance that runs, is stopping, or waits for its turn (policy wait): the state
; "executing" that the engine reports in evt.flow.state. The own flow is always executing. A flow that does not exist
; ends the element with "exception".
class Condition_Flow_Running extends AhfElement {
    static Mode := "inline"
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Flow_Executing")
    static Category() => Lang("Flow_control")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Which flow")},
        {type: "DropDown", id: "flowID", default: "", result: "enum", choices: [], enum: []}
    ]

    ; "Flow executing - <flow>" (v1 showed the name of the flow; the editor has no access to other flows yet, S0007)
    static GenerateName(ctx, params) {
        return Lang("Flow_Executing") " - " ((IsObject(params) && params.HasProp("flowID")) ? params.flowID : "")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        flowId := String(p.flowID)
        if (!ctx.FlowExists(flowId))
            throw ElementError(Lang("Flow '%1%' does not exist", flowId))
        ctx.Finish(ctx.IsFlowExecuting(flowId) ? "yes" : "no")
    }
}
