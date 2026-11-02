#Requires AutoHotkey v2.0
#Include ..\..\..\core\ElementError.ahk
#Include ..\..\..\core\Lang.ahk

; Shared code of the screen elements of the package Default (WI-0127): the pixel and image search, the screenshot and the
; screen settings of v1 (Source_Elements/Default/Actions/Get_pixel_color.ahk, Search_pixel.ahk, Search_Image.ahk,
; Screenshot.ahk, Get_Screen_Settings.ahk, Set_Screen_Settings.ahk).
;
; Coordinates: the screen elements make the coordinates of their thread device pixels (EnterPhysical). A thread that is not
; DPI aware gets virtualised coordinates and screen images on a monitor whose scale is above 100 % (not checked on a
; machine with several scales, see the result of WI-0127). The state is set back when the job ends (LeavePhysical).
class ScreenOps {
    ; The parameters of WindowIdent (lib/WindowIdent.ahk, AddIdentificationParameters): left out of EvalParams when the
    ; element does not use a window.
    static WindowIds := ["TitleMatchMode", "Wintitle", "excludeTitle", "winText", "FindHiddenText", "ExcludeText"
        , "ahk_class", "ahk_exe", "ahk_id", "ahk_pid", "FindHiddenWindow"]

    ; The per-monitor DPI awareness (V2) of this thread; returns the previous context for LeavePhysical (0 when the
    ; Windows version has no such call, then nothing changes).
    static EnterPhysical() {
        prev := 0
        try prev := DllCall("user32\SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
        catch
            prev := 0
        return prev
    }

    static LeavePhysical(prev) {
        if (prev)
            try DllCall("user32\SetThreadDpiAwarenessContext", "Ptr", prev, "Ptr")
    }

    ; The search region of a whole screen, a whole window or the client area of the active window, for the coordinate
    ; mode (v1 Screen, Window or Client): [x1, y1, x2, y2] with the right and lower pixel included (the AutoHotkey
    ; search regions). Throws ElementError when no window is active in the window modes.
    static WholeRegion(mode, allScreens) {
        if (mode = "Screen") {
            if (allScreens) {
                x := SysGet(76), y := SysGet(77)
                return [x, y, x + SysGet(78) - 1, y + SysGet(79) - 1]
            }
            return [0, 0, A_ScreenWidth - 1, A_ScreenHeight - 1]
        }
        win := WinExist("A")
        if (!win)
            throw ElementError(Lang("Error! No active window found!"))
        if (mode = "Window") {
            WinGetPos(&x, &y, &w, &h, "ahk_id " win)
            return [0, 0, w - 1, h - 1]
        }
        WinGetClientPos(&x, &y, &w, &h, "ahk_id " win)
        return [0, 0, w - 1, h - 1]
    }

    ; The coordinate mode of the pixel and image functions (v1 CoordMode, Pixel): Screen, Window or Client.
    static SetPixelMode(mode) {
        CoordMode("Pixel", mode)
    }
}
