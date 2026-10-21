#Requires AutoHotkey v2.0
#Include ..\..\core\Log.ahk

; The window, mouse and pixel source of the assistants (WI-0110): the one place of the assistants that asks the system.
; The tests replace it by a fake with the same methods (tests/ahk/editor_assist.test.ahk). Every coordinate is in the
; coordinate space of the editor thread (per-monitor DPI awareness through GuiLayout.EnableDpi): the mouse and the pixel
; calls read the same space. The coordinate mode is set for one call and restored after it, so no other code of the
; thread sees a changed mode. Errors (a window that vanished, a point off the screen) are thrown to the caller.
class AssistantSource {
    ; The mouse position in the coordinate mode "Screen", "Window" or "Client": Map("x", "y", "hwnd", "ctl"). hwnd is the
    ; top-level window under the mouse (0 when none), ctl the control under it.
    Mouse(mode) {
        old := A_CoordModeMouse
        CoordMode("Mouse", mode)
        try {
            MouseGetPos(&x, &y, &hwnd, &ctl)
        } finally {
            CoordMode("Mouse", old)
        }
        return Map("x", x, "y", y, "hwnd", hwnd, "ctl", ctl)
    }

    ; The colour (0xRRGGBB text) of the pixel at x, y in the coordinate mode. method: "default", "alt" or "slow" (v1 values).
    Color(x, y, mode, method) {
        old := A_CoordModePixel
        CoordMode("Pixel", mode)
        opt := (method = "alt") ? "Alt RGB" : (method = "slow") ? "Slow RGB" : "RGB"
        try {
            return PixelGetColor(x, y, opt)
        } finally {
            CoordMode("Pixel", old)
        }
    }

    ; The handles of the visible top-level windows.
    WindowList() => WinGetList()

    ; Map("id", hwnd, "title", "class", "exe" (process name), "pid", "x", "y", "w", "h") of a window. A window that vanished
    ; gives the empty values it has (logged).
    WindowInfo(hwnd) {
        info := Map("id", hwnd, "title", "", "class", "", "exe", "", "pid", 0, "x", 0, "y", 0, "w", 0, "h", 0)
        if (!WinExist("ahk_id " hwnd))
            return info
        try {
            info["title"] := WinGetTitle("ahk_id " hwnd)
            info["class"] := WinGetClass("ahk_id " hwnd)
            info["exe"] := WinGetProcessName("ahk_id " hwnd)
            info["pid"] := WinGetPID("ahk_id " hwnd)
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            info["x"] := x, info["y"] := y, info["w"] := w, info["h"] := h
        } catch as e {
            Log.Write("a0", "editor", "assistant: the window " hwnd " is gone: " e.Message)
        }
        return info
    }
}
