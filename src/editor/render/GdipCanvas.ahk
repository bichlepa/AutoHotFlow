#Requires AutoHotkey v2.0

; The target of the renderer: a 32 bit top-down DIB section with its memory DC and a GDI+ graphics on that DC. It needs
; no window; a window gets the result by CopyToWindow (BitBlt). Pixel(x, y) reads a pixel back (ARGB) for tests.
; Every drawing method takes the wrapper objects (GdipBrush, GdipPen, GdipFont, GdipFormat, GdipImage) and uses their
; handles; a method that creates a GDI+ object of its own (a path) deletes it before it returns. Destroy() releases the
; graphics, the DIB and the DC. Requires Gdip.Startup() (the constructor calls it when needed).
class GdipCanvas {
    width := 0
    height := 0
    hdc := 0
    hbm := 0
    oldBm := 0
    bits := 0
    graphics := 0

    __New(width, height) {
        if (width < 1 || height < 1)
            throw AhfError("canvas size " width "x" height " is not valid", ErrCode.BAD_ARGS)
        Gdip.Startup()
        this.width := width
        this.height := height
        try {
            bmi := Buffer(40, 0)
            NumPut("UInt", 40, bmi, 0)              ; biSize
            NumPut("Int", width, bmi, 4)            ; biWidth
            NumPut("Int", -height, bmi, 8)          ; biHeight < 0: top-down, row 0 first
            NumPut("UShort", 1, bmi, 12)            ; biPlanes
            NumPut("UShort", 32, bmi, 14)           ; biBitCount
            this.hdc := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0, "Ptr")
            if (!this.hdc)
                throw AhfError("CreateCompatibleDC failed", ErrCode.INTERNAL)
            bits := 0
            this.hbm := DllCall("gdi32\CreateDIBSection", "Ptr", this.hdc, "Ptr", bmi, "UInt", 0, "Ptr*", &bits
                , "Ptr", 0, "UInt", 0, "Ptr")
            if (!this.hbm)
                throw AhfError("CreateDIBSection failed, Windows error " A_LastError, ErrCode.INTERNAL)
            this.bits := bits
            this.oldBm := DllCall("gdi32\SelectObject", "Ptr", this.hdc, "Ptr", this.hbm, "Ptr")
            g := 0
            Gdip.Check(DllCall("gdiplus\GdipCreateFromHDC", "Ptr", this.hdc, "Ptr*", &g, "Int"), "GdipCreateFromHDC")
            this.graphics := g
            this.SetAntiAlias(true)
        } catch as e {
            this.Destroy()
            throw e
        }
    }

    ; Anti-aliasing of the shapes and of the text. On: AntiAlias (4) and AntiAlias text; off: no smoothing (3) and
    ; single-bit text without anti-aliasing (1).
    SetAntiAlias(on) {
        Gdip.Check(DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", this.graphics, "Int", on ? 4 : 3, "Int")
            , "GdipSetSmoothingMode")
        Gdip.Check(DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", this.graphics, "Int", on ? 4 : 1, "Int")
            , "GdipSetTextRenderingHint")
    }

    ; Fills the whole canvas with a color (ARGB).
    Clear(argb) {
        Gdip.Check(DllCall("gdiplus\GdipGraphicsClear", "Ptr", this.graphics, "UInt", argb, "Int")
            , "GdipGraphicsClear")
    }

    FillRect(brush, x, y, w, h) {
        Gdip.Check(DllCall("gdiplus\GdipFillRectangle", "Ptr", this.graphics, "Ptr", brush.handle, "Float", x
            , "Float", y, "Float", w, "Float", h, "Int"), "GdipFillRectangle")
    }

    DrawRect(pen, x, y, w, h) {
        Gdip.Check(DllCall("gdiplus\GdipDrawRectangle", "Ptr", this.graphics, "Ptr", pen.handle, "Float", x
            , "Float", y, "Float", w, "Float", h, "Int"), "GdipDrawRectangle")
    }

    ; A rectangle with rounded corners of radius r (clamped to half the smaller side), as a path.
    FillRoundRect(brush, x, y, w, h, r) {
        path := this.RoundPath(x, y, w, h, r)
        try {
            Gdip.Check(DllCall("gdiplus\GdipFillPath", "Ptr", this.graphics, "Ptr", brush.handle, "Ptr", path
                , "Int"), "GdipFillPath")
        } finally {
            DllCall("gdiplus\GdipDeletePath", "Ptr", path, "Int")
        }
    }

    DrawRoundRect(pen, x, y, w, h, r) {
        path := this.RoundPath(x, y, w, h, r)
        try {
            Gdip.Check(DllCall("gdiplus\GdipDrawPath", "Ptr", this.graphics, "Ptr", pen.handle, "Ptr", path
                , "Int"), "GdipDrawPath")
        } finally {
            DllCall("gdiplus\GdipDeletePath", "Ptr", path, "Int")
        }
    }

    ; The path of a rounded rectangle. The caller deletes it (GdipDeletePath).
    RoundPath(x, y, w, h, r) {
        r := Min(r, w / 2, h / 2)
        d := 2 * r
        path := 0
        Gdip.Check(DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path, "Int"), "GdipCreatePath")
        try {
            this.ArcTo(path, x, y, d, 180, 90)
            this.ArcTo(path, x + w - d, y, d, 270, 90)
            this.ArcTo(path, x + w - d, y + h - d, d, 0, 90)
            this.ArcTo(path, x, y + h - d, d, 90, 90)
            Gdip.Check(DllCall("gdiplus\GdipClosePathFigure", "Ptr", path, "Int"), "GdipClosePathFigure")
        } catch as e {
            DllCall("gdiplus\GdipDeletePath", "Ptr", path, "Int")
            throw e
        }
        return path
    }

    ArcTo(path, x, y, d, startAngle, sweep) {
        Gdip.Check(DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", x, "Float", y, "Float", d, "Float", d
            , "Float", startAngle, "Float", sweep, "Int"), "GdipAddPathArc")
    }

    ; pts: an array of [x, y] pairs.
    FillPolygon(brush, pts) {
        buf := Gdip.Points(pts)
        Gdip.Check(DllCall("gdiplus\GdipFillPolygon", "Ptr", this.graphics, "Ptr", brush.handle, "Ptr", buf
            , "Int", pts.Length, "Int", 0, "Int"), "GdipFillPolygon")
    }

    DrawPolygon(pen, pts) {
        buf := Gdip.Points(pts)
        Gdip.Check(DllCall("gdiplus\GdipDrawPolygon", "Ptr", this.graphics, "Ptr", pen.handle, "Ptr", buf
            , "Int", pts.Length, "Int"), "GdipDrawPolygon")
    }

    ; A connected line through the points (pts: [x, y] pairs, at least two).
    DrawLines(pen, pts) {
        buf := Gdip.Points(pts)
        Gdip.Check(DllCall("gdiplus\GdipDrawLines", "Ptr", this.graphics, "Ptr", pen.handle, "Ptr", buf
            , "Int", pts.Length, "Int"), "GdipDrawLines")
    }

    DrawLine(pen, x1, y1, x2, y2) {
        Gdip.Check(DllCall("gdiplus\GdipDrawLine", "Ptr", this.graphics, "Ptr", pen.handle, "Float", x1
            , "Float", y1, "Float", x2, "Float", y2, "Int"), "GdipDrawLine")
    }

    ; Text in the box (x, y, w, h). The format decides the alignment, the ellipsis and the wrapping; the text is clipped
    ; to the box.
    DrawText(brush, font, format, text, x, y, w, h) {
        rect := Buffer(16, 0)
        NumPut("Float", x, rect, 0)
        NumPut("Float", y, rect, 4)
        NumPut("Float", w, rect, 8)
        NumPut("Float", h, rect, 12)
        Gdip.Check(DllCall("gdiplus\GdipDrawString", "Ptr", this.graphics, "WStr", text, "Int", -1
            , "Ptr", font.handle, "Ptr", rect, "Ptr", format.handle, "Ptr", brush.handle, "Int")
            , "GdipDrawString")
    }

    ; An image scaled into the box (x, y, w, h). alpha 0.0 to 1.0; below 1.0 the image is drawn with a color matrix.
    DrawImage(image, x, y, w, h, alpha := 1.0) {
        attr := 0
        if (alpha < 1.0) {
            attr := this.AlphaAttributes(alpha)
        }
        try {
            Gdip.Check(DllCall("gdiplus\GdipDrawImageRectRect", "Ptr", this.graphics, "Ptr", image.handle
                , "Float", x, "Float", y, "Float", w, "Float", h
                , "Float", 0, "Float", 0, "Float", image.width, "Float", image.height
                , "Int", 2, "Ptr", attr, "Ptr", 0, "Ptr", 0, "Int"), "GdipDrawImageRectRect")
        } finally {
            if (attr)
                DllCall("gdiplus\GdipDisposeImageAttributes", "Ptr", attr, "Int")
        }
    }

    ; Image attributes with a color matrix that only sets the alpha. The caller disposes them.
    AlphaAttributes(alpha) {
        attr := 0
        Gdip.Check(DllCall("gdiplus\GdipCreateImageAttributes", "Ptr*", &attr, "Int"), "GdipCreateImageAttributes")
        m := Buffer(100, 0)                      ; 5 x 5 floats, row-major
        NumPut("Float", 1.0, m, 0)               ; [0][0]
        NumPut("Float", 1.0, m, 24)              ; [1][1]
        NumPut("Float", 1.0, m, 48)              ; [2][2]
        NumPut("Float", alpha, m, 72)            ; [3][3] alpha
        NumPut("Float", 1.0, m, 96)              ; [4][4]
        try {
            Gdip.Check(DllCall("gdiplus\GdipSetImageAttributesColorMatrix", "Ptr", attr, "Int", 1, "Int", 1
                , "Ptr", m, "Ptr", 0, "Int", 0, "Int"), "GdipSetImageAttributesColorMatrix")
        } catch as e {
            DllCall("gdiplus\GdipDisposeImageAttributes", "Ptr", attr, "Int")
            throw e
        }
        return attr
    }

    ; Copies the canvas into a device context at x, y (BitBlt, SRCCOPY).
    CopyToDc(hdcDest, x, y) {
        ok := DllCall("gdi32\BitBlt", "Ptr", hdcDest, "Int", x, "Int", y, "Int", this.width, "Int", this.height
            , "Ptr", this.hdc, "Int", 0, "Int", 0, "UInt", 0x00CC0020, "Int")
        if (!ok)
            throw AhfError("BitBlt failed, Windows error " A_LastError, ErrCode.INTERNAL)
    }

    ; Copies the w x h pixels of this canvas that start at (sx, sy) into dest at (dx, dy) (BitBlt, SRCCOPY). The renderer
    ; shows its cached layer with it: the layer is larger than the window, so a pan is a copy with another offset.
    CopyRegionTo(dest, dx, dy, w, h, sx, sy) {
        ok := DllCall("gdi32\BitBlt", "Ptr", dest.hdc, "Int", dx, "Int", dy, "Int", w, "Int", h
            , "Ptr", this.hdc, "Int", sx, "Int", sy, "UInt", 0x00CC0020, "Int")
        if (!ok)
            throw AhfError("BitBlt failed, Windows error " A_LastError, ErrCode.INTERNAL)
    }

    ; Restricts the following drawing to the rectangle (x, y, w, h). ResetClip removes the restriction.
    SetClip(x, y, w, h) {
        Gdip.Check(DllCall("gdiplus\GdipSetClipRect", "Ptr", this.graphics, "Float", x, "Float", y, "Float", w
            , "Float", h, "Int", 0, "Int"), "GdipSetClipRect")   ; CombineModeReplace
    }

    ResetClip() {
        Gdip.Check(DllCall("gdiplus\GdipResetClip", "Ptr", this.graphics, "Int"), "GdipResetClip")
    }

    FillEllipse(brush, x, y, w, h) {
        Gdip.Check(DllCall("gdiplus\GdipFillEllipse", "Ptr", this.graphics, "Ptr", brush.handle, "Float", x
            , "Float", y, "Float", w, "Float", h, "Int"), "GdipFillEllipse")
    }

    ; Text rendering hint: 1 no anti-aliasing, 4 anti-aliased with grid fitting, 5 ClearType grid fitting (the text
    ; needs an opaque background, which the renderer has).
    SetTextHint(hint) {
        Gdip.Check(DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", this.graphics, "Int", hint, "Int")
            , "GdipSetTextRenderingHint")
    }

    ; Writes the canvas as a PNG file. The file is replaced if it exists.
    SavePng(path) {
        bmp := 0
        Gdip.Check(DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", this.hbm, "Ptr", 0, "Ptr*", &bmp, "Int")
            , "GdipCreateBitmapFromHBITMAP")
        try {
            clsid := Gdip.EncoderClsid("image/png")
            Gdip.Check(DllCall("gdiplus\GdipSaveImageToFile", "Ptr", bmp, "WStr", path, "Ptr", clsid, "Ptr", 0
                , "Int"), "GdipSaveImageToFile")
        } finally {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp, "Int")
        }
    }

    ; Copies the canvas into the client area of a window at x, y.
    CopyToWindow(hwnd, x, y) {
        hdcWin := DllCall("user32\GetDC", "Ptr", hwnd, "Ptr")
        if (!hdcWin)
            throw AhfError("GetDC failed, Windows error " A_LastError, ErrCode.INTERNAL)
        try {
            this.CopyToDc(hdcWin, x, y)
        } finally {
            DllCall("user32\ReleaseDC", "Ptr", hwnd, "Ptr", hdcWin, "Int")
        }
    }

    ; The ARGB value of one pixel (0xAARRGGBB). x and y are counted from the top left.
    Pixel(x, y) {
        if (x < 0 || y < 0 || x >= this.width || y >= this.height)
            throw AhfError("pixel " x "," y " is outside the canvas", ErrCode.BAD_ARGS)
        return NumGet(this.bits, (y * this.width + x) * 4, "UInt")
    }

    ; Releases the graphics, the DIB and the DC. Safe to call more than once and after a failed constructor.
    Destroy() {
        if (this.graphics) {
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", this.graphics, "Int")
            this.graphics := 0
        }
        if (this.hdc && this.oldBm)
            DllCall("gdi32\SelectObject", "Ptr", this.hdc, "Ptr", this.oldBm, "Ptr")
        this.oldBm := 0
        if (this.hbm) {
            DllCall("gdi32\DeleteObject", "Ptr", this.hbm, "Int")
            this.hbm := 0
        }
        if (this.hdc) {
            DllCall("gdi32\DeleteDC", "Ptr", this.hdc, "Int")
            this.hdc := 0
        }
        this.bits := 0
    }
}
