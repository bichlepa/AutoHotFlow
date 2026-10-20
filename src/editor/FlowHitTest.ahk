#Requires AutoHotkey v2.0
#Include FlowGeometry.ahk
#Include FlowHit.ahk

; Hit test of a flow point (WI-0084, used by the tooltip (WI-0090) and by the selection (S0006)). The point is in flow
; coordinates, the scene holds the parts and segments in flow coordinates too.
;
; Order (decision, WI-0084, WI-0097): the buttons of the selection come first, then the elements, then the connections,
; and within each group the item that is drawn last wins (the scene lists them in ID order; the last one is on top).
; A connection is hit within FlowGeometry.CONNECTION_MARGIN of one of its segments, as v1 does; an element only inside
; its box. The fields for new elements are not in the flow: NewElementFields.At is asked before this (canvas pixels).
class FlowHitTest {
    ; Returns the FlowHit under (fx, fy), or "" if nothing is there.
    static At(scene, fx, fy) {
        for button in scene.Buttons {
            if (button["rect"].Contains(fx, fy))
                return FlowHit("button", button["id"], button["name"])
        }
        elements := scene.Elements
        loop elements.Length {
            element := elements[elements.Length + 1 - A_Index]
            parts := element.Parts
            loop parts.Length {
                if (parts[A_Index].Contains(fx, fy))
                    return FlowHit("element", element.Id, A_Index)
            }
        }
        connections := scene.Connections
        loop connections.Length {
            connection := connections[connections.Length + 1 - A_Index]
            segments := connection.Segments
            loop segments.Length {
                if (segments[A_Index].Contains(fx, fy, FlowGeometry.CONNECTION_MARGIN))
                    return FlowHit("connection", connection.Id, A_Index)
            }
        }
        return ""
    }
}
