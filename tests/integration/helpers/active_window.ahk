#Requires AutoHotkey v2.0
#SingleInstance Off
; Own window of the hotstring input tests (WI-0131): a Gui without controls, shown and activated, so that the keys typed
; by a test reach it and do nothing there. Args: window title, ready file, stop file. Ends when the stop file exists.
title := A_Args[1]
readyPath := A_Args[2]
stopPath := A_Args[3]

g := Gui("+AlwaysOnTop", title)
g.Show("w320 h120")
FileAppend("ready`n", readyPath, "UTF-8")
SetTimer(CheckStop, 100)

CheckStop() {
    if FileExist(stopPath)
        ExitApp(0)
}
