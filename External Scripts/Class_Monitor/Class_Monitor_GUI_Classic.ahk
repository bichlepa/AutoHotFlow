; ===============================================================================================================================
; Title .........: Class_Monitor_GUI_Classic
; AHK Version ...: 1.1.22.02 x64 Unicode
; Win Version ...: Windows 7 Professional x64 SP1
; Description ...: Monitor GUI Class
; Version .......: v1.01
; Modified ......: 2015.06.01-2027
; Author(s) .....: jNizM
; ===============================================================================================================================
;@Ahk2Exe-SetName Class_Monitor_GUI_Classic
;@Ahk2Exe-SetDescription Class_Monitor_GUI_Classic
;@Ahk2Exe-SetVersion v1.01
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

Display := New Monitor()

; GUI ===========================================================================================================================

Gui, Margin, 5, 5
Gui, Font, s16 w800 q4 c76B900, MS Shell Dlg 2
Gui, Add, Text, xm ym w240 0x201, % "Monitor Configuration"

if (OSVER >= 60)    ; Minimum supported client: Windows Vista
{
    Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
    Gui, Add, GroupBox, xm y+15 w240 h90, % "Display #1"

    Gui, Add, Text, xm+11 yp+27 w60 h22 0x0200, % "Brightness"
    Gui, Add, Edit, x+10 yp w80 h22 0x2002 Limit3 vDB1, % Display.GetMonitorBrightness(1).CurrentBrightness

    Gui, Font, s9 w400 q1 csilver, MS Shell Dlg 2s
    Gui, Add, Text, x+10 yp w60 h22 0x0200, % "(" Display.GetMonitorBrightness(1).MinimumBrightness " - " Display.GetMonitorBrightness(1).MaximumBrightness ")"

    Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
    Gui, Add, Text, xm+11 y+5 w60 h22 0x0200, % "Contrast"
    Gui, Add, Edit, x+10 yp w80 h22 0x2002 Limit3 vDC1, % Display.GetMonitorContrast(1).CurrentContrast
    Gui, Font, s9 w400 q1 csilver, MS Shell Dlg 2s
    Gui, Add, Text, x+10 yp w60 h22 0x0200, % "(" Display.GetMonitorContrast(1).MinimumContrast " - " Display.GetMonitorContrast(1).MaximumContrast ")"

    loop % MOCNT - 1
    {
        sleep 100    ; Prevent empty fields since the functions takes from 0 to 90 milliseconds to return.
        num := A_Index + 1
        Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
        Gui, Add, GroupBox, xm y+25 w240 h90, % "Display #" num

        Gui, Add, Text, xm+11 yp+27 w60 h22 0x0200, % "Brightness"
        Gui, Add, Edit, x+10 yp w80 h22 0x2002 Limit3 vDB%num%, % Display.GetMonitorBrightness(num).CurrentBrightness
        Gui, Font, s9 w400 q1 csilver, MS Shell Dlg 2s
        Gui, Add, Text, x+10 yp w60 h22 0x0200, % "(" Display.GetMonitorBrightness(num).MinimumBrightness " - " Display.GetMonitorBrightness().MaximumBrightness ")"

        Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
        Gui, Add, Text, xm+11 y+5 w60 h22 0x0200, % "Contrast"
        Gui, Add, Edit, x+10 yp w80 h22 0x2002 Limit3 vDC%num%, % Display.GetMonitorContrast(num).CurrentContrast
        Gui, Font, s9 w400 q1 csilver, MS Shell Dlg 2
        Gui, Add, Text, x+10 yp w60 h22 0x0200, % "(" Display.GetMonitorContrast(num).MinimumContrast " - " Display.GetMonitorContrast().MaximumContrast ")"
    }
}
else
{
    Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
    Gui, Add, GroupBox, xm y+15 w240 h90, % "Brightness && Contrast"
    Gui, Add, Text, xm+11 yp+27 w218 r3, % "Please Note:`nThe minimum supported client is Windows Vista"
}

Gui, Font, s9 w400 q1 c000000, MS Shell Dlg 2
Gui, Add, GroupBox, xm y+25 w240 h50

Gui, Add, Text, xm+11 yp+17 w60 h22 0x0200, % "Gamma"
Gui, Add, Edit, x+10 yp w80 h22 0x2002 Limit3 vDG, % Display.GetDeviceGammaRamp()
Gui, Font, s9 w400 q1 csilver, MS Shell Dlg 2
Gui, Add, Text, x+10 yp w60 h22 0x0200, % "(0 - 255)"

Gui, Add, Button, xm y+25 w60 gSetSettings, % "Set"
Gui, Add, Button, x+10 yp w60 gResetSettings, % "Reset"

Gui, Show, AutoSize
return

; UPDATE ========================================================================================================================

SetSettings:
    Gui, Submit, NoHide
    loop % MOCNT
        Display.SetMonitorBrightness(A_Index, DB%A_Index%), Display.SetMonitorContrast(A_Index, DC%A_Index%)
    Display.SetDeviceGammaRamp(DG)
    sleep 100
return

ResetSettings:
    loop % MOCNT
    {
        GuiControl,, DB%A_Index%, % Display.SetMonitorBrightness(A_Index, 50)
        GuiControl,, DC%A_Index%, % Display.SetMonitorContrast(A_Index, 50)
    }
    GuiControl,, DG, % Display.SetDeviceGammaRamp(128)
    sleep 100
return

; EXIT ==========================================================================================================================

GuiClose:
GuiEscape:
    Display.OnExit()
ExitApp

; ===============================================================================================================================