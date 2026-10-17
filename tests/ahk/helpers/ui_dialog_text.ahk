#Requires AutoHotkey v2.0
#SingleInstance Off
; Probe for tests/fault/test_manager_window.py (F-0128): opens the Confirm dialog of UiDialogs with a text that wraps at
; the dialog width, reads the height of its text control and prints "static=<px> line=<px>" (the height of one line at
; the same DPI, measured with GuiLayout.TextHeight). The dialog is left open; the probe ends the process itself.
; Run through tools/ahkrun.py (the dialog guard). Not a unit test: it needs a desktop.
#Include ..\..\..\src\ui_common\UiDialogs.ahk

UiDialogs.Confirm(0, "Delete_flow", "Ask_delete_text", [["yes", "Yes"], ["no", "No"]], (a, b) => 0, "Flow X")
Sleep 700
hwnd := WinExist("Delete flow")
if (!hwnd) {
    FileAppend("no window`n", "*")
    ExitApp 2
}
ControlGetPos(&x, &y, &w, &h, "Static1", "ahk_id " hwnd)
g := Gui("-DPIScale")
line := GuiLayout.TextHeight(g, "Ag", 356)
g.Destroy()
FileAppend("static=" h " line=" line "`n", "*")
ExitApp 0
