#Requires AutoHotkey v2.0

; A string format (GDI+ GpStringFormat) for GdipCanvas.Text: horizontal and vertical alignment, ellipsis when the
; text does not fit the box, no wrapping. The text is clipped to the box (the default of GDI+ without NoClip).
; Destroy() deletes it.
class GdipFormat {
    handle := 0

    ; h: 0 near, 1 center, 2 far. v: the same for the lines. ellipsis: true adds "..." at the end of a text that
    ; does not fit. wrap: false keeps the text on one line.
    __New(h := 0, v := 0, ellipsis := false, wrap := true) {
        f := 0
        Gdip.Check(DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "UShort", 0, "Ptr*", &f, "Int")
            , "GdipCreateStringFormat")
        this.handle := f
        Gdip.Check(DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", f, "Int", h, "Int"), "GdipSetStringFormatAlign")
        Gdip.Check(DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", f, "Int", v, "Int")
            , "GdipSetStringFormatLineAlign")
        if (ellipsis)
            Gdip.Check(DllCall("gdiplus\GdipSetStringFormatTrimming", "Ptr", f, "Int", 3, "Int")
                , "GdipSetStringFormatTrimming")   ; StringTrimmingEllipsisCharacter
        if (!wrap)
            Gdip.Check(DllCall("gdiplus\GdipSetStringFormatFlags", "Ptr", f, "Int", 0x1000, "Int")
                , "GdipSetStringFormatFlags")      ; StringFormatFlagsNoWrap
    }

    Destroy() {
        if (this.handle) {
            DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", this.handle, "Int")
            this.handle := 0
        }
    }
}
