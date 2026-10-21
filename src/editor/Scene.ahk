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
;
; Interaction (WI-0097, the editing state the renderer draws over the flow; a Map, every key optional):
;   selected    Map: element or connection ID -> true (the selection)
;   rect        FlowRect of the selection rectangle being drawn (flow units), or ""
;   connecting  Map("fromId", element ID, "fromPart", part, "type", connection type, "x", x, "y", y) for a connection
;               being drawn from a part of an element to the point (x, y), or Map("toId", element ID, "toPart", part,
;               "x", x, "y", y) for one whose start is the point and whose end is the element (WI-0100), or ""
;   dragged     Map: ID -> true of the elements being dragged; dx, dy the offset of the drag (see WithDrag)
;   ghost       FlowRect of the box of a new element that is being placed (WI-0099), or ""
; Properties from it: Selected, Rect, Connecting (Map("start", [x, y], "aim", [x, y]) or ""), Dragged, DragX, DragY,
; Ghost, and Buttons: the buttons of the single selected element or connection (Array of Maps("name", "id", "rect" FlowRect);
; none while a drag runs). FlowHitTest asks Buttons first.
class Scene {
    __New(view, version, hovered, elements, connections, warnings, interaction := "") {
        this.View := view
        this.Version := version
        this.Hovered := hovered
        this.Elements := elements
        this.Connections := connections
        this.Warnings := warnings
        if (!(interaction is Map))
            interaction := Map()
        this.Selected := interaction.Get("selected", Map())
        this.Rect := interaction.Get("rect", "")
        this.ConnectingRequest := interaction.Get("connecting", "")
        this.Dragged := interaction.Get("dragged", Map())
        this.DragX := interaction.Get("dx", 0)
        this.DragY := interaction.Get("dy", 0)
        this.Ghost := interaction.Get("ghost", "")
        this.Connecting := Scene.ConnectingOf(elements, this.ConnectingRequest)
        this.Buttons := (this.Dragged.Count = 0) ? Scene.ButtonsOf(elements, connections, this.Selected) : []
        rects := []
        for element in elements
            rects.Push(element.Bounds)
        for connection in connections
            for segment in connection.Segments
                rects.Push(segment)
        this.Bounds := FlowRect.Union(rects)
    }

    ; The interaction of this scene as the constructor takes it (the state that WithStates keeps).
    Interaction() {
        return Map("selected", this.Selected, "rect", this.Rect, "connecting", this.ConnectingRequest
            , "dragged", this.Dragged, "dx", this.DragX, "dy", this.DragY, "ghost", this.Ghost)
    }

    ; The same flow and states with another selection, selection rectangle and connection being drawn (the drag of the
    ; scene stays as it is). The elements and connections are shared, nothing is built again.
    WithInteraction(selected, rect := "", connecting := "", ghost := "") {
        interaction := this.Interaction()
        interaction["selected"] := (selected is Map) ? selected : Map()
        interaction["rect"] := rect
        interaction["connecting"] := connecting
        interaction["ghost"] := ghost
        return Scene(this.View, this.Version, this.Hovered, this.Elements, this.Connections, this.Warnings, interaction)
    }

    ; The scene with the elements in dragged (Map: ID -> true) moved by (dx, dy) flow units, and the loops in heights
    ; (Map: ID -> height of the bar) given their new height, and their connections routed again from the new ends
    ; (WI-0097, WI-0098). The base is the scene without a drag: its moved elements are computed from their positions in
    ; this scene. Only the changed objects are new; the others are shared with this scene. version: the version of the
    ; new scene ("" keeps the version of this one; the editor gives every drag a new one, so a frame is drawn).
    WithDrag(dragged, dx, dy, version := "", heights := "") {
        if (!(heights is Map))
            heights := Map()
        elements := []
        byId := Map()
        for element in this.Elements {
            moved := dragged.Has(element.Id) ? element.Moved(dx, dy) : element
            if (heights.Has(element.Id))
                moved := moved.Resized(heights[element.Id])
            elements.Push(moved)
            byId[moved.Id] := moved
        }
        connections := []
        for connection in this.Connections {
            from := byId.Get(connection.From, "")
            to := byId.Get(connection.To, "")
            affected := dragged.Has(connection.From) || dragged.Has(connection.To) || heights.Has(connection.From)
                || heights.Has(connection.To)
            if (!affected || !(from is SceneElement) || !(to is SceneElement)) {
                connections.Push(connection)
                continue
            }
            start := FlowGeometry.StartOf(from.Kind, from.X, from.Y, from.HeightOfVerticalBar, connection.Type
                , connection.FromPart)
            aim := FlowGeometry.AimOf(to.Kind, to.X, to.Y, to.HeightOfVerticalBar, connection.ToPart)
            connections.Push(connection.Moved(start[1], start[2], aim[1], aim[2]))
        }
        interaction := this.Interaction()
        interaction["dragged"] := dragged
        interaction["dx"] := dx
        interaction["dy"] := dy
        return Scene(this.View, (version = "") ? this.Version : version, this.Hovered, elements, connections
            , this.Warnings, interaction)
    }

    ; The start and the aim of a connection being drawn, or "" when its source element is not in the scene.
    static ConnectingOf(elements, request) {
        if (!(request is Map))
            return ""
        if (request.Has("toId")) {             ; the start follows the pointer, the aim is the end element (WI-0100)
            target := ""
            for element in elements {
                if (element.Id = request["toId"]) {
                    target := element
                    break
                }
            }
            if (!(target is SceneElement))
                return ""
            aim := FlowGeometry.AimOf(target.Kind, target.X, target.Y, target.HeightOfVerticalBar, request.Get("toPart", ""))
            return Map("start", [request.Get("x", 0), request.Get("y", 0)], "aim", aim)
        }
        source := ""
        for element in elements {
            if (element.Id = request.Get("fromId", "")) {
                source := element
                break
            }
        }
        if (!(source is SceneElement))
            return ""
        start := FlowGeometry.StartOf(source.Kind, source.X, source.Y, source.HeightOfVerticalBar
            , request.Get("type", "normal"), request.Get("fromPart", ""))
        return Map("start", start, "aim", [request.Get("x", 0), request.Get("y", 0)])
    }

    ; The buttons of the single selected element or connection, as the boxes of their centres (B x B flow units).
    static ButtonsOf(elements, connections, selected) {
        if (selected.Count != 1)
            return []
        id := ""
        for key, value in selected
            id := key
        for element in elements {
            if (element.Id = id)
                return Scene.BoxesOf(FlowGeometry.ElementButtons(element.Kind, element.X, element.Y
                    , element.HeightOfVerticalBar), id)
        }
        for connection in connections {
            if (connection.Id = id)
                return Scene.BoxesOf(FlowGeometry.ConnectionButtons(connection.Segments), id)
        }
        return []
    }

    static BoxesOf(centres, id) {
        size := FlowGeometry.BUTTON_SIZE
        out := []
        for centre in centres
            out.Push(Map("name", centre["name"], "id", id, "rect"
                , FlowRect(centre["x"] - size / 2, centre["y"] - size / 2, size, size)))
        return out
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
                t := SceneBuilder.TriggerStateOf(trigger.Get(element.Id, ""), element.Trigger["default"], element.Trigger["manual"])
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
        return Scene(view, version, this.Hovered, elements, connections, issues, this.Interaction())
    }
}
