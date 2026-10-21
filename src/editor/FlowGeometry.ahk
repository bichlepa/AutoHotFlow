#Requires AutoHotkey v2.0
#Include FlowRect.ahk

; Geometry of the flow drawing (WI-0084, REQ-EDT-020): the sizes of v1 and the parts, anchor points, segments and labels
; of the connections, exactly as v1 computes them in v1/Source_Draw/GDIp/GDIp.ahk (gdip_DrawEverything). Pure
; computation in flow coordinates: nothing here knows the window, the zoom or the DPI (EditorView does that).
;
; The v1 line numbers in the comments refer to v1/Source_Draw/GDIp/GDIp.ahk. Comparisons of texts with "=" are
; case-insensitive in AutoHotkey, as in v1 (ConnectionType "Normal" and "normal" are the same).
class FlowGeometry {
    ; v1 Design.ahk: default_ElementWidth, default_ElementHeight, default_Gridx, default_MinimumHeightOfConnection
    static ELEMENT_WIDTH := 140
    static ELEMENT_HEIGHT := 105
    static GRID := 35
    static MIN_CONNECTION_HEIGHT := 15
    ; v1 GDIp.ahk: the hit area of a connection segment is grown by 20 flow units on every side (lines 546 to 549)
    static CONNECTION_MARGIN := 20
    ; v1 GDIp.ahk line 597: height of the label of a connection type (texth)
    static LABEL_HEIGHT := 17
    ; v1 Design.ahk default_SizeOfButtons: the size of a button of the selection (flow units, the box of its centre)
    static BUTTON_SIZE := 35
    ; The marks of a trigger (WI-0102, v1 positions, the same numbers as EditorStyle.DrawMarks): the switch at 80 % of the
    ; width and 25 % of the height, the star of a manual trigger at 15 % and 20 %; the box of a mark is MARK_SIZE wide.
    static MARK_SIZE := 35
    ; v1 Element_SetType: the height of the bar of a new loop (WI-0099)
    static NEW_LOOP_BAR := 150

    ; A position or a height snapped to the grid (v1 ui_FitGridX: the nearest multiple of GRID). WI-0098.
    static Snap(v) => Round(v / FlowGeometry.GRID) * FlowGeometry.GRID

    ; The top left corner (flow units, on the grid) of a new element whose centre is at the flow point (fx, fy): v1 put the
    ; new element under the mouse (Editor GUI User Input, the menu of the new elements). WI-0099.
    static CentredOrigin(fx, fy) => [FlowGeometry.Snap(fx - FlowGeometry.ELEMENT_WIDTH / 2)
        , FlowGeometry.Snap(fy - FlowGeometry.ELEMENT_HEIGHT / 2)]

    ; The parts of an element as FlowRects, in the numbering of v1 (part 1 first). A trigger, an action and a condition
    ; have one part, the whole box. A loop has four (GDIp.ahk lines 800 to 816): the head, the bar on its left side
    ; (width 1/8, height HeightOfVerticalBar), the foot (height 1/3, up to 3/4 of the width) and the break field
    ; (the right quarter of the foot). The foot starts below the bar.
    static Parts(kind, x, y, heightOfVerticalBar) {
        W := FlowGeometry.ELEMENT_WIDTH, H := FlowGeometry.ELEMENT_HEIGHT, B := heightOfVerticalBar
        if (kind != "loop")
            return [FlowRect(x, y, W, H)]
        return [
            FlowRect(x, y, W, H),
            FlowRect(x, y + H, W / 8, B),
            FlowRect(x, y + H + B, W * 3 / 4, H / 3),
            FlowRect(x + W * 3 / 4, y + H + B, W / 4, H / 3)
        ]
    }

    ; The box of the whole element: the head, and for a loop the bar and the foot below it (GDIp.ahk 755 to 765).
    static Bounds(kind, x, y, heightOfVerticalBar) {
        W := FlowGeometry.ELEMENT_WIDTH, H := FlowGeometry.ELEMENT_HEIGHT
        if (kind != "loop")
            return FlowRect(x, y, W, H)
        return FlowRect(x, y, W, H + heightOfVerticalBar + H / 3)
    }

    ; Where a connection leaves its source element (GDIp.ahk lines 280 to 312). A loop leaves at the bottom of the
    ; head for a normal connection from HEAD, otherwise at the foot (that is also the way of an exception). Any other
    ; element leaves at the bottom centre.
    static StartOf(kind, x, y, heightOfVerticalBar, connectionType, fromPart) {
        W := FlowGeometry.ELEMENT_WIDTH, H := FlowGeometry.ELEMENT_HEIGHT
        if (kind != "loop")
            return [x + W / 2, y + H]
        if (connectionType = "normal" && fromPart = "HEAD")
            return [x + W / 2, y + H]
        return [x + W / 2, y + heightOfVerticalBar + H * 4 / 3]
    }

    ; Where a connection arrives at its target element (GDIp.ahk lines 332 to 350): the top centre, a loop at its head,
    ; its break field (BREAK) or its foot (any other part).
    static AimOf(kind, x, y, heightOfVerticalBar, toPart) {
        W := FlowGeometry.ELEMENT_WIDTH, H := FlowGeometry.ELEMENT_HEIGHT
        if (kind != "loop")
            return [x + W / 2, y]
        if (toPart = "HEAD")
            return [x + W / 2, y]
        if (toPart = "BREAK")
            return [x + W * 7 / 8, y + heightOfVerticalBar + H]
        return [x + W / 2, y + heightOfVerticalBar + H]
    }

    ; The five segments of a connection from (sx, sy) to (ax, ay), as v1 computes lin1 to lin5 (GDIp.ahk lines 366 to
    ; 470). The result is an Array of five FlowRects; a segment with W 0 is vertical, with H 0 horizontal. The route
    ; goes down from the source, sideways, down again (going around the elements when the target is above), sideways
    ; and down into the target.
    static Segments(sx, sy, ax, ay) {
        W := FlowGeometry.ELEMENT_WIDTH, minH := FlowGeometry.MIN_CONNECTION_HEIGHT
        ; segment 1: down from the source (lines 368 to 378)
        lin1x := sx, lin1y := sy
        lin1h := (ay - sy < 20) ? minH : (ay - sy) / 2
        ; segment 2: sideways (lines 380 to 413)
        lin2y := lin1y + lin1h
        if (ax > sx) {
            lin2x := sx
            lin2w := (ax - sx) / 2
            if (lin2w < W / 2 + 5 && sy > ay)
                lin2w := W / 2 + 5
            if (ax - W / 2 - 5 < lin2x + lin2w && sy > ay)
                lin2w := ax + W / 2 + 5 - lin2x
        } else {
            lin2w := (sx - ax) / 2
            if (lin2w < W / 2 + 5 && sy > ay)
                lin2w := W / 2 + 5
            lin2x := lin1x - lin2w
            if (ax + W / 2 + 5 > lin2x && sy > ay) {
                lin2x := ax - W / 2 - 5
                lin2w := lin1x - lin2x
            }
        }
        ; segment 3: down, past the target when the target is above (lines 415 to 441)
        lin3x := (ax > sx) ? lin2x + lin2w : lin2x
        if (sy > ay - 20) {
            lin3y := ay - minH
            lin3h := lin2y - lin3y
        } else {
            lin3h := 0
            lin3y := lin2y
        }
        ; segment 4: sideways to the target (lines 443 to 457)
        lin4y := lin3y
        if (ax > lin3x) {
            lin4x := lin3x
            lin4w := ax - lin4x
        } else {
            lin4x := ax
            lin4w := lin3x - lin4x
        }
        ; segment 5: down into the target (lines 459 to 472)
        lin5x := ax
        if (ay - sy < 20) {
            lin5h := minH
            lin5y := ay - lin5h
        } else {
            lin5h := (ay - sy) / 2
            lin5y := ay - lin5h
        }
        return [
            FlowRect(lin1x, lin1y, 0, lin1h),
            FlowRect(lin2x, lin2y, lin2w, 0),
            FlowRect(lin3x, lin3y, 0, lin3h),
            FlowRect(lin4x, lin4y, lin4w, 0),
            FlowRect(lin5x, lin5y, 0, lin5h)
        ]
    }

    ; The label of a connection type other than normal and exception (GDIp.ahk lines 474 to 508): "yes" is written to
    ; the left of the target, right-aligned; any other type to its right, left-aligned. Returns Map("rect", FlowRect,
    ; "align", "left" | "right"), or "" when the type has no label.
    static LabelOf(connectionType, ax, ay) {
        W := FlowGeometry.ELEMENT_WIDTH
        t := StrLower(connectionType)
        if (t = "normal" || t = "exception")
            return ""
        H := FlowGeometry.LABEL_HEIGHT
        if (t = "yes")
            return Map("rect", FlowRect(ax - W / 2, ay - H, W / 2 - 3, H), "align", "right")
        return Map("rect", FlowRect(ax + 5, ay - H, W / 2, H), "align", "left")
    }

    ; The buttons of a selected element as an Array of Maps("name", "x", "y"), the centre in flow units (v1 GDIp.ahk lines
    ; 828 to 960): edit and trash beside the head, plus below it; a loop has a second plus below its foot. A trigger's
    ; switch and star are marks (EditorStyle), not buttons.
    static ElementButtons(kind, x, y, heightOfVerticalBar) {
        W := FlowGeometry.ELEMENT_WIDTH, H := FlowGeometry.ELEMENT_HEIGHT, B := FlowGeometry.BUTTON_SIZE
        out := [
            Map("name", "edit", "x", x - W * 0.125 - B * 0.2, "y", y + W * 0.375),
            Map("name", "trash", "x", x + W * 9 / 8 + B * 0.2, "y", y + W * 0.375),
            Map("name", "plus", "x", x + W * 0.5, "y", y + W * 7 / 8 + B * 0.2)
        ]
        if (kind = "loop")
            out.Push(Map("name", "plus2", "x", x + W * 0.5
                , "y", y + W / 8 + H * 4 / 3 + heightOfVerticalBar + B * 0.2))
        return out
    }

    ; The centres of the marks of a trigger at the top left corner (x, y), as Map("switch", [x, y], "star", [x, y]).
    static TriggerMarks(x, y) => Map("switch", [x + FlowGeometry.ELEMENT_WIDTH * 0.8, y + FlowGeometry.ELEMENT_HEIGHT * 0.25]
        , "star", [x + FlowGeometry.ELEMENT_WIDTH * 0.15, y + FlowGeometry.ELEMENT_HEIGHT * 0.2])

    ; The buttons of a selected connection (v1 GDIp.ahk lines 861 to 900) from its five segments: edit, trash and plus
    ; on the middle of the third segment, and two move buttons at the ends (near the first and the last segment). The
    ; move buttons are left out when they would lie on top of each other (v1 rule with GRID).
    static ConnectionButtons(segments) {
        B := FlowGeometry.BUTTON_SIZE, G := FlowGeometry.GRID
        s3 := segments[3]
        mx := s3.X, my := s3.Y + s3.H / 2
        out := [
            Map("name", "edit", "x", mx - B * 1.3, "y", my),
            Map("name", "trash", "x", mx + B * 1.3, "y", my),
            Map("name", "plus", "x", mx, "y", my)
        ]
        m1x := segments[1].X, m1y := segments[1].Y + 20
        m2x := segments[5].X, m2y := segments[5].Bottom - 20
        if !(Abs(m2y - m1y) < G * 2 && Abs(m2x - m1x) < G * 5) {
            out.Push(Map("name", "move1", "x", m1x, "y", m1y))
            out.Push(Map("name", "move2", "x", m2x, "y", m2y))
        }
        return out
    }

    ; True if an element with this box is at least partly visible in the flow rectangle visible (GDIp.ahk line 593).
    static ElementVisible(bounds, visible) {
        return !(bounds.Right < visible.X || bounds.X > visible.Right
            || bounds.Bottom < visible.Y || bounds.Y > visible.Bottom)
    }

    ; True unless both ends of a connection lie beyond the same side of the visible rectangle (GDIp.ahk line 359). The
    ; check is the v1 one: a connection is skipped only when it is certainly out of view.
    static ConnectionVisible(sx, sy, ax, ay, visible) {
        return !((sx < visible.X && ax < visible.X) || (sx > visible.Right && ax > visible.Right)
            || (sy < visible.Y && ay < visible.Y) || (sy > visible.Bottom && ay > visible.Bottom))
    }
}
