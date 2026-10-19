#Requires AutoHotkey v2.0

; An image read from a file (GDI+ GpImage): .png, .ico and the other formats GDI+ reads. The file is read once, when
; the object is created; it is not read again while the frames are drawn. Destroy() disposes it.
class GdipImage {
    handle := 0
    width := 0
    height := 0

    __New(path) {
        h := 0
        Gdip.Check(DllCall("gdiplus\GdipLoadImageFromFile", "WStr", path, "Ptr*", &h, "Int")
            , "GdipLoadImageFromFile")
        this.handle := h
        w := 0
        hgt := 0
        try {
            Gdip.Check(DllCall("gdiplus\GdipGetImageWidth", "Ptr", h, "UInt*", &w, "Int"), "GdipGetImageWidth")
            Gdip.Check(DllCall("gdiplus\GdipGetImageHeight", "Ptr", h, "UInt*", &hgt, "Int"), "GdipGetImageHeight")
        } catch as e {
            this.Destroy()
            throw e
        }
        this.width := w
        this.height := hgt
    }

    Destroy() {
        if (this.handle) {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", this.handle, "Int")
            this.handle := 0
        }
    }
}
