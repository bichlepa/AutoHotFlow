#Requires AutoHotkey v2.0

; GDI+ wrapper of the editor renderer (WI-0083, E0085, risk R0002). The process-wide part: GdiplusStartup once and
; GdiplusShutdown at the end, and the check of every GDI+ status (anything but Ok throws AhfError with the status
; name). The objects are in their own classes: GdipCanvas (a DIB section with its memory DC and a graphics),
; GdipBrush, GdipPen, GdipFont, GdipFormat and GdipImage. Each of them has Destroy(); the caller destroys what it
; created. Colors are ARGB (0xAARRGGBB). Sizes and positions are in device pixels (float).
;
; Usage: Gdip.Startup(); c := GdipCanvas(200, 100); ... c.Destroy(); Gdip.Shutdown()
class Gdip {
    static token := 0

    ; Starts GDI+ once per process. Calling it again does nothing.
    ; The token is passed as UInt, as v1 does (Lib/GDI+/Gdip.ahk). With Ptr, GdiplusShutdown raised an exception
    ; in AutoHotkey 2.0.30 (verified, see doc/howto/gdi-and-rendering.md).
    static Startup() {
        if (this.token)
            return
        if (!DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr"))
            DllCall("LoadLibrary", "Str", "gdiplus", "Ptr")
        input := Buffer(24, 0)
        NumPut("UInt", 1, input)                ; GdiplusVersion 1 (GdiplusStartupInput)
        tok := 0
        Gdip.Check(DllCall("gdiplus\GdiplusStartup", "UInt*", &tok, "Ptr", input, "Ptr", 0, "Int"), "GdiplusStartup")
        if (tok = 0 || tok > 0xFFFFFFFF)
            throw AhfError("GdiplusStartup returned the token " tok " (not a 32 bit token)", ErrCode.INTERNAL)
        this.token := tok
    }

    ; Ends GDI+. Every object must be destroyed before. Calling it when GDI+ is not running does nothing.
    static Shutdown() {
        if (!this.token)
            return
        DllCall("gdiplus\GdiplusShutdown", "UInt", this.token)
        this.token := 0
    }

    static IsStarted {
        get => this.token != 0
    }

    ; Throws AhfError with the name of the status when it is not Ok (0). fn names the GDI+ call for the message.
    static Check(status, fn := "") {
        if (status != 0)
            throw AhfError("GDI+ " fn " returned " status " (" Gdip.StatusName(status) ")", ErrCode.INTERNAL)
        return status
    }

    static StatusName(status) {
        static names := [
            "Ok", "GenericError", "InvalidParameter", "OutOfMemory", "ObjectBusy", "InsufficientBuffer",
            "NotImplemented", "Win32Error", "WrongState", "Aborted", "FileNotFound", "ValueOverflow", "AccessDenied",
            "UnknownImageFormat", "FontFamilyNotFound", "FontStyleNotFound", "NotTrueTypeFont",
            "UnsupportedGdiplusVersion", "GdiplusNotInitialized", "PropertyNotFound", "PropertyNotSupported",
            "ProfileNotFound"]
        return (status >= 0 && status < names.Length) ? names[status + 1] : "Unknown"
    }

    ; A point list for the polygon and line calls: an array of [x, y] pairs to a buffer of PointF.
    static Points(pts) {
        buf := Buffer(8 * pts.Length)
        for i, p in pts {
            NumPut("Float", p[1], buf, 8 * (i - 1))
            NumPut("Float", p[2], buf, 8 * (i - 1) + 4)
        }
        return buf
    }
}
