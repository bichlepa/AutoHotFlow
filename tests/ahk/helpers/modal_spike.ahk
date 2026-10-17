#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, StdOut
; Spike of WI-0069 (result in doc/howto/gui-and-hotkeys.md): does a standard modal dialog stop the message handling of
; the process? Usage (through tools/ahkrun.py --no-dialog-guard, timeout 60):
;   modal_spike.ahk <FileSelect|DirSelect|MsgBox|none> [holdMs]
; A timer posts WM_AHF_WAKE (0x8001) to the script window every 500 ms and counts the answers (OnMessage), as the
; supervisor's ping does. Another timer ticks every 100 ms and records the longest gap. The dialog is opened at 1 s and
; kept for holdMs; it is closed by this script (WM_CLOSE to the dialogs of this process), or by its own timeout for
; MsgBox. "none" opens no dialog (baseline). The result is one line per measure on stdout.

mode := A_Args.Length >= 1 ? A_Args[1] : "FileSelect"
holdMs := A_Args.Length >= 2 ? Integer(A_Args[2]) : 10000
ownPid := ProcessExist()
sent := 0, pongs := 0, maxLatency := 0
ticks := 0, lastTick := 0, maxGap := 0
dialogOpen := false
pongsAtStart := 0, sentAtStart := 0, ticksAtStart := 0, startTick := 0
pongsAtClose := 0, sentAtClose := 0, ticksAtClose := 0, gapDuring := 0
returned := "not returned", closedClasses := ""

OnMessage(0x8001, OnPong)
SetTimer(Ping, 500)
SetTimer(Tick, 100)
SetTimer(OpenDialog, -1000)
SetTimer(CloseDialog, -(1000 + holdMs))

Ping() {
    global sent
    sent++
    PostMessage(0x8001, A_TickCount, 0, , A_ScriptHwnd)
}

OnPong(wParam, lParam, msg, hwnd) {
    global pongs, maxLatency
    pongs++
    lat := A_TickCount - wParam
    if (lat > maxLatency)
        maxLatency := lat
}

Tick() {
    global ticks, lastTick, maxGap, dialogOpen
    now := A_TickCount
    ticks++
    if (lastTick && dialogOpen && now - lastTick > maxGap)
        maxGap := now - lastTick
    lastTick := now
}

OpenDialog() {
    global mode, dialogOpen, returned, pongsAtStart, sentAtStart, ticksAtStart, maxGap, startTick
    pongsAtStart := pongs, sentAtStart := sent, ticksAtStart := ticks
    maxGap := 0
    startTick := A_TickCount
    if (mode = "none") {
        returned := "none"
        return
    }
    dialogOpen := true
    if (mode = "FileSelect")
        r := FileSelect(, A_ScriptDir, "Spike", "All (*.*)")
    else if (mode = "DirSelect")
        r := DirSelect(A_ScriptDir, , "Spike")
    else
        r := MsgBox("Spike: this box closes itself", "Spike", "T" Round(holdMs / 1000))
    dialogOpen := false
    returned := "returned after " (A_TickCount - startTick) " ms (value: '" r "')"
}

CloseDialog() {
    global ownPid, pongsAtClose, sentAtClose, ticksAtClose, closedClasses, gapDuring, maxGap, mode
    pongsAtClose := pongs, sentAtClose := sent, ticksAtClose := ticks, gapDuring := maxGap
    if (mode = "FileSelect" || mode = "DirSelect") {
        for hwnd in WinGetList("ahk_pid " ownPid) {
            try {
                cls := WinGetClass(hwnd), ttl := WinGetTitle(hwnd)
            } catch {
                continue
            }
            closedClasses .= cls " | " ttl "; "
            if (cls = "#32770")
                PostMessage(0x10, 0, 0, , hwnd)   ; WM_CLOSE: the dialog returns "" (cancel)
        }
    }
    SetTimer(Finish, -1500)
}

Finish() {
    global mode, holdMs, maxLatency, returned, closedClasses
    global pongsAtStart, sentAtStart, ticksAtStart, pongsAtClose, sentAtClose, ticksAtClose, gapDuring
    secs := holdMs / 1000
    FileAppend("mode=" mode " holdS=" secs "`n", "*")
    FileAppend("during: pings=" (sentAtClose - sentAtStart) " answers=" (pongsAtClose - pongsAtStart)
        " ticks=" (ticksAtClose - ticksAtStart) " (expected about " Round(secs * 10) ")`n", "*")
    FileAppend("longest tick gap during the dialog (ms): " gapDuring "`n", "*")
    FileAppend("max answer latency overall (ms): " maxLatency "`n", "*")
    FileAppend("after: " returned "`n", "*")
    FileAppend("windows of this process at close: " closedClasses "`n", "*")
    ExitApp(0)
}
