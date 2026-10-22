#Requires AutoHotkey v2.0
#SingleInstance Off
; Own window of the window tests (WI-0125): a visible Gui with a title that the test chooses (unique), two edit controls
; (Edit1 with the text "AHF own text", Edit2 with "second") and a button (Button1). Args: window title, ready file, stop
; file, and "noactivate" to show the window without taking the focus. The window ends with its close (WM_CLOSE) and when
; the stop file exists. It is the only window the window tests act on.
title := A_Args[1]
readyPath := A_Args[2]
stopPath := A_Args[3]
showOption := (A_Args.Length >= 4 && A_Args[4] = "noactivate") ? "NoActivate" : ""

g := Gui(, title)
g.AddEdit("w200 vFirst", "AHF own text")
g.AddEdit("w200 vSecond", "second")
g.AddButton("w200 vOk", "OK")
g.OnEvent("Close", (*) => ExitApp(0))
g.Show(showOption)
FileAppend("ready`n", readyPath, "UTF-8")
SetTimer(CheckStop, 100)

CheckStop() {
    if FileExist(stopPath)
        ExitApp(0)
}
