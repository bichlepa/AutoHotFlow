#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Stop flow of the package Default (WI-0055): stops all instances of a flow. Specification: the help text of v1
; (help/en/Actions/Stop_Flow.html). Class ID, parameter ID and language keys are those of v1
; (Source_Elements/Default/Actions/Stop_Flow.ahk).
;
;   flowID   the ID of the flow (its file name); v1 filled in the own flow when the field was empty, in the editor
;
; Running and waiting instances (policy wait) are stopped; they end with the reason "element.stopflow" (PROTOCOL 4.3).
; The element finishes first, then it stops the flow (as v1: its stop marks the instances, then the element finishes): when
; it stops its own flow, its own instance ends too and nothing behind the element runs. A flow that does not exist ends
; the element with "exception".
class Action_Stop_Flow extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Stop_Flow")
    static Category() => Lang("Flow_control")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Which flow")},
        {type: "DropDown", id: "flowID", default: "", result: "enum", choices: [], enum: []}
    ]

    ; "Stop flow - <flow>" (v1 showed the name of the flow; the editor has no access to other flows yet, S0007)
    static GenerateName(ctx, params) {
        return Lang("Stop_Flow") " - " ((IsObject(params) && params.HasProp("flowID")) ? params.flowID : "")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        flowId := String(p.flowID)
        if (!ctx.FlowExists(flowId))
            throw ElementError(Lang("Flow '%1%' does not exist", flowId))
        ctx.Finish("normal")
        ctx.StopFlow(flowId)
    }
}
