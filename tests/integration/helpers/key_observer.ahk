#Requires AutoHotkey v2.0
#SingleInstance Off
; Key observer of the input tests (WI-0064): logs the key-down events that reach it through the keyboard hook chain
; (a key that a trigger blocks does not reach it; a key with ~ does). Args: log file, ready file, stop file.
logPath := A_Args[1]
readyPath := A_Args[2]
stopPath := A_Args[3]

ih := InputHook("V L0")
ih.KeyOpt("{All}", "N")
ih.NotifyNonText := true      ; unassigned keys produce no text; without this OnKeyDown is not called for them
ih.OnKeyDown := Observed
ih.Start()
FileAppend("ready`n", readyPath, "UTF-8")
SetTimer(CheckStop, 100)

Observed(hook, vk, sc) {
    FileAppend(Format("{:X}", vk) "`n", logPath, "UTF-8")
}

CheckStop() {
    if FileExist(stopPath)
        ExitApp(0)
}
