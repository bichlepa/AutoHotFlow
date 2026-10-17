#Requires AutoHotkey v2.0

; The layout of the real windows (REQ-USE-090; moved here from elements/base/DialogWindow.ahk in WI-0069): per-monitor
; DPI awareness, the sizes at 100 % (96 dpi) kept in a list and scaled by the DPI of the window, the font, the show
; without a flicker, and WM_DPICHANGED. Used by the dialog elements (DialogWindow) and by the UI roles (ui_common/UiWindow).
; It lives in core/ because an element may include core/ only (ARCHITECTURE 8); the file has no window of its own and
; decides nothing about the content of a window.
;
; Usage: g := Gui("-DPIScale", title); lay := GuiLayout.Create(g, width, height); GuiLayout.Place(lay, g.AddText(...), x, y, w, h);
; GuiLayout.Show(lay); ... GuiLayout.Destroy(lay) before g.Destroy(). All positions and sizes are in pixels at 100 %.
class GuiLayout {
    static _dpiSet := false

    ; Declares the process as per-monitor DPI aware for the windows of this thread, so they are drawn sharp on a
    ; display with a scaling above 100 % (REQ-USE-090). The sizes are scaled by the layout below.
    static EnableDpi() {
        if (this._dpiSet)
            return
        this._dpiSet := true
        try DllCall("user32\SetThreadDpiAwarenessContext", "ptr", -4, "ptr")   ; DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
    }

    ; The layout of a window. The window g must be created with -DPIScale (see the file comment).
    static Create(g, width, height) {
        this.EnableDpi()
        lay := Map("g", g, "items", [], "w", width, "h", height, "dpi", 96, "font", 0)
        ; WM_DPICHANGED. A Gui has no OnMessage in v2, so the global one is used; it is removed again in Destroy.
        lay["cb"] := (wParam, lParam, msg, hwnd) => GuiLayout.OnDpiChanged(lay, wParam, lParam, hwnd)
        OnMessage(0x02E0, lay["cb"])
        return lay
    }

    ; Registers a control with its place; h is left out for a control whose height is fixed by Windows (drop-down list).
    static Place(lay, ctl, x, y, w, h := "") {
        lay["items"].Push([ctl, x, y, w, h])
        return ctl
    }

    static Scale(lay, n) => Round(n * lay["dpi"] / 96)

    ; The font of the controls (Segoe UI 9 pt at the DPI dpi). The caller deletes it.
    static MakeFont(dpi) => DllCall("gdi32\CreateFontW", "int", -Round(9 * dpi / 72), "int", 0, "int", 0, "int", 0
        , "int", 400, "uint", 0, "uint", 0, "uint", 0, "uint", 1, "uint", 0, "uint", 0, "uint", 5, "uint", 0
        , "str", "Segoe UI", "ptr")

    ; The height at 100 % of a text shown in a Text control of the width (at 100 %) of the Gui g. The text is wrapped at
    ; the width the way a Text control wraps it (DrawText with the font of the layout at the DPI of the window), and
    ; every line counts. A height from the number of newlines alone clips a wrapped text to its first line (F-0128).
    ; Measured once when the dialog is built: a later DPI change keeps the height of the first DPI.
    static TextHeight(g, text, width) {
        dpi := DllCall("user32\GetDpiForWindow", "ptr", g.Hwnd, "uint")
        dpi := dpi > 0 ? dpi : 96
        font := this.MakeFont(dpi)
        hdc := DllCall("user32\GetDC", "ptr", g.Hwnd, "ptr")
        old := DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", font, "ptr")
        rc := Buffer(16, 0)
        NumPut("int", Round(width * dpi / 96), rc, 8)   ; right edge of the text area; left and top are 0
        ; DT_CALCRECT (0x400) | DT_WORDBREAK (0x10) | DT_NOPREFIX (0x800); DrawText takes CR LF as the line end. The control
        ; must not interpret "&" either: the Text control of a dialog has SS_NOPREFIX ("+0x80", UiDialogs).
        lines := StrReplace(StrReplace(text, "`r`n", "`n"), "`n", "`r`n")
        ; with DT_CALCRECT the result is the height of the text (the rectangle is not changed)
        px := DllCall("user32\DrawTextW", "ptr", hdc, "str", lines, "int", -1, "ptr", rc, "uint", 0xC10, "int")
        DllCall("gdi32\SelectObject", "ptr", hdc, "ptr", old, "ptr")
        DllCall("gdi32\DeleteObject", "ptr", font)
        DllCall("user32\ReleaseDC", "ptr", g.Hwnd, "ptr", hdc)
        return Ceil(px * 96 / dpi)
    }

    ; Moves the controls and sets the font for the DPI dpi (0: the DPI of the window).
    static Apply(lay, dpi := 0) {
        if (dpi <= 0)
            dpi := DllCall("user32\GetDpiForWindow", "ptr", lay["g"].Hwnd, "uint")
        lay["dpi"] := dpi > 0 ? dpi : 96
        oldFont := lay["font"]
        lay["font"] := this.MakeFont(lay["dpi"])
        for it in lay["items"] {
            ctl := it[1]
            if (it[5] = "")
                ctl.Move(this.Scale(lay, it[2]), this.Scale(lay, it[3]), this.Scale(lay, it[4]))
            else
                ctl.Move(this.Scale(lay, it[2]), this.Scale(lay, it[3]), this.Scale(lay, it[4]), this.Scale(lay, it[5]))
            SendMessage(0x30, lay["font"], 1, ctl)   ; WM_SETFONT
        }
        if (oldFont)
            DllCall("gdi32\DeleteObject", "ptr", oldFont)
    }

    ; Scales the layout for the DPI of the window and shows the window with the scaled client size. Without x and y the
    ; window is centered; with x and y (outer position, pixels) it is put there when its top left part is on a monitor,
    ; otherwise it is centered (a remembered position of a disconnected monitor).
    ; The outer size is set by Fit: the size that Show("w.. h..") computes uses the title bar and frame of the DPI that the
    ; process had at its start (too small at 225 % after a start at 100 %, too big the other way round; manual check 3).
    static Show(lay, x := "", y := "") {
        this.Apply(lay)
        g := lay["g"]
        g.Show("Hide Center w" this.Scale(lay, lay["w"]) " h" this.Scale(lay, lay["h"]))
        ; Show computes the outer size itself, so Fit comes after it, and the window is centered again on its old center.
        ; The window stays hidden until it has its final size and position (no flicker). Every later Show of the Gui, even
        ; one without options, sizes the window again with the frame of the start DPI, so the window is shown by Windows.
        g.GetPos(&x0, &y0, &w0, &h0)
        this.Fit(lay)
        g.GetPos(, , &newW, &newH)
        if (x != "" && y != "" && this.OnScreen(x, y))
            g.Move(x, y)
        else
            g.Move(x0 + w0 // 2 - newW // 2, y0 + h0 // 2 - newH // 2)
        DllCall("user32\ShowWindow", "ptr", g.Hwnd, "int", 5)   ; SW_SHOW
        WinActivate(g.Hwnd)
    }

    ; True when the point (x, y) plus 16 pixels lies inside the work area of one monitor (the title bar is reachable).
    static OnScreen(x, y) {
        loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
            if (x + 16 >= l && x + 16 < r && y + 16 >= t && y + 16 < b)
                return true
        }
        return false
    }

    ; Sets the outer size of the window so that its client area is the scaled size of the layout, with the title bar and frame
    ; of the DPI of the layout. x and y are the new position (pass both or none; a position of 0 is a position).
    static Fit(lay, x?, y?) {
        g := lay["g"]
        rc := Buffer(16, 0)
        NumPut("int", this.Scale(lay, lay["w"]), "int", this.Scale(lay, lay["h"]), rc, 8)
        DllCall("user32\AdjustWindowRectExForDpi", "ptr", rc, "uint", WinGetStyle(g.Hwnd), "int", false
            , "uint", WinGetExStyle(g.Hwnd), "uint", lay["dpi"])
        flags := 0x14   ; SWP_NOZORDER | SWP_NOACTIVATE
        if (!IsSet(x))
            flags |= 0x2   ; SWP_NOMOVE
        DllCall("user32\SetWindowPos", "ptr", g.Hwnd, "ptr", 0, "int", x ?? 0, "int", y ?? 0
            , "int", NumGet(rc, 8, "int") - NumGet(rc, 0, "int"), "int", NumGet(rc, 12, "int") - NumGet(rc, 4, "int"), "uint", flags)
    }

    ; WM_DPICHANGED: the new DPI is in the low word of wParam, lParam points to the position that Windows suggests. The window
    ; gets the scaled client size plus the title bar and frame of the new DPI, so that nothing is cut off (returning 0: Windows
    ; does not resize it again). An error here must not end the thread inside the message.
    static OnDpiChanged(lay, wParam, lParam, hwnd) {
        if (hwnd != lay["g"].Hwnd)
            return   ; another window of this thread: not handled, Windows goes on as usual
        try {
            dpi := wParam & 0xFFFF
            this.Apply(lay, dpi)
            this.Fit(lay, NumGet(lParam, 0, "int"), NumGet(lParam, 4, "int"))
        }
        return 0
    }

    ; Removes the message handler and the font. Call it before the window is destroyed; the window itself is not touched.
    static Destroy(lay) {
        OnMessage(0x02E0, lay["cb"], 0)
        if (lay["font"]) {
            DllCall("gdi32\DeleteObject", "ptr", lay["font"])
            lay["font"] := 0
        }
    }
}
