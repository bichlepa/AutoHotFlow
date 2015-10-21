; ===============================================================================================================================
; Title .........: Class_Monitor_GUI_Classic
; AHK Version ...: 1.1.22.06 x64 Unicode
; Win Version ...: Windows 7 Professional x64 SP1
; Description ...: Monitor GUI Class
; Version .......: v1.02
; Modified ......: 2015.09.15-1937
; Author(s) .....: jNizM
; ===============================================================================================================================
;@Ahk2Exe-SetName Class_Monitor_GUI_Classic
;@Ahk2Exe-SetDescription Class_Monitor_GUI_Classic
;@Ahk2Exe-SetVersion v1.02
;@Ahk2Exe-SetCopyright Copyright (c) 2015-2015`, jNizM
;@Ahk2Exe-SetOrigFilename Class_Monitor_GUI_Classic.ahk
; ===============================================================================================================================

; GLOBAL SETTINGS ===============================================================================================================

#Warn
#NoEnv
#SingleInstance Force
SetBatchLines -1

#Include Class_Monitor.ahk

global OSVER := ((OSVER := DllCall("GetVersion") & 0xFFFF) & 0xFF) (OSVER >> 8)    ; Get OSVersion (Major- & MinorVerion)
global MOCNT := DllCall("user32.dll\GetSystemMetrics", "Int", 80)                  ; Get the number of display monitors on a desktop.
global SleepDuration := 100                                                        ; Prevent empty fields since the functions takes from 0 to 90 milliseconds to return.
global TabTitle := ""

Display := New Monitor()

loop % MOCNT
{
    if (A_Index > 4)
        break
    i := A_Index, DDList%A_Index% := ""
    TabTitle .= "Display " A_Index "|"
    GMC%A_Index% := Display.GetMonitorCapabilities(A_Index)
    if (GMC%A_Index%.Length() >= 0)
    {
        for key, val in GMC%A_Index%
        {
            if (key != 0)
            {
                if (InStr(Display.GetMonitorColorTemperature(i), val))
                    DDList%i% .= val "||"
                else
                    DDList%i% .= val "|"
            }
        }
    }
}

; GUI ===========================================================================================================================

Gui, Margin, 5, 5
Gui, Font, s16 w800 q4 c76B900, MS Shell Dlg 2
Gui, Add, Text, xm ym w240 0x201, % "Monitor Configuration"

if (OSVER >= 60)    ; Minimum supported client: Windows Vista
{
    Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
    Gui, Add, Tab2, xm y+15 w290 h245 vTab AltSubmit, % TabTitle

    loop % MOCNT
    {
        if (A_Index > 4)
            break
        Gui, Tab, % A_Index

        Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
        Gui, Add, Text, xs+7 y+10 w120 h22 0x0200, % "Brightness"
        Gui, Add, Edit, x+5 yp w80 h22 0x2002 Limit3 vDBR%A_Index%, % Display.GetMonitorBrightness(A_Index).Current
        Gui, Font, s9 w400 q1 csilver, MS Shell Dlg 2
        Gui, Add, Text, x+5 yp w65 h22 0x0200, % "(" Display.GetMonitorBrightness(A_Index).Minimum " - " Display.GetMonitorBrightness(A_Index).Maximum ")"

        Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
        Gui, Add, Text, xs+7 y+5 w120 h22 0x0200, % "Contrast"
        Gui, Add, Edit, x+5 yp w80 h22 0x2002 Limit3 vDCO%A_Index%, % Display.GetMonitorContrast(A_Index).Current
        Gui, Font, s9 w400 q1 csilver, MS Shell Dlg 2
        Gui, Add, Text, x+5 yp w65 h22 0x0200, % "(" Display.GetMonitorContrast(A_Index).Minimum " - " Display.GetMonitorContrast(A_Index).Maximum ")"

        Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
        Gui, Add, Text, xs+7 y+5 w120 h22 0x0200, % "Color Temperature"
        Gui, Add, DropDownList, x+5 yp w80 vDT%A_Index%, % DDList%A_Index%

        Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
        Gui, Add, Text, xs+7 y+5 w120 h22 0x200, % "Red"
        Gui, Add, Edit, x+5 yp w80 h22 0x2002 Limit3 vDRE%A_Index%, % Display.GetMonitorRedGreenOrBlueGain(A_Index, 0).Current
        Gui, Font, s9 w400 q1 csilver, MS Shell Dlg 2
        Gui, Add, Text, x+5 yp w65 h22 0x0200, % "(" Display.GetMonitorRedGreenOrBlueGain(A_Index, 0).Minimum " - " Display.GetMonitorRedGreenOrBlueGain(A_Index, 0).Maximum ")"

        Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
        Gui, Add, Text, xs+7 y+5 w120 h22 0x200, % "Green"
        Gui, Add, Edit, x+5 yp w80 h22 0x2002 Limit3 vDGR%A_Index%, % Display.GetMonitorRedGreenOrBlueGain(A_Index, 1).Current
        Gui, Font, s9 w400 q1 csilver, MS Shell Dlg 2
        Gui, Add, Text, x+5 yp w65 h22 0x0200, % "(" Display.GetMonitorRedGreenOrBlueGain(A_Index, 1).Minimum " - " Display.GetMonitorRedGreenOrBlueGain(A_Index, 1).Maximum ")"

        Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
        Gui, Add, Text, xs+7 y+5 w120 h22 0x200, % "Blue"
        Gui, Add, Edit, x+5 yp w80 h22 0x2002 Limit3 vDBL%A_Index%, % Display.GetMonitorRedGreenOrBlueGain(A_Index, 2).Current
        Gui, Font, s9 w400 q1 csilver, MS Shell Dlg 2
        Gui, Add, Text, x+5 yp w65 h22 0x0200, % "(" Display.GetMonitorRedGreenOrBlueGain(A_Index, 2).Minimum " - " Display.GetMonitorRedGreenOrBlueGain(A_Index, 2).Maximum ")"
        
        Gui, Add, Text, xs+5 y+10 w280 h1 0x10 

        Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
        Gui, Add, Button, xs+7 y+10 w80 gSetSettings, % "Set"
        Gui, Add, Button, x+2 yp w80 gResetSettings, % "Reset"

        sleep % SleepDuration
    }
}
else
{
    Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
    Gui, Add, GroupBox, xm y+15 w240 h90, % "Brightness && Contrast"
    Gui, Add, Text, xm+11 yp+27 w218 r3, % "Please Note:`nThe minimum supported client is Windows Vista"
}

Gui, Show, AutoSize
return

; UPDATE ========================================================================================================================

SetSettings:
    Gui, Submit, NoHide
    GuiControlGet, Index,, Tab
    Display.SetMonitorBrightness(Index, DBR%Index%)
    Display.SetMonitorContrast(Index, DCO%Index%)
    Display.SetMonitorRedGreenOrBlueGain(Index, 0, DRE%Index%)
    Display.SetMonitorRedGreenOrBlueGain(Index, 1, DGR%Index%)
    Display.SetMonitorRedGreenOrBlueGain(Index, 2, DBL%Index%)
    sleep % SleepDuration
    ;goto RefreshSettings
return

ResetSettings:
    GuiControlGet, Index,, Tab
    Display.RestoreMonitorFactoryColorDefaults(Index)
    Display.RestoreMonitorFactoryDefaults(Index)
    sleep % SleepDuration
    goto RefreshSettings
return

RefreshSettings:
    GuiControlGet, Index,, Tab
    GuiControl,, DBR%Index%, % Display.GetMonitorBrightness(Index).Current
    GuiControl,, DCO%Index%, % Display.GetMonitorContrast(Index).Current
    GuiControl,, DRE%Index%, % Display.GetMonitorRedGreenOrBlueGain(Index, 0).Current
    GuiControl,, DGR%Index%, % Display.GetMonitorRedGreenOrBlueGain(Index, 1).Current
    GuiControl,, DBL%Index%, % Display.GetMonitorRedGreenOrBlueGain(Index, 2).Current
    sleep % SleepDuration
return

; EXIT ==========================================================================================================================

GuiClose:
GuiEscape:
    Display.OnExit()
ExitApp

; ===============================================================================================================================