#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ..\..\core\Json.ahk

; Flow model in the v1 file format (WI-0008, ARCHITECTURE 7, v2-phase2-final:work_items/phase2/README.md).
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
;     Dangling and never returned by FromConnections (open question 3 in WI-0008).
;
; Maps keyed by ID use CaseSense "Off", as the v1 object keys do.
class FlowDefinition {
    ; Written files (WI-0039, doc/ARCHITECTURE.md section 7): the root key "formatVersion" says that the file was saved by
    ; v2 (a file without it comes from v1); an element whose expression texts are still in v1 syntax carries the key
    ; "v1Text". Neither key is kept in Raw: Pending names the elements, ToFileText writes the keys.
    static FORMAT_KEY := "formatVersion"
    static FORMAT_VERSION := 2
    static MARKER_KEY := "v1Text"
    ; Key of an element (WI-0045, E0035): the places of its parameters that behave differently in v2, with MIGRATION IDs and
    ; the v1 text. Unlike v1Text it is an ordinary key of the element: it stays in Raw, so it is written back and
    ; clients see it (FlowExprConvert.Mark).
    static MIGRATION_KEY := "migration"
    ; The flow option "strictTypes" in flowSettings (E0034, WI-0042): in strict mode a type error of an evaluation (a
    ; comparison or a calculation with a text that is not a number, doc/EXPRESSION-LANGUAGE.md section 17) ends the
    ; element with "exception"; in compatibility mode the result is the empty text plus a warning (E0025), as v1 had it.
    ; A flow without the key is a migrated flow (a v1 file, or a file that v2 saved before the option existed; no flow
    ; is created by v2 before S0004): compatibility mode. A flow that v2 creates gets NEW_FLOW_STRICT_TYPES. Saving
    ; writes the key always (ToFileText), so the mode of a flow never changes by itself.
    static STRICT_KEY := "strictTypes"
    static NEW_FLOW_STRICT_TYPES := 1

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
        this.StrictTypes := FlowDefinition.ReadStrictTypes(raw.Has("flowSettings") ? raw["flowSettings"] : "")
        ; Elements (ID -> true) whose expression texts are still in v1 syntax because their class is not known
        ; (FlowExprConvert).
        this.Pending := Map()

        this._elements := FlowDefinition.NewIndex()
        this._kinds := FlowDefinition.NewIndex()
        this._classes := FlowDefinition.NewIndex()
        this._packages := FlowDefinition.NewIndex()
        this._connections := FlowDefinition.NewIndex()
        this._from := FlowDefinition.NewIndex()

        elements := FlowDefinition.RequireMap(flowId, raw, "allElements")
        connections := FlowDefinition.RequireMap(flowId, raw, "allConnections")

        for id, elem in elements {
            if (!(elem is Map))
                throw AhfError("flow '" flowId "': element '" id "' is not an object", ErrCode.BAD_PAYLOAD)
            if (!elem.Has("type") || !elem.Has("class"))
                throw AhfError("flow '" flowId "': element '" id "' has no type or class", ErrCode.BAD_PAYLOAD)
            this._elements[id] := elem
            this._kinds[id] := StrLower(FlowDefinition.TextOf(flowId, elem, "type", ""))
            this._classes[id] := FlowDefinition.TextOf(flowId, elem, "class", "")
            this._packages[id] := FlowDefinition.TextOf(flowId, elem, "package", "")
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

    ; The text of the flow file: Raw with the format version at the root, the marker "v1Text" at the elements in
    ; Pending and flowSettings.strictTypes (StrictTypes). Raw itself is not changed. Json.Stringify sorts the keys; the storage role writes the line breaks.
    ToFileText() {
        root := this.Raw.Clone()
        root[FlowDefinition.FORMAT_KEY] := FlowDefinition.FORMAT_VERSION
        settings := (root.Has("flowSettings") && root["flowSettings"] is Map) ? root["flowSettings"].Clone()
            : FlowDefinition.NewIndex()
        settings[FlowDefinition.STRICT_KEY] := Json.Bool(this.StrictTypes)
        root["flowSettings"] := settings
        if (this.Pending.Count) {
            elements := root["allElements"].Clone()
            for id in this.Pending {
                if (!elements.Has(id))
                    continue
                elem := elements[id].Clone()
                elem[FlowDefinition.MARKER_KEY] := Json.True
                elements[id] := elem
            }
            root["allElements"] := elements
        }
        return Json.Stringify(root, 2)
    }

    ; The definition for the wire (cmd.flow.get and the conflict answer): Raw, but flowSettings.strictTypes, if the flow
    ; has the key, as a JSON boolean (the parser reads true as 1, and the wire rule E0008 wants true/false; F-0076).
    ; Raw itself is not changed; a flow without the key stays without it (compatibility mode, no invented key).
    WireDefinition() {
        settings := this.Raw.Get("flowSettings", "")
        if (!(settings is Map) || !settings.Has(FlowDefinition.STRICT_KEY))
            return this.Raw
        root := this.Raw.Clone()
        settings := settings.Clone()
        settings[FlowDefinition.STRICT_KEY] := Json.Bool(this.StrictTypes)
        root["flowSettings"] := settings
        return root
    }

    ; 1 if flowSettings holds strictTypes true (also 1, "1" or "true", as a file edited by hand may have it), else 0.
    static ReadStrictTypes(settings) {
        if (!(settings is Map) || !settings.Has(FlowDefinition.STRICT_KEY))
            return 0
        v := settings[FlowDefinition.STRICT_KEY]
        return (v == Json.True || (!IsObject(v) && (v = 1 || v = "1" || v = "true"))) ? 1 : 0
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

    ; Package name as written in the file (e.g. "default"); "" if the element has none or the ID is unknown. With the
    ; class it is the identity of the element (E0045): ElementRegistry.QualifiedId(package, class), where "" means Default.
    ElementPackage(elementId) {
        return this._packages.Get(elementId, "")
    }

    ; The element Map as parsed (keys ID, class, type, pars, ...). "" if unknown ID.
    Element(elementId) {
        return this._elements.Get(elementId, "")
    }

    ; The connection Map as parsed. "" if unknown ID.
    Connection(connectionId) {
        return this._connections.Get(connectionId, "")
    }

    ; The IDs of the elements whose class is qualifiedId ("<package>.<class>", any case; a missing package is Default,
    ; E0045), in the order of the Map (sorted by ID). v1 x_getAllElementIDsOfClass (WI-0052).
    ElementIdsOfClass(qualifiedId) {
        pos := InStr(qualifiedId, ".")
        want := pos ? qualifiedId : "Default." qualifiedId
        idList := []
        for id in this._elements {
            if (this._QualifiedIdOf(id) = want)
                idList.Push(id)
        }
        return idList
    }

    ; The stored parameters of an element as an object with case-insensitive properties, a copy (v1 x_getElementPars,
    ; WI-0052). Unlike the parameters that an element receives in Run, the values keep their type: a list stays an
    ; Array, an object a Map (a JSON null is the empty text). "" if there is no such element.
    ElementPars(elementId) {
        elem := this._elements.Get(elementId, "")
        if (!(elem is Map))
            return ""
        out := {}
        pars := elem.Get("pars", "")
        if (pars is Map) {
            for k, v in pars
                out.%k% := FlowDefinition.CopyValue(v)
        }
        return out
    }

    ; A deep copy of a parsed JSON value: Maps keep their case-insensitivity, Arrays stay Arrays, null is "".
    static CopyValue(value) {
        if (value is Map) {
            m := Map()
            m.CaseSense := value.CaseSense
            for k, v in value
                m[k] := FlowDefinition.CopyValue(v)
            return m
        }
        if (value is Array) {
            a := []
            for v in value
                a.Push(IsSet(v) ? FlowDefinition.CopyValue(v) : "")
            return a
        }
        return (value == Json.Null) ? "" : value
    }

    _QualifiedIdOf(elementId) {
        package := this._packages.Get(elementId, "")
        return (package = "" ? "Default" : package) "." this._classes.Get(elementId, "")
    }

    ; IDs of valid connections that start at the element, in the enumeration order of the Map
    ; (sorted by ID). Dangling connections are not included. Empty array for unknown IDs.
    FromConnections(elementId) {
        idList := []
        for id in this._from.Get(elementId, []) {
            idList.Push(id)
        }
        return idList
    }

    ; IDs of all elements of kind "trigger", in Map enumeration order (sorted by ID).
    Triggers() {
        idList := []
        for id, kind in this._kinds {
            if (kind = "trigger")
                idList.Push(id)
        }
        return idList
    }

    ; The ID of the default manual trigger (v1 xx_getDefaultManualTriggerID, WI-0055): the first element (sorted by ID) of
    ; the class Default.Trigger_Manual whose key "DefaultTrigger" is true (1, "1" or true, any case of the class). "" if
    ; the flow has none.
    DefaultManualTrigger() {
        for id in this.ElementIdsOfClass("Default.Trigger_Manual") {
            if (this.ElementKind(id) != "trigger")
                continue
            v := this._elements[id].Get("DefaultTrigger", "")
            if (v == Json.True || (!IsObject(v) && (v = 1 || v = "true")))
                return id
        }
        return ""
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
