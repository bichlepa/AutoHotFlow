#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk  ; AhfError (also included by SystemOps.ahk; once per script)

; The DDC/CI settings of a monitor (WI-0127, the v1 class Lib/Class_Monitor on dxva2.dll): brightness, contrast, the
; gains and drives of the red, green and blue channel, and the colour temperature. Only SystemOps.Real calls it (the
; seam of the screen settings, E0103); an element never does.
;
; A call opens the physical monitors of one monitor, makes one DDC/CI call and destroys the physical monitor handles
; again (v1 did not destroy them). The monitor number is the number of MonitorGet (1 is the first monitor); the first
; physical monitor of it is used. A monitor without DDC/CI, or a call that fails, throws AhfError with the Windows error.
;
; Settings: "brightness" and "contrast" (ranged), "gain" and "drive" (ranged, channel 0 red, 1 green, 2 blue) and
; "colorTemperature" (the index of dxva2's MC_COLOR_TEMPERATURE: 1 is 4000 K, 2 5000 K, 3 6500 K, 4 7500 K, 5 8200 K,
; 6 9300 K, 7 10000 K, 8 11500 K). Reads give a Map with current, min and max (the colour temperature only current).
class MonitorDdc {
    ; PHYSICAL_MONITOR: the handle (8 bytes on 64 bit) and a description of 128 characters (256 bytes).
    static PHYSICAL_MONITOR_SIZE := 264

    static Get(monitor, name, channel := 0) {
        buf := "", count := 0
        h := MonitorDdc._Open(monitor, &buf, &count)
        try {
            return MonitorDdc._Read(h, name, channel)
        } finally {
            MonitorDdc._Close(buf, count)
        }
    }

    static Set(monitor, name, value, channel := 0) {
        buf := "", count := 0
        h := MonitorDdc._Open(monitor, &buf, &count)
        try {
            MonitorDdc._Write(h, name, value, channel)
        } finally {
            MonitorDdc._Close(buf, count)
        }
    }

    ; The handle of the first physical monitor of the monitor. buf and count are set for _Close.
    static _Open(monitor, &buf, &count) {
        left := 0, top := 0, right := 0, bottom := 0
        try {
            MonitorGet(monitor, &left, &top, &right, &bottom)
        } catch {
            throw AhfError("monitor " monitor " does not exist", ErrCode.BAD_ARGS)
        }
        ; a point inside the monitor (its top left corner plus one pixel), packed as the POINT structure (x low, y high)
        point := ((top + 1) << 32) | ((left + 1) & 0xFFFFFFFF)
        hMon := DllCall("user32\MonitorFromPoint", "Int64", point, "UInt", 0, "Ptr")
        if (!hMon)
            throw AhfError("monitor " monitor " has no handle", ErrCode.INTERNAL)
        count := 0
        if (!DllCall("dxva2\GetNumberOfPhysicalMonitorsFromHMONITOR", "Ptr", hMon, "UInt*", &count, "Int"))
            throw AhfError("GetNumberOfPhysicalMonitorsFromHMONITOR failed, Windows error " A_LastError, ErrCode.INTERNAL)
        if (count < 1)
            throw AhfError("monitor " monitor " has no physical monitor with DDC/CI", ErrCode.INTERNAL)
        buf := Buffer(MonitorDdc.PHYSICAL_MONITOR_SIZE * count, 0)
        if (!DllCall("dxva2\GetPhysicalMonitorsFromHMONITOR", "Ptr", hMon, "UInt", count, "Ptr", buf, "Int"))
            throw AhfError("GetPhysicalMonitorsFromHMONITOR failed, Windows error " A_LastError, ErrCode.INTERNAL)
        return NumGet(buf, 0, "Ptr")
    }

    static _Close(buf, count) {
        if (count > 0)
            DllCall("dxva2\DestroyPhysicalMonitors", "UInt", count, "Ptr", buf, "Int")
    }

    static _Read(h, name, channel) {
        mn := 0, cur := 0, mx := 0, ok := 0
        switch name {
            case "brightness":
                ok := DllCall("dxva2\GetMonitorBrightness", "Ptr", h, "UInt*", &mn, "UInt*", &cur, "UInt*", &mx, "Int")
            case "contrast":
                ok := DllCall("dxva2\GetMonitorContrast", "Ptr", h, "UInt*", &mn, "UInt*", &cur, "UInt*", &mx, "Int")
            case "gain":
                ok := DllCall("dxva2\GetMonitorRedGreenOrBlueGain", "Ptr", h, "UInt", channel
                    , "UInt*", &mn, "UInt*", &cur, "UInt*", &mx, "Int")
            case "drive":
                ok := DllCall("dxva2\GetMonitorRedGreenOrBlueDrive", "Ptr", h, "UInt", channel
                    , "UInt*", &mn, "UInt*", &cur, "UInt*", &mx, "Int")
            case "colorTemperature":
                ok := DllCall("dxva2\GetMonitorColorTemperature", "Ptr", h, "UInt*", &cur, "Int")
            default:
                throw AhfError("unknown monitor setting '" name "'", ErrCode.BAD_ARGS)
        }
        if (!ok)
            throw AhfError("DDC/CI read failed, Windows error " A_LastError, ErrCode.INTERNAL)
        return Map("current", cur, "min", mn, "max", mx)
    }

    static _Write(h, name, value, channel) {
        ok := 0
        switch name {
            case "brightness":
                ok := DllCall("dxva2\SetMonitorBrightness", "Ptr", h, "UInt", value, "Int")
            case "contrast":
                ok := DllCall("dxva2\SetMonitorContrast", "Ptr", h, "UInt", value, "Int")
            case "gain":
                ok := DllCall("dxva2\SetMonitorRedGreenOrBlueGain", "Ptr", h, "UInt", channel, "UInt", value, "Int")
            case "drive":
                ok := DllCall("dxva2\SetMonitorRedGreenOrBlueDrive", "Ptr", h, "UInt", channel, "UInt", value, "Int")
            case "colorTemperature":
                ok := DllCall("dxva2\SetMonitorColorTemperature", "Ptr", h, "UInt", value, "Int")
            default:
                throw AhfError("unknown monitor setting '" name "'", ErrCode.BAD_ARGS)
        }
        if (!ok)
            throw AhfError("DDC/CI write failed, Windows error " A_LastError, ErrCode.INTERNAL)
    }
}
