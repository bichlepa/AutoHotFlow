#Requires AutoHotkey v2.0
#Include FlowRect.ahk

; The snapshot of a flow that the renderer draws (WI-0084, ARCHITECTURE 2.1): elements, connections, view, hovered item
; and warnings. Built by SceneBuilder; it holds copies only, never a reference into the flow model. Its properties are
; set once in the constructor and not changed afterwards (no code in the editor writes to them).
;
; Version: a number that the builder takes from the caller; a window compares it with the version it drew last to decide
; whether a new frame is needed.
; Warnings: a list of Maps("id", element or connection ID, "text", message, "kind"), kind "evaluation" for the warnings of the
; evaluation (also the count of an element is in its WarningCount).
; Bounds: the box of everything in flow coordinates (empty at 0,0 for an empty flow).
class Scene {
    __New(view, version, hovered, elements, connections, warnings) {
        this.View := view
        this.Version := version
        this.Hovered := hovered
        this.Elements := elements
        this.Connections := connections
        this.Warnings := warnings
        rects := []
        for element in elements
            rects.Push(element.Bounds)
        for connection in connections
            for segment in connection.Segments
                rects.Push(segment)
        this.Bounds := FlowRect.Union(rects)
    }

    ; A scene with other run, trigger and warning states (WI-0088, F-0150, WI-0089): the same flow, the same view or
    ; another one, and the states given as SceneBuilder.Build takes them (run: ID -> "running", "exception", a fade or
    ; ""; trigger: ID -> the engine's trigger state; warnings: element ID -> Map("count", n, "text", text), or "" to keep
    ; the warnings of this scene). An element or connection whose state did not change is the same object as before (the
    ; scene is immutable, so sharing is safe); only the changed ones are made new. Building the flow again costs about
    ; 18 ms for 300 elements (MS-0046), a state change must not pay for it. The flow must be the one this scene was built
    ; from. The list of Warnings is made again when the warnings are given: the evaluation warnings of the elements follow them.
    WithStates(view, run, trigger, version, warnings := "") {
        hasWarnings := (warnings is Map)
        elements := []
        for element in this.Elements {
            r := run.Get(element.Id, "")
            t := ""
            if (element.Kind = "trigger")
                t := SceneBuilder.TriggerStateOf(trigger.Get(element.Id, ""), element.Trigger["default"])
            w := hasWarnings ? SceneBuilder.WarningOf(warnings.Get(element.Id, "")) : Map("count", element.WarningCount
                , "text", element.Warning)
            if (r = element.Run && SceneBuilder.SameTrigger(t, element.Trigger) && w["count"] = element.WarningCount
                    && w["text"] = element.Warning) {
                elements.Push(element)
                continue
            }
            elements.Push(SceneElement(element.Id, element.Kind, element.ClassName, element.Icon, element.X, element.Y,
                element.HeightOfVerticalBar, r, t, element.Migration, element.Placeholder, w["text"],
                element.Package, element.Name, w["count"]))
        }
        connections := []
        for connection in this.Connections {
            r := run.Get(connection.Id, "")
            if (r = connection.Run) {
                connections.Push(connection)
                continue
            }
            connections.Push(SceneConnection(connection.Id, connection.From, connection.To, connection.Type,
                connection.FromPart, connection.ToPart, connection.StartX, connection.StartY, connection.AimX,
                connection.AimY, r))
        }
        issues := this.Warnings
        if (hasWarnings) {
            issues := []
            elementIds := Map()
            for element in elements
                elementIds[element.Id] := true
            for issue in this.Warnings {
                ; the evaluation warnings of elements are made again below; the others stay
                if (issue.Get("kind", "") != "evaluation" || !elementIds.Has(issue["id"]))
                    issues.Push(issue)
            }
            for element in elements {
                if (element.Warning != "")
                    issues.Push(Map("id", element.Id, "text", element.Warning, "kind", "evaluation"))
            }
        }
        return Scene(view, version, this.Hovered, elements, connections, issues)
    }
}
