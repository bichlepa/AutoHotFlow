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
}
