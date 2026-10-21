#Requires AutoHotkey v2.0
#Include SceneBuilder.ahk

; The context of the element settings in the editor (WI-0107, doc/ELEMENT-API-V2.md section 3, "editor ctx"): what the element
; classes read in Parameters(ctx), in CheckSettings (form.ctx) and in GenerateName(ctx, params): the own flow and the other
; flows, their names and their triggers (v1 x_GetListOfFlowIDs, x_getFlowName, x_getAllElementIDsOfType, x_getElementName).
;
; The own flow comes from the draft (the newest state, unsaved changes included). Other flows come from EditorFlowCatalog:
; a list that is not known yet is empty (its request is on its way; the settings window is told when it arrives), and a
; name that is not known yet is "" (the caller shows the ID). The class of an element is never asked by the settings
; window itself; the only writes are those of the form (EditorSettings).
class EditorElementCtx {
    __New(model, catalog, elementId := "") {
        this.model := model
        this.catalog := catalog
        this.flowId := model.flowId
        this.elementId := elementId
    }

    ; The flows: an Array of Maps "id" and "name" in the order of the engine. The own flow is in it even before the list
    ; of the engine is known. The name is "" when it is not known.
    Flows() {
        out := []
        own := false
        for f in this.catalog.flows {
            if (f["flowId"] = this.flowId) {
                own := true
                out.Push(Map("id", this.flowId, "name", this._OwnName(f["name"])))
            } else {
                out.Push(Map("id", f["flowId"], "name", f["name"]))
            }
        }
        if (!own)
            out.InsertAt(1, Map("id", this.flowId, "name", this._OwnName("")))
        return out
    }

    ; The name of a flow, "" when it is not known.
    FlowName(flowId) {
        if (flowId = this.flowId)
            return this._OwnName("")
        for f in this.catalog.flows {
            if (f["flowId"] = flowId)
                return f["name"]
        }
        return ""
    }

    ; The triggers of a flow: an Array of Maps "elementId", "name" and "manual" (the class Default.Trigger_Manual), sorted by
    ; ID. manualOnly: only the manual triggers (the choice of Execute flow). Empty while the list of another flow is not known.
    Triggers(flowId, manualOnly := false) {
        out := []
        if (flowId = "")
            return out
        if (flowId = this.flowId) {
            for t in this._OwnTriggers()
                if (!manualOnly || t["manual"])
                    out.Push(t)
            return out
        }
        list := this.catalog.Triggers(flowId)
        if (!(list is Array))
            return out
        for t in list {
            if (!manualOnly || t["manual"])
                out.Push(t)
        }
        return out
    }

    ; The name of a trigger of a flow, "" when it is not known.
    TriggerName(flowId, elementId) {
        for t in this.Triggers(flowId) {
            if (t["elementId"] = elementId)
                return t["name"]
        }
        return ""
    }

    _OwnName(fallback) {
        name := this.model.name
        return (name = "") ? fallback : name
    }

    ; The triggers of the draft (the own flow), sorted by ID.
    _OwnTriggers() {
        out := []
        root := this.model.draft.root
        if (!(root is Map) || !(root.Get("allElements", "") is Map))
            return out
        for id, el in root["allElements"] {
            if (!(el is Map) || StrLower(SceneBuilder.TextOf(el, "type")) != "trigger")
                continue
            className := SceneBuilder.TextOf(el, "class")
            package := SceneBuilder.TextOf(el, "package")
            entry := Map("elementId", id, "name", SceneBuilder.TextOf(el, "name")
                , "manual", SceneBuilder.IsManualTrigger(className, package))
            at := out.Length + 1                    ; insert in ID order (Array has no Sort in AHK v2)
            loop out.Length {
                if (StrCompare(out[A_Index]["elementId"], id) > 0) {
                    at := A_Index
                    break
                }
            }
            out.InsertAt(at, entry)
        }
        return out
    }
}
