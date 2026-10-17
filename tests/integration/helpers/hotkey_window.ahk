#Requires AutoHotkey v2.0
#SingleInstance Off
; Hidden window of the input tests (WI-0064): a Gui that never shows, so it can be found only with hidden detection and
; never becomes the active window. Args: window title, ready file, stop file. Ends when the stop file exists.
title := A_Args[1]
readyPath := A_Args[2]
stopPath := A_Args[3]

g := Gui("+AlwaysOnTop -Caption", title)
g.Show("Hide")
FileAppend("ready`n", readyPath, "UTF-8")
SetTimer(CheckStop, 100)

CheckStop() {
    if FileExist(stopPath)
        ExitApp(0)
}
