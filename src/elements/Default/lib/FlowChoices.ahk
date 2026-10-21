#Requires AutoHotkey v2.0

; The lists and the names of the flow elements in the settings (WI-0107, v1 x_GetListOfFlowIDs, x_getAllElementIDsOfType,
; x_getFlowName, x_getElementName). Editor only: the form has the editor context (form.ctx, EditorElementCtx, section 3 of
; ELEMENT-API-V2) with the flows and their triggers. Without a context (a new element of the class list, a test) the lists
; stay empty and the names are the IDs. A list of another flow that is not known yet is empty too; its answer comes later
; and the form runs CheckSettings again (EditorSettings.CatalogChanged).
class FlowChoices {
    ; The context of the form, or "" (no context, or no form with a context property).
    static CtxOf(form) {
        ctx := ""
        try ctx := form.ctx
        return IsObject(ctx) ? ctx : ""
    }

    ; The flow list of the form in the drop-down id: the texts "ID: name" and the enum values the IDs (v1).
    static Flows(form, id) {
        ctx := FlowChoices.CtxOf(form)
        if (!IsObject(ctx))
            return
        ids := []
        labels := []
        for f in ctx.Flows() {
            ids.Push(f["id"])
            labels.Push(FlowChoices.Label(f["id"], f["name"]))
        }
        form.SetChoices(id, labels, ids)
    }

    ; The trigger list of the flow flowId in the drop-down id: "ID: name" and the IDs. manualOnly: only the manual triggers.
    static Triggers(form, flowId, id, manualOnly := false) {
        ctx := FlowChoices.CtxOf(form)
        if (!IsObject(ctx))
            return
        ids := []
        labels := []
        if (flowId != "") {
            for t in ctx.Triggers(flowId, manualOnly) {
                ids.Push(t["elementId"])
                labels.Push(FlowChoices.Label(t["elementId"], t["name"]))
            }
        }
        form.SetChoices(id, labels, ids)
    }

    ; The flow that an element means: the flow of the context when thisFlowOn is true, else the text flowId.
    static Target(ctx, thisFlowOn, flowId) {
        if (thisFlowOn && IsObject(ctx))
            return ctx.flowId
        return FlowChoices.Text(flowId)
    }

    ; The name of a flow for a name of an element (its ID when the name is not known).
    static FlowName(ctx, flowId) {
        flowId := FlowChoices.Text(flowId)
        name := IsObject(ctx) ? ctx.FlowName(flowId) : ""
        return (name = "") ? flowId : name
    }

    ; The name of a trigger of a flow for a name of an element (its ID when the name is not known).
    static TriggerName(ctx, flowId, triggerId) {
        triggerId := FlowChoices.Text(triggerId)
        name := (IsObject(ctx) && flowId != "") ? ctx.TriggerName(flowId, triggerId) : ""
        return (name = "") ? triggerId : name
    }

    ; "ID: name", or the ID alone when the name is "".
    static Label(id, name) => (name = "") ? id : id ": " name

    ; The text of a parameter value ("" for a list or a map).
    static Text(value) => IsObject(value) ? "" : String(value)
}
