#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, StdOut
; The own window of the screen element tests (WI-0127): a red window without caption and border, 200 x 150 device pixels,
; that shows a picture (a 20 x 20 BMP, the test writes it) at 40, 30 of its client area. The test reads the geometry
; from the ready file and searches the screen for the picture; it ends the window by writing the stop file.
;
; Arguments: title, ready file, stop file, picture file.
; The ready file gets one line: the screen position and size of the client area, "x y w h" (device pixels).
#Include ..\..\ahk\lib\Assert.ahk
try DllCall("user32\SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")   ; device pixels, as the screen elements use
title := A_Args[1]
ready := A_Args[2]
stop := A_Args[3]
picture := A_Args[4]
g := Gui("-Caption -Border +AlwaysOnTop -DPIScale", title)
g.BackColor := "FF0000"
g.AddPicture("x40 y30 w20 h20", picture)
g.Show("x300 y200 w200 h150 NoActivate")
WinGetClientPos(&x, &y, &w, &h, "ahk_id " g.Hwnd)
FileAppend(x " " y " " w " " h "`n", ready, "UTF-8")
while (!FileExist(stop))
    Sleep(50)
g.Destroy()
ExitApp()
