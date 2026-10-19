#Requires AutoHotkey v2.0
#Include ..\elements\base\ElementRegistry.ahk
#Include FlowGeometry.ahk
#Include EditorView.ahk
#Include Scene.ahk
#Include SceneElement.ahk
#Include SceneConnection.ahk

; Builds the Scene of a flow (WI-0084, ARCHITECTURE 2.1). The input is the flow as parsed from its file (Json.Parse: a
; Map with allElements and allConnections, the types kept). The builder reads it and copies what the window needs; the
; flow model is not changed and not referred to.
;
; The element class is looked up in the element registry of the editor process, which has all classes (E0041). An
; element whose class is unknown, or whose package is not installed, gets no icon and a placeholder with the reason
; (ElementRegistry.MissingText, REQ-MIG-070). A connection without a source or target element is left out and listed
; as a warning. The elements are in ID order (the order of the Map), so the last one is drawn on top.
;
; Inputs besides the flow (all optional):
;   view     EditorView (default: the default view)
;   run      Map: element or connection ID -> "running" or "recent" (a connection shows its last run as an element does)
;   trigger  Map: trigger element ID -> Map("enabled", 1 or 0, "armed", 1 or 0, "message", text) (the engine's state)
;   warnings Map: element or connection ID -> text (for example a warning of the evaluation)
;   hovered  FlowHit or "" (the item under the mouse)
;   version  number, see Scene
class SceneBuilder {
    static Build(raw, view := "", run := "", trigger := "", warnings := "", hovered := "", version := 0) {
        if (!(raw is Map))
            raw := Map()
        if (!(view is EditorView))
            view := EditorView()
        if (!(run is Map))
            run := Map()
        if (!(trigger is Map))
            trigger := Map()
        if (!(warnings is Map))
            warnings := Map()
        allElements := raw.Get("allElements", "")
        if (!(allElements is Map))
            allElements := Map()
        allConnections := raw.Get("allConnections", "")
        if (!(allConnections is Map))
            allConnections := Map()

        issues := []
        elements := []
        for id, elem in allElements {
            if (!(elem is Map)) {
                issues.Push(Map("id", id, "text", "the element is not an object"))
                continue
            }
            element := SceneBuilder.MakeElement(id, elem, run, trigger, warnings)
            elements.Push(element)
            if (element.Warning != "")
                issues.Push(Map("id", id, "text", element.Warning))
        }

        connections := []
        for id, conn in allConnections {
            if (!(conn is Map)) {
                issues.Push(Map("id", id, "text", "the connection is not an object"))
                continue
            }
            from := allElements.Get(SceneBuilder.TextOf(conn, "from"), "")
            to := allElements.Get(SceneBuilder.TextOf(conn, "to"), "")
            if (!(from is Map) || !(to is Map)) {
                issues.Push(Map("id", id, "text", "the connection has no source or target element"))
                continue
            }
            connections.Push(SceneBuilder.MakeConnection(id, conn, from, to, run))
            if (warnings.Has(id))
                issues.Push(Map("id", id, "text", warnings[id]))
        }
        return Scene(view, version, hovered, elements, connections, issues)
    }

    static MakeElement(id, elem, run, trigger, warnings) {
        kind := StrLower(SceneBuilder.TextOf(elem, "type"))
        className := SceneBuilder.TextOf(elem, "class")
        package := SceneBuilder.TextOf(elem, "package")
        cls := ElementRegistry.Lookup(package, className)
        placeholder := ""
        icon := ""
        displayName := className
        if (!IsObject(cls)) {
            placeholder := ElementRegistry.MissingText(ElementRegistry.QualifiedId(package, className))
        } else {
            ; An element class calls Lang() in Name(); a failing class must not stop the drawing (CONVENTIONS 4).
            try displayName := cls.Name()
            try icon := cls.Icon
        }
        trig := (kind = "trigger") ? SceneBuilder.TriggerStateOf(trigger.Get(id, "")) : ""
        ; The text on the element is the name the user gave it (v1 draws `name`); the class name is the fallback.
        label := SceneBuilder.TextOf(elem, "name")
        return SceneElement(id, kind, displayName, icon,
            SceneBuilder.NumberOf(elem.Get("x", 0)), SceneBuilder.NumberOf(elem.Get("y", 0)),
            SceneBuilder.NumberOf(elem.Get("HeightOfVerticalBar", 0)),
            run.Get(id, ""), trig, SceneBuilder.CopyMigration(elem.Get("migration", "")), placeholder,
            warnings.Get(id, ""), (package = "") ? "Default" : package, (label = "") ? displayName : label)
    }

    static MakeConnection(id, conn, from, to, run) {
        connectionType := SceneBuilder.TextOf(conn, "ConnectionType")
        fromPart := SceneBuilder.TextOf(conn, "fromPart")
        toPart := SceneBuilder.TextOf(conn, "toPart")
        fromKind := StrLower(SceneBuilder.TextOf(from, "type"))
        toKind := StrLower(SceneBuilder.TextOf(to, "type"))
        start := FlowGeometry.StartOf(fromKind, SceneBuilder.NumberOf(from.Get("x", 0)),
            SceneBuilder.NumberOf(from.Get("y", 0)), SceneBuilder.NumberOf(from.Get("HeightOfVerticalBar", 0)),
            connectionType, fromPart)
        aim := FlowGeometry.AimOf(toKind, SceneBuilder.NumberOf(to.Get("x", 0)),
            SceneBuilder.NumberOf(to.Get("y", 0)), SceneBuilder.NumberOf(to.Get("HeightOfVerticalBar", 0)), toPart)
        return SceneConnection(id, SceneBuilder.TextOf(conn, "from"), SceneBuilder.TextOf(conn, "to"),
            connectionType, fromPart, toPart, start[1], start[2], aim[1], aim[2], run.Get(id, ""))
    }

    ; The trigger state of a scene element from the engine's state (a Map or "" for none): enabled and armed are 1 or 0
    ; (internal values, no truth values of the protocol), the message is a text.
    static TriggerStateOf(state) {
        out := Map()
        out["enabled"] := (state is Map && state.Get("enabled", 0)) ? 1 : 0
        out["armed"] := (state is Map && state.Get("armed", 0)) ? 1 : 0
        out["message"] := (state is Map) ? SceneBuilder.TextOf(state, "message") : ""
        out["default"] := (state is Map && state.Get("default", 0)) ? 1 : 0    ; the default manual trigger (star)
        return out
    }

    ; The text of a key of a parsed object; "" for a missing key or an object value.
    static TextOf(m, key) {
        v := m.Get(key, "")
        return IsObject(v) ? "" : String(v)
    }

    ; A position or size of a flow: a number, also when the file has it as text ("x": "175"); 0 otherwise.
    static NumberOf(v) => IsNumber(v) ? v + 0 : 0

    ; A copy of the migration list of an element (the Maps and the ID lists are new), so the scene keeps no reference.
    static CopyMigration(value) {
        out := []
        if (!(value is Array))
            return out
        for entry in value {
            if (!(entry is Map))
                continue
            copy := Map()
            for key, v in entry {
                if (v is Array) {
                    list := []
                    for item in v
                        list.Push(item)
                    copy[key] := list
                } else {
                    copy[key] := v
                }
            }
            out.Push(copy)
        }
        return out
    }
}
