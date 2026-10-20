#Requires AutoHotkey v2.0
#Include FlowRect.ahk

; The four fields "Create new action, condition, loop, trigger" at the top left of the editor canvas (WI-0097, v1
; GDIp.ahk lines 1036 to 1055). They are fixed to the canvas: they do not move with the flow and do not change with the
; zoom, only with the DPI (decision of WI-0097: v1 scaled them with the zoom). Positions are in device pixels; the sizes
; are v1's at 96 DPI and scaled by dpi / 96.
;
; Hit order (decision, WI-0097): the fields come before the flow (buttons, elements, connections); the window asks At
; with canvas coordinates first.
class NewElementFields {
    static FIELD_WIDTH := 100        ; v1 default_NewElementIconWidth
    static FIELD_HEIGHT := 75        ; v1 default_NewElementIconHeight
    static KINDS := ["action", "condition", "loop", "trigger"]

    ; The white area behind the fields: 4 fields wide and 1.2 fields high (v1 line 1038).
    static AreaOf(dpi) => NewElementFields.Scaled(FlowRect(0, 0, NewElementFields.FIELD_WIDTH * 4.8
        , NewElementFields.FIELD_HEIGHT * 1.2), dpi)

    ; The fields as an Array of Maps("kind", kind, "rect", FlowRect in device pixels), in the order of KINDS.
    static Rects(dpi) {
        W := NewElementFields.FIELD_WIDTH, H := NewElementFields.FIELD_HEIGHT
        lefts := [W * 0.1, W * 1.3, W * 2.5, W * 3.7]
        out := []
        for kind in NewElementFields.KINDS {
            i := A_Index
            out.Push(Map("kind", kind, "rect", NewElementFields.Scaled(FlowRect(lefts[i], H * 0.1, W, H), dpi)))
        }
        return out
    }

    ; The kind of the field under the point (px, py) in device pixels, or "" when no field is there.
    static At(dpi, px, py) {
        for field in NewElementFields.Rects(dpi) {
            if (field["rect"].Contains(px, py))
                return field["kind"]
        }
        return ""
    }

    static Scaled(rect, dpi) {
        k := dpi / 96
        return FlowRect(rect.X * k, rect.Y * k, rect.W * k, rect.H * k)
    }
}
