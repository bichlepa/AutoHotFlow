#Requires AutoHotkey v2.0

; An image (GDI+ GpImage): read from a file, or a scaled copy of another image (Scaled). The file is read once, when the
; object is created; it is not read again while the frames are drawn. Destroy() disposes it.
class GdipImage {
    handle := 0
    width := 0
    height := 0

    ; path: the file to read. Without a path the object is empty (used by Scaled).
    __New(path := "") {
        if (path = "")
            return
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

    ; A copy of source drawn into a new w x h bitmap with high quality interpolation. The renderer uses it for icons
    ; that are drawn at the same size in every frame: the scaling is paid once, not on every draw (MS-0044). The copy
    ; is an ARGB bitmap of its own; the caller destroys it.
    static Scaled(source, w, h) {
        PixelFormat32bppARGB := 0x26200A
        bmp := 0
        Gdip.Check(DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0
            , "Int", PixelFormat32bppARGB, "Ptr", 0, "Ptr*", &bmp, "Int"), "GdipCreateBitmapFromScan0")
        g := 0
        try {
            Gdip.Check(DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &g, "Int")
                , "GdipGetImageGraphicsContext")
            Gdip.Check(DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g, "Int", 7, "Int")
                , "GdipSetInterpolationMode")          ; HighQualityBicubic
            Gdip.Check(DllCall("gdiplus\GdipDrawImageRectRect", "Ptr", g, "Ptr", source.handle
                , "Float", 0, "Float", 0, "Float", w, "Float", h
                , "Float", 0, "Float", 0, "Float", source.width, "Float", source.height
                , "Int", 2, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Int"), "GdipDrawImageRectRect")
        } catch as e {
            if (g)
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g, "Int")
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp, "Int")
            throw e
        }
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g, "Int")
        img := GdipImage()
        img.handle := bmp
        img.width := w
        img.height := h
        return img
    }

    Destroy() {
        if (this.handle) {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", this.handle, "Int")
            this.handle := 0
        }
    }
}
