#Requires AutoHotkey v2.0
#Include FlowRect.ahk

; The snapshot of a flow that the renderer draws (WI-0084, ARCHITECTURE 2.1): elements, connections, view, hovered item
; and warnings. Built by SceneBuilder; it holds copies only, never a reference into the flow model. Its properties are
; set once in the constructor and not changed afterwards (no code in the editor writes to them).
;
; Version: a number that the builder takes from the caller; a window compares it with the version it drew last to decide
; whether a new frame is needed.
; Warnings: a list of Maps("id", element or connection ID, "text", message).
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

    ; A scene with other run and trigger states (WI-0088, F-0150): the same flow, the same view or another one, and the
    ; states given as SceneBuilder.Build takes them (run: ID -> "running", "recent" or ""; trigger: ID -> the engine's
    ; trigger state). An element or connection whose state did not change is the same object as before (the scene is
    ; immutable, so sharing is safe); only the changed ones are made new. Building the flow again costs about 18 ms for
    ; 300 elements (MS-0046), a state change must not pay for it. The flow must be the one this scene was built from.
    WithStates(view, run, trigger, version) {
        elements := []
        for element in this.Elements {
            r := run.Get(element.Id, "")
            t := ""
            if (element.Kind = "trigger")
                t := SceneBuilder.TriggerStateOf(trigger.Get(element.Id, ""), element.Trigger["default"])
            if (r = element.Run && SceneBuilder.SameTrigger(t, element.Trigger)) {
                elements.Push(element)
                continue
            }
            elements.Push(SceneElement(element.Id, element.Kind, element.ClassName, element.Icon, element.X, element.Y,
                element.HeightOfVerticalBar, r, t, element.Migration, element.Placeholder, element.Warning,
                element.Package, element.Name))
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
        return Scene(view, version, this.Hovered, elements, connections, this.Warnings)
    }
}
