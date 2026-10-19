#Requires AutoHotkey v2.0
; Unit tests for src/editor/render/ (WI-0083, E0085): the GDI+ wrapper drawn into a DIB without a window, read back
; pixel by pixel. No window, no dialog. The GDI objects of the process are counted with GetGuiResources.
#SingleInstance Off
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\core\AhfError.ahk
#Include ..\..\src\editor\render\Gdip.ahk
#Include ..\..\src\editor\render\GdipBrush.ahk
#Include ..\..\src\editor\render\GdipPen.ahk
#Include ..\..\src\editor\render\GdipFont.ahk
#Include ..\..\src\editor\render\GdipFormat.ahk
#Include ..\..\src\editor\render\GdipImage.ahk
#Include ..\..\src\editor\render\GdipCanvas.ahk

WHITE := 0xFFFFFFFF
BLACK := 0xFF000000
BLUE := 0xFF0000FF
RED := 0xFFFF0000
ICON_DIR := A_ScriptDir "\..\..\src\elements\Default\Icons\"

; The number of GDI objects of this process (GetGuiResources, flag 0 = GDI).
GdiObjects() {
    return DllCall("user32\GetGuiResources", "Ptr", DllCall("kernel32\GetCurrentProcess", "Ptr"), "UInt", 0, "UInt")
}

NewCanvas(w := 200, h := 100) {
    c := GdipCanvas(w, h)
    c.Clear(WHITE)
    return c
}

CheckStartupIsIdempotent() {
    Gdip.Startup()
    Gdip.Startup()
    Assert.True(Gdip.IsStarted)
}

CheckFilledRectangle() {
    c := NewCanvas()
    try {
        b := GdipBrush(BLUE)
        try
            c.FillRect(b, 10, 10, 50, 30)
        finally
            b.Destroy()
        Assert.Equal(c.Pixel(20, 20), BLUE, "inside the rectangle")
        Assert.Equal(c.Pixel(9, 20), WHITE, "left of the rectangle")
        Assert.Equal(c.Pixel(62, 20), WHITE, "two pixels right of the edge (the antialiased edge spreads one pixel)")
        Assert.Equal(c.Pixel(20, 44), WHITE, "four pixels below the rectangle (antialiasing)")
    } finally {
        c.Destroy()
    }
}

CheckRoundedCornersAreCut() {
    c := NewCanvas()
    try {
        b := GdipBrush(RED)
        try
            c.FillRoundRect(b, 20, 20, 100, 60, 15)
        finally
            b.Destroy()
        Assert.Equal(c.Pixel(70, 50), RED, "centre")
        Assert.Equal(c.Pixel(20, 20), WHITE, "the corner is rounded off")
    } finally {
        c.Destroy()
    }
}

CheckLineIsDrawn() {
    c := NewCanvas()
    try {
        c.SetAntiAlias(false)
        p := GdipPen(BLACK, 1.0)
        try
            c.DrawLine(p, 0, 50, 199, 50)
        finally
            p.Destroy()
        Assert.True(c.Pixel(100, 49) != WHITE || c.Pixel(100, 50) != WHITE, "the line is drawn at y 49 or 50")
        Assert.Equal(c.Pixel(100, 10), WHITE, "far from the line")
    } finally {
        c.Destroy()
    }
}

CheckPolygonIsFilled() {
    c := NewCanvas()
    try {
        b := GdipBrush(BLUE)
        try
            c.FillPolygon(b, [[10, 10], [90, 10], [50, 90]])
        finally
            b.Destroy()
        Assert.Equal(c.Pixel(50, 30), BLUE, "inside the triangle")
        Assert.Equal(c.Pixel(5, 90), WHITE, "outside the triangle")
    } finally {
        c.Destroy()
    }
}

; Text changes pixels only inside its box (the clipping of the format).
CheckTextChangesOnlyItsBox() {
    c := NewCanvas()
    try {
        f := GdipFont("Arial", 14, 1)
        fmt := GdipFormat(1, 1, false, false)
        b := GdipBrush(BLACK)
        try {
            c.DrawText(b, f, fmt, "Sleep 100 ms and more", 100, 20, 90, 60)
        } finally {
            b.Destroy()
            fmt.Destroy()
            f.Destroy()
        }
        inside := 0
        outside := 0
        loop c.height {
            y := A_Index - 1
            loop c.width {
                x := A_Index - 1
                if (c.Pixel(x, y) = WHITE)
                    continue
                if (x >= 100 && x < 190 && y >= 20 && y < 80)
                    inside += 1
                else
                    outside += 1
            }
        }
        Assert.True(inside > 0, "the text is drawn inside its box")
        Assert.Equal(outside, 0, "no pixel outside the box changed")
    } finally {
        c.Destroy()
    }
}

CheckIconFileLoadsAndIsDrawn() {
    img := GdipImage(ICON_DIR "Sleep.ico")
    try {
        Assert.True(img.width > 0 && img.height > 0, "the icon has a size")
        c := NewCanvas(120, 120)
        try {
            c.DrawImage(img, 0, 0, 64, 64)
            changed := 0
            loop 64 * 64 {
                x := Mod(A_Index - 1, 64)
                y := (A_Index - 1) // 64
                if (c.Pixel(x, y) != WHITE)
                    changed += 1
            }
            Assert.True(changed > 0, "the icon is drawn into its box")
            Assert.Equal(c.Pixel(100, 100), WHITE, "nothing outside the box")
        } finally {
            c.Destroy()
        }
    } finally {
        img.Destroy()
    }
}

CheckPngFileLoads() {
    img := GdipImage(ICON_DIR "Bug.png")
    try
        Assert.True(img.width > 0 && img.height > 0)
    finally
        img.Destroy()
}

; The same image with alpha 0.5 is lighter than with alpha 1.0 over a white background.
CheckAlphaMakesTheImageLighter() {
    img := GdipImage(ICON_DIR "Bug.png")
    try {
        full := NewCanvas(80, 80)
        half := NewCanvas(80, 80)
        try {
            full.DrawImage(img, 0, 0, 64, 64, 1.0)
            half.DrawImage(img, 0, 0, 64, 64, 0.5)
            sumFull := 0
            sumHalf := 0
            loop 64 * 64 {
                x := Mod(A_Index - 1, 64)
                y := (A_Index - 1) // 64
                sumFull += (full.Pixel(x, y) >> 8) & 0xFF
                sumHalf += (half.Pixel(x, y) >> 8) & 0xFF
            }
            Assert.True(sumHalf > sumFull, "alpha 0.5 is lighter than alpha 1.0")
        } finally {
            full.Destroy()
            half.Destroy()
        }
    } finally {
        img.Destroy()
    }
}

; GdipLoadImageFromFile reports a missing file as OutOfMemory (3), not FileNotFound (verified here): the test checks
; that the error names the call and a status name, whichever it is.
CheckMissingFileThrowsWithStatusName() {
    err := Assert.Throws(() => GdipImage(ICON_DIR "does_not_exist.png"), AhfError)
    Assert.True(InStr(err.Message, "GdipLoadImageFromFile returned") > 0, "the call is named: " err.Message)
    Assert.True(RegExMatch(err.Message, "returned \d+ \(\w+\)"), "a status name is given: " err.Message)
}

CheckStatusNames() {
    Assert.Equal(Gdip.StatusName(0), "Ok")
    Assert.Equal(Gdip.StatusName(10), "FileNotFound")
    Assert.Equal(Gdip.StatusName(99), "Unknown")
}

CheckCopyToAnotherDc() {
    src := NewCanvas(40, 20)
    dst := NewCanvas(100, 60)
    try {
        b := GdipBrush(RED)
        try
            src.FillRect(b, 0, 0, 40, 20)
        finally
            b.Destroy()
        src.CopyToDc(dst.hdc, 30, 10)
        Assert.Equal(dst.Pixel(35, 15), RED, "copied inside the target")
        Assert.Equal(dst.Pixel(5, 5), WHITE, "the rest of the target stays")
    } finally {
        src.Destroy()
        dst.Destroy()
    }
}

CheckPixelOutsideIsAnError() {
    c := NewCanvas(10, 10)
    try
        Assert.Throws(() => c.Pixel(10, 0), AhfError)
    finally
        c.Destroy()
}

; One frame with the objects a frame creates and destroys: brush, pen, font, format, path, image attributes.
DrawFrame(c, img) {
    b := GdipBrush(BLUE)
    p := GdipPen(BLACK, 2.0)
    f := GdipFont("Segoe UI", 12, 0)
    fmt := GdipFormat(0, 1, true, false)
    tb := GdipBrush(BLACK)
    try {
        c.FillRoundRect(b, 10, 10, 120, 60, 8)
        c.DrawRoundRect(p, 10, 10, 120, 60, 8)
        c.DrawText(tb, f, fmt, "A name of a flow element that is too long", 12, 40, 116, 26)
        c.DrawImage(img, 140, 10, 48, 48, 0.5)
        c.DrawLines(p, [[0, 90], [40, 90], [40, 110], [80, 110]])
    } finally {
        tb.Destroy()
        fmt.Destroy()
        f.Destroy()
        p.Destroy()
        b.Destroy()
    }
}

; 1000 frames leave the number of GDI objects of the process unchanged.
CheckFramesLeaveNoGdiObjects() {
    img := GdipImage(ICON_DIR "Bug.png")
    c := NewCanvas(200, 100)
    try {
        DrawFrame(c, img)
        before := GdiObjects()
        loop 1000
            DrawFrame(c, img)
        after := GdiObjects()
        Assert.Equal(after, before, "GDI objects before and after 1000 frames")
    } finally {
        c.Destroy()
        img.Destroy()
    }
}

CheckClipRestrictsDrawing() {
    c := NewCanvas(100, 100)
    try {
        b := GdipBrush(BLUE)
        try {
            c.SetClip(10, 10, 20, 20)
            c.FillRect(b, 0, 0, 100, 100)
            c.ResetClip()
        } finally
            b.Destroy()
        Assert.Equal(c.Pixel(15, 15), BLUE, "inside the clip")
        Assert.Equal(c.Pixel(5, 5), WHITE, "outside the clip")
        Assert.Equal(c.Pixel(50, 50), WHITE, "outside the clip, far away")
    } finally {
        c.Destroy()
    }
}

CheckEllipseIsFilled() {
    c := NewCanvas()
    try {
        b := GdipBrush(BLUE)
        try
            c.FillEllipse(b, 10, 10, 60, 40)
        finally
            b.Destroy()
        Assert.Equal(c.Pixel(40, 30), BLUE, "centre of the ellipse")
        Assert.Equal(c.Pixel(11, 11), WHITE, "corner of the box, outside the ellipse")
    } finally {
        c.Destroy()
    }
}

CheckRegionCopyUsesTheOffset() {
    src := NewCanvas(100, 100)
    dst := NewCanvas(60, 60)
    try {
        b := GdipBrush(BLUE)
        try
            src.FillRect(b, 0, 0, 50, 50)
        finally
            b.Destroy()
        src.CopyRegionTo(dst, 0, 0, 30, 30, 20, 20)
        Assert.Equal(dst.Pixel(0, 0), BLUE, "source pixel (20, 20) is blue")
        Assert.Equal(dst.Pixel(29, 29), BLUE, "source pixel (49, 49) is blue")
        Assert.Equal(dst.Pixel(30, 30), WHITE, "outside the copied part (not drawn)")
    } finally {
        src.Destroy()
        dst.Destroy()
    }
}

CheckScaledImageHasTheSizeAndIsDrawn() {
    img := GdipImage(ICON_DIR "Sleep.ico")
    try {
        s := GdipImage.Scaled(img, 40, 30)
        try {
            Assert.Equal(s.width, 40, "width of the scaled copy")
            Assert.Equal(s.height, 30, "height of the scaled copy")
            c := NewCanvas(40, 30)
            try {
                c.DrawImage(s, 0, 0, 40, 30)
                changed := 0
                loop 30 {
                    y := A_Index - 1
                    loop 40 {
                        if (c.Pixel(A_Index - 1, y) != WHITE)
                            changed += 1
                    }
                }
                Assert.True(changed > 100, "the scaled icon changes at least 100 pixels, got " changed)
            } finally {
                c.Destroy()
            }
        } finally {
            s.Destroy()
        }
    } finally {
        img.Destroy()
    }
}

CheckSavePngWritesAPngFile() {
    c := NewCanvas(20, 10)
    path := A_Temp "\ahf_gdip_test_" A_TickCount ".png"
    try {
        c.SavePng(path)
        data := FileRead(path, "RAW")
        Assert.True(FileGetSize(path) > 60, "the file has the size of a small PNG")
        Assert.Equal(NumGet(data, 0, "UChar"), 0x89, "the PNG signature starts with 0x89")
        Assert.Equal(NumGet(data, 1, "UChar"), 0x50, "the PNG signature continues with P")
    } finally {
        c.Destroy()
        try FileDelete(path)
    }
}

Gdip.Startup()
TestRun.Init()

TestRun.Case("GdiplusStartup can be called twice", CheckStartupIsIdempotent)
TestRun.Case("SetClip restricts the drawing until ResetClip", CheckClipRestrictsDrawing)
TestRun.Case("an ellipse is filled inside its box only", CheckEllipseIsFilled)
TestRun.Case("CopyRegionTo copies the part at the source offset", CheckRegionCopyUsesTheOffset)
TestRun.Case("a scaled copy of an icon has the new size and is drawn", CheckScaledImageHasTheSizeAndIsDrawn)
TestRun.Case("SavePng writes a PNG file", CheckSavePngWritesAPngFile)
TestRun.Case("a filled rectangle has its color inside and white outside", CheckFilledRectangle)
TestRun.Case("a rounded rectangle is filled and its corner is cut", CheckRoundedCornersAreCut)
TestRun.Case("a line is drawn where it is, nowhere else", CheckLineIsDrawn)
TestRun.Case("a polygon is filled inside its outline", CheckPolygonIsFilled)
TestRun.Case("text changes pixels only inside its box", CheckTextChangesOnlyItsBox)
TestRun.Case("the icon file Sleep.ico loads and is drawn into its box", CheckIconFileLoadsAndIsDrawn)
TestRun.Case("the png file Bug.png loads", CheckPngFileLoads)
TestRun.Case("an image with alpha 0.5 is lighter than with alpha 1.0", CheckAlphaMakesTheImageLighter)
TestRun.Case("a missing image file throws AhfError with the status name", CheckMissingFileThrowsWithStatusName)
TestRun.Case("status names are read from the status number", CheckStatusNames)
TestRun.Case("CopyToDc copies the canvas into another device context", CheckCopyToAnotherDc)
TestRun.Case("a pixel outside the canvas throws AhfError", CheckPixelOutsideIsAnError)
TestRun.Case("1000 frames leave the GDI objects of the process unchanged", CheckFramesLeaveNoGdiObjects)

Gdip.Shutdown()
TestRun.Finish()
