;By jNizM. License: unlicense.org
;Modified by Paul Bichler

Class Monitor                                                                     ; http://msdn.com/library/dd692964(vs.85,en-us)
{
    static FreeSize, FreeArray
    static hDXVA2 := DllCall("LoadLibrary", "Str", "dxva2.dll", "Ptr")

; ===============================================================================================================================

    __New()
    {
        this._DestroyPhysicalMonitor                  := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",    6, "Ptr")
        this._DestroyPhysicalMonitors                 := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",    7, "Ptr")
        this._GetMonitorBrightness                    := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",    9, "Ptr")
        this._GetMonitorColorTemperature              := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",   11, "Ptr")
        this._GetMonitorContrast                      := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",   12, "Ptr")
        this._GetMonitorRedGreenOrBlueGain            := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",   16, "Ptr")
        this._GetNumberOfPhysicalMonitorsFromHMONITOR := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",   18, "Ptr")
        this._GetPhysicalMonitorsFromHMONITOR         := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",   20, "Ptr")
        this._SetMonitorBrightness                    := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",   30, "Ptr")
        this._SetMonitorColorTemperature              := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",   31, "Ptr")
        this._SetMonitorContrast                      := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",   32, "Ptr")
        this._SetMonitorRedGreenOrBlueGain            := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",   36, "Ptr")
        this.hDC := DllCall("user32.dll\GetDC", "Ptr", 0, "Ptr")
    }

; ===============================================================================================================================

    GetDeviceGammaRamp()                                                          ; http://msdn.com/library/dd316946(vs.85,en-us)
    {
        VarSetCapacity(buf, 1536, 0)
        if !(DllCall("gdi32.dll\GetDeviceGammaRamp", "Ptr", this.hDC, "Ptr", &buf))
            return "*" A_LastError
        return NumGet(buf, 2, "UShort") - 128
    }

; ===============================================================================================================================

    SetDeviceGammaRamp(SetNew := 128)                                             ; http://msdn.com/library/dd372194(vs.85,en-us)
    {
        SetNew := (SetNew > 255) ? 255 : (SetNew < 0) ? 0 : SetNew
        loop % VarSetCapacity(buf, 1536) / 6
            NumPut((N := (SetNew + 128) * (A_Index - 1)) > 65535 ? 65535 : N, buf, 2 * (A_Index - 1), "UShort")
        DllCall("RtlMoveMemory", "Ptr", &buf +  512, "Ptr", &buf, "UPtr", 512, "Ptr")
        DllCall("RtlMoveMemory", "Ptr", &buf + 1024, "Ptr", &buf, "UPtr", 512, "Ptr")
        if !(DllCall("gdi32.dll\SetDeviceGammaRamp", "Ptr", this.hDC, "Ptr", &buf))
            return "*" A_LastError
        return SetNew
    }

; ===============================================================================================================================

    MonitorFromWindow(hWnd := 0, Flags := 0)                                      ; http://msdn.com/library/dd145064(vs.85,en-us)
    {
        return DllCall("user32.dll\MonitorFromWindow", "Ptr", hWnd, "UInt", Flags, "Ptr")
    }

    EnumDisplayMonitors(MonitorNumber)                                            ; http://msdn.com/library/dd162610(vs.85,en-us)
    {
        static MonitorEnumProc := RegisterCallback("Monitor.MonitorEnumProc")
        static Monitors
        static Init := Monitor.EnumDisplayMonitors("")
        if (MonitorNumber = "")
        {
            Monitors := {}
            return DllCall("user32.dll\EnumDisplayMonitors", "Ptr", 0, "Ptr", 0, "Ptr", MonitorEnumProc, "Ptr", &Monitors)
        }
        return Monitors[MonitorNumber]
    }

    MonitorEnumProc(hDC, RECT, lParam)                                            ; http://msdn.com/library/dd145061(vs.85,en-us)
    {
        hMonitor := this
        return Object(lParam).Push(hMonitor)
    }

; ===============================================================================================================================

    DestroyPhysicalMonitor(hMonitor)                                              ; http://msdn.com/library/dd692936(vs.85,en-us)
    {
        if !(DllCall(this._DestroyPhysicalMonitor, "Ptr", hMonitor))
            return "*" A_LastError
        return true
    }

; ===============================================================================================================================

    DestroyPhysicalMonitors(Size, PHYSICAL_MONITOR)                               ; http://msdn.com/library/dd692937(vs.85,en-us)
    {
        if !(DllCall(this._DestroyPhysicalMonitors, "UInt", Size, "Ptr", &PHYSICAL_MONITOR))
            return "*" A_LastError
        return true
    }

; ===============================================================================================================================

    GetMonitorBrightness(MonNum := 1)                                             ; http://msdn.com/library/dd692939(vs.85,en-us)
    {
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum), min := cur := max := ""
        if !(DllCall(this._GetMonitorBrightness, "Ptr", hMonitor, "UInt*", min, "UInt*", cur, "UInt*", max))
            return "*" A_LastError
        GMB := {}, GMB.MinimumBrightness := min, GMB.CurrentBrightness := cur, GMB.MaximumBrightness := max
        return GMB
    }

; ===============================================================================================================================
    
    GetMonitorColorTemperature(MonNum := 1)                                       ; http://msdn.com/library/dd692941(vs.85,en-us)
    {
        static MC_COLOR_TEMPERATURE := ["UNKNOWN", "4000K", "5000K", "6500K", "7500K", "8200K", "9300K", "10000K", "11500K"]
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum)
        if !(DllCall(this._GetMonitorColorTemperature, "Ptr", hMonitor, "UInt*", CurColTemp))
            return "*" A_LastError
        return MC_COLOR_TEMPERATURE[CurColTemp]
    }
    
; ===============================================================================================================================

    GetMonitorContrast(MonNum := 1)                                               ; http://msdn.com/library/dd692942(vs.85,en-us)
    {
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum), min := cur := max := ""
        if !(DllCall(this._GetMonitorContrast, "Ptr", hMonitor, "UInt*", min, "UInt*", cur, "UInt*", max))
            return "*" A_LastError
        GMC := {}, GMC.MinimumContrast := min, GMC.CurrentContrast := cur, GMC.MaximumContrast := max
        return GMC
    }
    
; ===============================================================================================================================

    GetMonitorRGBGain(MonNum := 1, Colour:=0)                                               ; http://msdn.com/library/dd692942(vs.85,en-us)
    {
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum), min := cur := max := ""
        if !(DllCall(this._GetMonitorRedGreenOrBlueGain, "Ptr", hMonitor, "UInt", Colour, "UInt*", min, "UInt*", cur, "UInt*", max))
            return "*" A_LastError
        GMC := {}, GMC.MinimumGain := min, GMC.CurrentGain := cur, GMC.MaximumGain := max
        return GMC
    }

; ===============================================================================================================================

    GetNumberOfPhysicalMonitorsFromHMONITOR(ByRef hMonitor, MonNum := 1)          ; http://msdn.com/library/dd692948(vs.85,en-us)
    {
        hMonitor := this.EnumDisplayMonitors(MonNum), PhysMons := ""
        if !(DllCall(this._GetNumberOfPhysicalMonitorsFromHMONITOR, "Ptr", hMonitor, "UInt*", PhysMons))
            return "*" A_LastError
        return PhysMons
    }

; ===============================================================================================================================

    GetPhysicalMonitorsFromHMONITOR(MonNum := 1)                                  ; http://msdn.com/library/dd692950(vs.85,en-us)
    {
        FreeSize := PhysMons := this.GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, MonNum)
        VarSetCapacity(PHYSICAL_MONITOR, (A_PtrSize + 256) * PhysMons, 0)
        if !(DllCall(this._GetPhysicalMonitorsFromHMONITOR, "Ptr", hMonitor, "UInt", PhysMons, "Ptr", &PHYSICAL_MONITOR))
            return "*" A_LastError
        return FreeArray := NumGet(PHYSICAL_MONITOR, 0, "UPtr")
    }

; ===============================================================================================================================

    SetMonitorBrightness(MonNum := 1, SetNew := 50)                               ; http://msdn.com/library/dd692972(vs.85,en-us)
    {
        SetNew := (SetNew > 100) ? 100 : (SetNew < 0) ? 0 : SetNew
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum)
        if !(DllCall(this._SetMonitorBrightness, "Ptr", hMonitor, "UInt", SetNew))
            return "*" A_LastError
        return SetNew
    }

; ===============================================================================================================================
    
    SetMonitorColorTemperature(MonNum := 1, SetNew := 3)                          ; http://msdn.com/library/dd692973(vs.85,en-us)
    {
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum)
        if !(DllCall(this._SetMonitorColorTemperature, "Ptr", hMonitor, "UInt", SetNew))
            return "*" A_LastError
        return true
    }
    
; ===============================================================================================================================

    SetMonitorContrast(MonNum := 1, SetNew := 50)                                 ; http://msdn.com/library/dd692974(vs.85,en-us)
    {
        SetNew := (SetNew > 100) ? 100 : (SetNew < 0) ? 0 : SetNew
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum)
        if !(DllCall(this._SetMonitorContrast, "Ptr", hMonitor, "UInt", SetNew))
            return "*" A_LastError
        return SetNew
    }

; ===============================================================================================================================

    SetMonitorRGBGain(MonNum := 1, Colour:=1, SetNew := 50)                               ; http://msdn.com/library/dd692972(vs.85,en-us)
    {
        ;~ SetNew := (SetNew > 100) ? 100 : (SetNew < 0) ? 0 : SetNew ;Don't use that because range is very differend depending on monitor
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum)
        if !(DllCall(this._SetMonitorRedGreenOrBlueGain, "Ptr", hMonitor, "UInt", Colour, "UInt", SetNew))
            return "*" A_LastError
        return SetNew
    }

; ===============================================================================================================================

    OnExit()
    {
        this.DestroyPhysicalMonitors(this.FreeSize, this.FreeArray)
        DllCall("user32.dll\ReleaseDC", "Ptr", 0, "Ptr", this.hDC)
        DllCall("FreeLibrary", "Ptr", this.hDXVA2)
    }

; ===============================================================================================================================

}