#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ..\..\core\Json.ahk

; Flow model in the v1 file format (WI-08, ARCHITECTURE 7, v2-phase2-final:work_items/phase2/README.md).
;
; Reads the parsed v1 flow JSON (Json.Parse, types kept) and offers lookups by element and
; connection ID. Nothing is changed: Raw is the parsed Map, unknown keys stay in it.
;
; Facts from v1 files (verified by reading the 23 files in v1/AppData/Saved Flows):
;   - allElements and allConnections are objects keyed by ID; the ID field equals the key.
;   - element "type" is spelled in several ways ("trigger", "Trigger", "Action", "action",
;     "Condition", "Loop", "loop"). Kinds are compared lowercased here.
;   - connection "ConnectionType" is "normal", "Normal", "Yes", "No", "Exception" (v1 compares
;     case-insensitively, see v1/Source_Execution/Execution Task/Execution Task.ahk:119).
;   - some flows contain dangling connections (empty or unknown from/to). They are listed in
;     Dangling and never returned by FromConnections (open question 3 in WI-08).
;
; Maps keyed by ID use CaseSense "Off", as the v1 object keys do.
class FlowDefinition {
    ; Builds the model from the text of a flow file. Errors are AhfError with a readable
    ; message, never a crash. rev is the committed revision (see ARCHITECTURE 4.2).
    static FromText(flowId, text, rev := 1) {
        try {
            raw := Json.Parse(text)
        } catch as e {
            throw AhfError("flow '" flowId "' is not valid JSON: " e.Message, ErrCode.BAD_JSON)
        }
        if (!(raw is Map))
            throw AhfError("flow '" flowId "': the file root is not an object", ErrCode.BAD_PAYLOAD)
        return FlowDefinition(flowId, raw, rev)
    }

    __New(flowId, raw, rev := 1) {
        if (!(raw is Map))
            throw AhfError("FlowDefinition: raw flow is not a Map", ErrCode.BAD_PAYLOAD)
        this.FlowId := flowId
        this.Raw := raw
        this.Rev := rev
        this.Name := FlowDefinition.TextOf(flowId, raw, "name", "")
        this.Category := FlowDefinition.TextOf(flowId, raw, "category", "")
        this.Dangling := []

        this._elements := FlowDefinition.NewIndex()
        this._kinds := FlowDefinition.NewIndex()
        this._classes := FlowDefinition.NewIndex()
        this._connections := FlowDefinition.NewIndex()
        this._from := FlowDefinition.NewIndex()

        elements := FlowDefinition.RequireMap(flowId, raw, "allElements")
        connections := FlowDefinition.RequireMap(flowId, raw, "allConnections")

        for id, el in elements {
            if (!(el is Map))
                throw AhfError("flow '" flowId "': element '" id "' is not an object", ErrCode.BAD_PAYLOAD)
            if (!el.Has("type") || !el.Has("class"))
                throw AhfError("flow '" flowId "': element '" id "' has no type or class", ErrCode.BAD_PAYLOAD)
            this._elements[id] := el
            this._kinds[id] := StrLower(FlowDefinition.TextOf(flowId, el, "type", ""))
            this._classes[id] := FlowDefinition.TextOf(flowId, el, "class", "")
            this._from[id] := []
        }

        for id, c in connections {
            if (!(c is Map))
                throw AhfError("flow '" flowId "': connection '" id "' is not an object", ErrCode.BAD_PAYLOAD)
            if (!c.Has("ConnectionType"))
                throw AhfError("flow '" flowId "': connection '" id "' has no ConnectionType", ErrCode.BAD_PAYLOAD)
            this._connections[id] := c
            from := FlowDefinition.TextOf(flowId, c, "from", "")
            to := FlowDefinition.TextOf(flowId, c, "to", "")
            if (this._elements.Has(from) && this._elements.Has(to))
                this._from[from].Push(id)
            else
                this.Dangling.Push(id)
        }
    }

    ; True if an element with this ID exists.
    HasElement(elementId) {
        return this._elements.Has(elementId)
    }

    ; Lowercased element kind: "trigger", "action", "condition", "loop". "" if unknown ID.
    ElementKind(elementId) {
        return this._kinds.Get(elementId, "")
    }

    ; Class name as written in the file (e.g. "action_Encode_string"). "" if unknown ID.
    ElementClass(elementId) {
        return this._classes.Get(elementId, "")
    }

    ; The element Map as parsed (keys ID, class, type, pars, ...). "" if unknown ID.
    Element(elementId) {
        return this._elements.Get(elementId, "")
    }

    ; The connection Map as parsed. "" if unknown ID.
    Connection(connectionId) {
        return this._connections.Get(connectionId, "")
    }

    ; IDs of valid connections that start at the element, in the enumeration order of the Map
    ; (sorted by ID). Dangling connections are not included. Empty array for unknown IDs.
    FromConnections(elementId) {
        ids := []
        for id in this._from.Get(elementId, []) {
            ids.Push(id)
        }
        return ids
    }

    ; IDs of all elements of kind "trigger", in Map enumeration order (sorted by ID).
    Triggers() {
        ids := []
        for id, kind in this._kinds {
            if (kind = "trigger")
                ids.Push(id)
        }
        return ids
    }

    ; Creates an index Map with case-insensitive keys, as v1 object keys are.
    static NewIndex() {
        m := Map()
        m.CaseSense := "Off"
        return m
    }

    static RequireMap(flowId, raw, key) {
        if (!raw.Has(key))
            throw AhfError("flow '" flowId "': key '" key "' is missing", ErrCode.BAD_PAYLOAD)
        value := raw[key]
        if (!(value is Map))
            throw AhfError("flow '" flowId "': key '" key "' is not an object", ErrCode.BAD_PAYLOAD)
        return value
    }

    ; Reads a text value. Missing keys give default. Numbers become text, objects are an error.
    static TextOf(flowId, m, key, default) {
        if (!m.Has(key))
            return default
        value := m[key]
        if (IsObject(value))
            throw AhfError("flow '" flowId "': key '" key "' must be a value, not an object", ErrCode.BAD_PAYLOAD)
        return String(value)
    }
}
