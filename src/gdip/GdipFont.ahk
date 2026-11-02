#Requires AutoHotkey v2.0

; A font: a font family by name and a font (GDI+ GpFontFamily and GpFont) of a size in device pixels. The style is
; the sum of the GDI+ FontStyle values: Bold 1, Italic 2, Underline 4, Strikeout 8. Destroy() deletes both.
class GdipFont {
    family := 0
    handle := 0

    __New(familyName, size, style := 0) {
        fam := 0
        Gdip.Check(DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", familyName, "Ptr", 0, "Ptr*", &fam, "Int")
            , "GdipCreateFontFamilyFromName")
        this.family := fam
        h := 0
        UnitPixel := 2
        try {
            Gdip.Check(DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", size, "Int", style, "Int", UnitPixel
                , "Ptr*", &h, "Int"), "GdipCreateFont")
        } catch as e {
            this.Destroy()
            throw e
        }
        this.handle := h
    }

    Destroy() {
        if (this.handle) {
            DllCall("gdiplus\GdipDeleteFont", "Ptr", this.handle, "Int")
            this.handle := 0
        }
        if (this.family) {
            DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", this.family, "Int")
            this.family := 0
        }
    }
}
