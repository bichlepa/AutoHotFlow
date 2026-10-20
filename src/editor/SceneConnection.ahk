#Requires AutoHotkey v2.0
#Include FlowGeometry.ahk

; A connection of a Scene (WI-0084): the anchor points in flow coordinates, its five segments (FlowRects, see
; FlowGeometry.Segments) and its label (Map("rect", FlowRect, "align", text) or ""). Run is "" (idle), "running" or
; "recent" as for an element. Nothing refers into the flow model.
class SceneConnection {
    __New(id, from, to, connectionType, fromPart, toPart, startX, startY, aimX, aimY, run) {
        this.Id := id
        this.From := from
        this.To := to
        this.Type := connectionType
        this.FromPart := fromPart
        this.ToPart := toPart
        this.StartX := startX
        this.StartY := startY
        this.AimX := aimX
        this.AimY := aimY
        this.Segments := FlowGeometry.Segments(startX, startY, aimX, aimY)
        this.Label := FlowGeometry.LabelOf(connectionType, aimX, aimY)
        this.Run := run
    }

    ; A copy of this connection with new anchor points (the ends of a dragged element moved, Scene.WithDrag); the
    ; segments and the label are computed again from them.
    Moved(startX, startY, aimX, aimY) {
        return SceneConnection(this.Id, this.From, this.To, this.Type, this.FromPart, this.ToPart, startX, startY
            , aimX, aimY, this.Run)
    }
}
