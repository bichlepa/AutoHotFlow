#Requires AutoHotkey v2.0

; A pen (GDI+ GpPen) with a color and a width in device pixels. Destroy() deletes it.
class GdipPen {
    handle := 0

    __New(argb, width := 1.0) {
        h := 0
        UnitPixel := 2
        Gdip.Check(DllCall("gdiplus\GdipCreatePen1", "UInt", argb, "Float", width, "Int", UnitPixel, "Ptr*", &h
            , "Int"), "GdipCreatePen1")
        this.handle := h
    }

    Destroy() {
        if (this.handle) {
            DllCall("gdiplus\GdipDeletePen", "Ptr", this.handle, "Int")
            this.handle := 0
        }
    }
}
