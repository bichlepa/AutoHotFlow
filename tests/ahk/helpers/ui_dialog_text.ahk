#Requires AutoHotkey v2.0
#SingleInstance Off
; Probe for tests/fault/test_manager_window.py (F-0128): opens the Confirm dialog of UiDialogs with a text that wraps at
; the dialog width (the flow name holds "&"), then prints "dpi=<dpi> static=<px> line=<px> style=<hex> text=<text>":
;   static: the height in pixels of the text control of the dialog;
;   line: the height in pixels of one line at the same DPI (GuiLayout.TextHeight is in 100 % units, scaled here);
;   style: the window style of the text control (SS_NOPREFIX 0x80 is set for a dialog text);
;   text: the text of the control as the dialog holds it.
; The dialog is left open; the probe ends the process itself. Run through tools/ahkrun.py (the dialog guard).
#Include ..\..\..\src\ui_common\UiDialogs.ahk

UiDialogs.Confirm(0, "Delete_flow", "Ask_delete_text", [["yes", "Yes"], ["no", "No"]], (a, b) => 0, "A&B")
Sleep 700
hwnd := WinExist("Delete flow")
if (!hwnd) {
    FileAppend("no window`n", "*")
    ExitApp 2
}
ControlGetPos(&x, &y, &w, &h, "Static1", "ahk_id " hwnd)
dpi := DllCall("user32\GetDpiForWindow", "ptr", hwnd, "uint")
style := ControlGetStyle("Static1", "ahk_id " hwnd)
text := ControlGetText("Static1", "ahk_id " hwnd)
g := Gui("-DPIScale")
line100 := GuiLayout.TextHeight(g, "Ag", 356)
g.Destroy()
FileAppend("dpi=" dpi " static=" h " line=" Round(line100 * dpi / 96) " style=" Format("{:x}", style)
    " text=" text "`n", "*")
ExitApp 0
