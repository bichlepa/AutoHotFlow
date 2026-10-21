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
        mark := FlowHitTest._MarkAt(scene, fx, fy)
        if (IsObject(mark))
            return mark
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

    ; The switch or the star of a trigger under (fx, fy) (FlowHit "mark"), or "". The star is a mark of a manual trigger only.
    ; The marks lie on top of their element, so they are asked before the elements.
    static _MarkAt(scene, fx, fy) {
        elements := scene.Elements
        loop elements.Length {
            element := elements[elements.Length + 1 - A_Index]
            if (element.Kind != "trigger" || !(element.Trigger is Map))
                continue
            marks := FlowGeometry.TriggerMarks(element.X, element.Y)
            size := FlowGeometry.MARK_SIZE
            for name in ["switch", "star"] {
                if (name = "star" && !element.Trigger["manual"])
                    continue
                centre := marks[name]
                if (FlowRect(centre[1] - size / 2, centre[2] - size / 2, size, size).Contains(fx, fy))
                    return FlowHit("mark", element.Id, name)
            }
        }
        return ""
    }

    ; The element under (fx, fy) with the part under it (FlowHit "element", Index the part), or "" when no element is there.
    ; Buttons and connections are not asked: the end of a connection that is dropped lands on the element beneath them
    ; (WI-0100, a drop on empty space creates an element).
    static ElementAt(scene, fx, fy) {
        elements := scene.Elements
        loop elements.Length {
            element := elements[elements.Length + 1 - A_Index]
            parts := element.Parts
            loop parts.Length {
                if (parts[A_Index].Contains(fx, fy))
                    return FlowHit("element", element.Id, A_Index)
            }
        }
        return ""
    }
}
