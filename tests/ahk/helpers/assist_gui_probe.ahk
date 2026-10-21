#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, StdOut
; Probe of the window assistant with the real source (WI-0110, tests/fault/test_editor_assist_gui.py): a target window with the
; title "AHF assist target" is shown; the window assistant is opened and follows the mouse. When the assistant has the target
; selected, it takes it (OK), and the probe writes the values to the result file given as the first argument, then ends.
; The probe waits by timers only (no Sleep). After 60 s without a take it writes "timeout=1" and ends.
#Include ..\..\..\src\editor\assist\AssistantValues.ahk
#Include ..\..\..\src\editor\assist\AssistantSource.ahk
#Include ..\..\..\src\editor\assist\WindowAssistant.ahk

global resultPath := A_Args.Length ? A_Args[1] : A_ScriptDir "\assist_probe_result.txt"
global assist := ""
global targetId := 0
global listed := 0
global finished := false

target := Gui("+AlwaysOnTop", "AHF assist target")
target.Add("Text", "w300 h150", "Point at this window.")
target.Show("x200 y200 w320 h200")
targetId := target.Hwnd

assist := WindowAssistant(AssistantSource(), Finish)
assist.Open(true)
listed := assist.hwnds.Length
SetTimer(Watch, 200)
SetTimer(() => Finish(Map("timeout", "1")), -60000)

; Takes the target as soon as the assistant has selected it (the mouse rested on it).
Watch() {
    if (finished)
        return
    if (assist.followed = targetId)
        assist.Take()
}

; The values of the take (or a timeout) go to the result file; then the probe ends.
Finish(values) {
    global finished, listed, resultPath
    if (finished)
        return
    finished := true
    SetTimer(Watch, 0)
    text := "listed=" listed "`n"
    for key, value in values
        text .= key "=" value "`n"
    FileAppend(text, resultPath, "UTF-8")
    ExitApp(0)
}
