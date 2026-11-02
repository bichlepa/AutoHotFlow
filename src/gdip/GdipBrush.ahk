#Requires AutoHotkey v2.0

; A solid brush (GDI+ GpBrush). Create it with the color; Destroy() deletes it.
class GdipBrush {
    handle := 0

    __New(argb) {
        h := 0
        Gdip.Check(DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &h, "Int"), "GdipCreateSolidFill")
        this.handle := h
    }

    Destroy() {
        if (this.handle) {
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", this.handle, "Int")
            this.handle := 0
        }
    }
}
