/*
license info:
{
	"name": "Class_Monitor",
	"author": "jNizM",
	"source": "https://github.com/jNizM/Class_Monitor",
	"license": "The Unlicense",
	"licenselink": "https://unlicense.org/"
}
*/

;By jNizM. License: unlicense.org
;https://github.com/jNizM/Class_Monitor

;Modified by Paul Bichler


global class_monitor:=new Class_Monitor_Class()
Class Class_Monitor_Class                                                                        ; http://msdn.com/library/dd692964(vs.85,en-us)
{
    static FreeSize, FreeArray
    static hDXVA2 := DllCall("LoadLibrary", "Str", "dxva2.dll", "Ptr")

; ===============================================================================================================================

    __New()
    {
        ;~ this.hDXVA2 := DllCall("LoadLibrary", "Str", "dxva2.dll", "Ptr")
          this._DestroyPhysicalMonitor                  := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",  6, "Ptr")
        , this._DestroyPhysicalMonitors                 := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",  7, "Ptr")
        , this._GetMonitorBrightness                    := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr",  9, "Ptr")
        , this._GetMonitorCapabilities                  := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr", 10, "Ptr")
        , this._GetMonitorColorTemperature              := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr", 11, "Ptr")
        , this._GetMonitorContrast                      := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr", 12, "Ptr")
        , this._GetMonitorRedGreenOrBlueDrive           := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr", 15, "Ptr")
        , this._GetMonitorRedGreenOrBlueGain            := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr", 16, "Ptr")
        , this._GetNumberOfPhysicalMonitorsFromHMONITOR := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr", 18, "Ptr")
        , this._GetPhysicalMonitorsFromHMONITOR         := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr", 20, "Ptr")
        , this._RestoreMonitorFactoryColorDefaults      := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr", 26, "Ptr")
        , this._RestoreMonitorFactoryDefaults           := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr", 27, "Ptr")
        , this._SetMonitorBrightness                    := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr", 30, "Ptr")
        , this._SetMonitorColorTemperature              := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr", 31, "Ptr")
        , this._SetMonitorContrast                      := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr", 32, "Ptr")
        , this._SetMonitorRedGreenOrBlueDrive           := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr", 35, "Ptr")
        , this._SetMonitorRedGreenOrBlueGain            := DllCall("GetProcAddress", "Ptr", this.hDXVA2, "Ptr", 36, "Ptr")
    }

; ===============================================================================================================================

    EnumDisplayMonitors(MonitorNumber)                                            ; http://msdn.com/library/dd162610(vs.85,en-us)
    {
        static MonitorEnumProc := RegisterCallback("Class_Monitor_Class.MonitorEnumProc")
        static Monitors
        static Init := Class_Monitor_Class.EnumDisplayMonitors("")
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
        ;~ d(this)
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum), min := cur := max := ""
        if !(DllCall(this._GetMonitorBrightness, "Ptr", hMonitor, "UInt*", min, "UInt*", cur, "UInt*", max))
            return "*" A_LastError
        GMB := {}, GMB.Minimum := min, GMB.Current := cur, GMB.Maximum := max
        return GMB
    }

; ===============================================================================================================================

    GetMonitorCapabilities(MonNum := 1)                                           ; http://msdn.com/library/dd692940(vs.85,en-us)
    {
        static SUPPORTED_COLOR_TEMPERATURE := { 0: "NONE", 1: "4000K", 2: "5000K", 4: "6500K", 8: "7500K", 16: "8200K", 32: "9300K", 64: "10000K", 128: "11500K" }
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum), MonitorCapabilities := SupportedColorTemperatures := ""
        if !(DllCall(this._GetMonitorCapabilities, "Ptr", hMonitor, "UInt*", MonitorCapabilities, "UInt*", SupportedColorTemperatures))
            return "*" A_LastError
        SCT := Object()
        for k, v in SUPPORTED_COLOR_TEMPERATURE
        {
            if ((SupportedColorTemperatures & k) = k)
                ObjRawSet(SCT, k, v)
        }
        return SCT
    }

; ===============================================================================================================================

    GetMonitorColorTemperature(MonNum := 1)                                       ; http://msdn.com/library/dd692941(vs.85,en-us)
    {
        static COLOR_TEMPERATURE := { 0: "UNKNOWN", 1: "4000K", 2: "5000K", 3: "6500K", 4: "7500K", 5: "8200K", 6: "9300K", 7: "10000K", 8: "11500K" }
        CurColTemp := ""
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum)
        if !(DllCall(this._GetMonitorColorTemperature, "Ptr", hMonitor, "UInt*", CurColTemp))
            return "*" A_LastError
        return COLOR_TEMPERATURE[CurColTemp]
    }

; ===============================================================================================================================

    GetMonitorContrast(MonNum := 1)                                               ; http://msdn.com/library/dd692942(vs.85,en-us)
    {
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum), min := cur := max := ""
        if !(DllCall(this._GetMonitorContrast, "Ptr", hMonitor, "UInt*", min, "UInt*", cur, "UInt*", max))
            return "*" A_LastError
        GMC := {}, GMC.Minimum := min, GMC.Current := cur, GMC.Maximum := max
        return GMC
    }

; ===============================================================================================================================

    GetMonitorRedGreenOrBlueDrive(MonNum := 1, DRIVE_TYPE := 2)                   ; http://msdn.com/library/dd692945(vs.85,en-us)
    {
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum), min := cur := max := ""
        if !(DllCall(this._GetMonitorRedGreenOrBlueDrive, "Ptr", hMonitor, "UInt", DRIVE_TYPE, "UInt*", min, "UInt*", cur, "UInt*", max))
            return "*" A_LastError
        GMRGBD := {}, GMRGBD.Minimum := min, GMRGBD.Current := cur, GMRGBD.Maximum := max
        return GMRGBD
    }

; ===============================================================================================================================

    GetMonitorRedGreenOrBlueGain(MonNum := 1, GAIN_TYPE := 2)                     ; http://msdn.com/library/dd692946(vs.85,en-us)
    {
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum), min := cur := max := ""
        if !(DllCall(this._GetMonitorRedGreenOrBlueGain, "Ptr", hMonitor, "UInt", GAIN_TYPE, "UInt*", min, "UInt*", cur, "UInt*", max))
            return "*" A_LastError
        GMRGBG := {}, GMRGBG.Minimum := min, GMRGBG.Current := cur, GMRGBG.Maximum := max
        return GMRGBG
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

    RestoreMonitorFactoryColorDefaults(MonNum := 1)                               ; http://msdn.com/library/dd692968(vs.85,en-us)
    {
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum)
        if !(DllCall(this._RestoreMonitorFactoryColorDefaults, "Ptr", hMonitor))
            return "*" A_LastError
        return True
    }

; ===============================================================================================================================

    RestoreMonitorFactoryDefaults(MonNum := 1)                                    ; http://msdn.com/library/dd692969(vs.85,en-us)
    {
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum)
        if !(DllCall(this._RestoreMonitorFactoryDefaults, "Ptr", hMonitor))
            return "*" A_LastError
        return True
    }

; ===============================================================================================================================

    SetMonitorBrightness(MonNum := 1, SetNew := 50)                               ; http://msdn.com/library/dd692972(vs.85,en-us)
    {
        SetMin := this.GetMonitorBrightness(MonNum).Minimum
        SetMax := this.GetMonitorBrightness(MonNum).Maximum
        SetNew := (SetNew > SetMax) ? SetMax : (SetNew < SetMin) ? SetMin : SetNew
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
        SetMin := this.GetMonitorContrast(MonNum).Minimum
        SetMax := this.GetMonitorContrast(MonNum).Maximum
        SetNew := (SetNew > SetMax) ? SetMax : (SetNew < SetMin) ? SetMin : SetNew
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum)
        if !(DllCall(this._SetMonitorContrast, "Ptr", hMonitor, "UInt", SetNew))
            return "*" A_LastError
        return SetNew
    }

; ===============================================================================================================================

    SetMonitorRedGreenOrBlueDrive(MonNum := 1, DRIVE_TYPE := 2, SetNew := 50)      ; http://msdn.com/library/dd692977(vs.85,en-us)
    {
        SetMin := this.GetMonitorRedGreenOrBlueDrive(MonNum, DRIVE_TYPE).Minimum
        SetMax := this.GetMonitorRedGreenOrBlueDrive(MonNum, DRIVE_TYPE).Maximum
        SetNew := (SetNew > SetMax) ? SetMax : (SetNew < SetMin) ? SetMin : SetNew
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum)
        if !(DllCall(this._SetMonitorRedGreenOrBlueDrive, "Ptr", hMonitor, "UInt", DRIVE_TYPE, "UInt", SetNew))
            return "*" A_LastError
        return SetNew
    }

; ===============================================================================================================================

    SetMonitorRedGreenOrBlueGain(MonNum := 1, GAIN_TYPE := 2, SetNew := 50)       ; http://msdn.com/library/dd692978(vs.85,en-us)
    {
        SetMin := this.GetMonitorRedGreenOrBlueGain(MonNum, GAIN_TYPE).Minimum
        SetMax := this.GetMonitorRedGreenOrBlueGain(MonNum, GAIN_TYPE).Maximum
        SetNew := (SetNew > SetMax) ? SetMax : (SetNew < SetMin) ? SetMin : SetNew
        hMonitor := this.GetPhysicalMonitorsFromHMONITOR(MonNum)
        if !(DllCall(this._SetMonitorRedGreenOrBlueGain, "Ptr", hMonitor, "UInt", GAIN_TYPE, "UInt", SetNew))
            return "*" A_LastError
        return SetNew
    }

; ===============================================================================================================================

    OnExit()
    {
        this.DestroyPhysicalMonitors(this.FreeSize, this.FreeArray)
        DllCall("FreeLibrary", "Ptr", this.hDXVA2)
    }
    
}