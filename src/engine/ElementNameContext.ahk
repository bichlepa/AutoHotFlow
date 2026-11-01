#Requires AutoHotkey v2.0

; The context that the engine gives to GenerateName(ctx, params) of an element class when it generates the name of an
; element that another element changed (WI-0129, Engine.SetElementParFromElement). It has the members that the names of
; the flow elements read (ELEMENT-API-V2 3.6): the own flow and element, the names of flows and of triggers. A name that
; is not known is "" (the caller shows the ID). It is not an element context: nothing in it runs or waits.
class ElementNameContext {
    __New(flowId, elementId, flows) {
        this.flowId := flowId
        this.elementId := elementId
        this._flows := flows            ; the FlowTable of the engine (Get)
    }

    ; The name of a flow, "" if the flow is not loaded.
    FlowName(flowId) {
        rec := this._flows.Get(flowId)
        return IsObject(rec) ? String(rec.Def.Name) : ""
    }

    ; The name of a trigger of a flow, "" if it is not known.
    TriggerName(flowId, triggerId) {
        rec := this._flows.Get(flowId)
        if (!IsObject(rec))
            return ""
        el := rec.Def.Element(triggerId)
        if (!(el is Map))
            return ""
        name := el.Get("name", "")
        return IsObject(name) ? "" : String(name)
    }
}
