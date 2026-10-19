#Requires AutoHotkey v2.0

; A rectangle in flow coordinates (WI-0084): X, Y, W, H. A connection segment is a rectangle with W or H 0, so a
; segment is a line; the hit test widens it by a margin (FlowHitTest). Values are plain numbers; a rectangle is never
; changed after it is created.
class FlowRect {
    __New(x, y, w, h) {
        this.X := x
        this.Y := y
        this.W := w
        this.H := h
    }

    Right => this.X + this.W
    Bottom => this.Y + this.H

    ; True if the point (px, py) lies in the rectangle, grown by margin on every side.
    Contains(px, py, margin := 0) {
        return px >= this.X - margin && px <= this.Right + margin
            && py >= this.Y - margin && py <= this.Bottom + margin
    }

    ; The smallest rectangle that holds all of rects. An empty list gives the empty rectangle at 0,0.
    static Union(rects) {
        if (rects.Length = 0)
            return FlowRect(0, 0, 0, 0)
        left := rects[1].X, top := rects[1].Y, right := rects[1].Right, bottom := rects[1].Bottom
        for r in rects {
            left := Min(left, r.X)
            top := Min(top, r.Y)
            right := Max(right, r.Right)
            bottom := Max(bottom, r.Bottom)
        }
        return FlowRect(left, top, right - left, bottom - top)
    }
}
