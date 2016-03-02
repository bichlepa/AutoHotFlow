#NoEnv
#Include Class_ScrollGUI.ahk
SetBatchLines, -1
 
class instance
{
   static height="nonSenceValue"
}
; ----------------------------------------------------------------------------------------------------------------------
; ChildGUI
MsgBox % "1 " instance.height
Gui, New, +hwndHGUI
Gui, Margin, 20, 20
I := 0
Gui, Add, Text, w370 h20 0x200, % "Edit " . ++I
Gui, Add, Edit, xp y+0 wp r6 vEdit10, 1`n2`n3`n4`n5`n6`n7`n8`n9
Loop, 4 {
   Gui, Add, Text, xp y+0 wp h20 0x200, % "Edit " . ++I
   Gui, Add, Edit, xp y+0 wp r6 vEdit1%A_Index%, 1`n2`n3`n4`n5`n6`n7`n8`n9
}
; Create ScrollGUI1 with vertical scrollbar and scrolling by mouse wheel
MsgBox % "2 " instance.height
Global SG1 := New ScrollGUI(HGUI, 0, 400, "", 2, 4)
MsgBox % "3 " instance.height
; Create the main window (parent)
Gui, Main:New
MsgBox % "4 " instance.height
Gui, Margin, 0, 20
Gui, % SG1.HWND . ": -Caption +ParentMAIN +LastFound"
Gui, % SG1.HWND . ":Show", Hide
WinGetPos, , , W, H,% "ahk_id " SG1.HWND
;~ W := Round(W * (96 / A_ScreenDPI))
;~ H := Round(H * (96 / A_ScreenDPI))
Y := H + 20
WinGetPos, , , Wsettings, Hsettings,% "ahk_id " SG1.HGUI
HParent:=Hsettings+60
;Make resizeable
gui,+minsize%w%x100 ;Ensure contant width.
gui,+maxsize%w%x%HParent%
Gui, Main:Add, Button, vButtonSave x20 y%Y% w100, Save
Gui, Main:Add, Button, vButtonCancel x+20 yp wp, Cancel
Gui, Main:Show, w%W%, Settings
Gui, Main:Show, w%W%, Settings ;Needed twice, otherwise the width is not correct
; Show ScrollGUI1
SG1.Show("", "x0 y0")
MsgBox % "5 " instance.height
Return
; ----------------------------------------------------------------------------------------------------------------------
MainGuiClose:
MainGuiEscape:
MsgBox % "6 " instance.height
ExitApp
 
 