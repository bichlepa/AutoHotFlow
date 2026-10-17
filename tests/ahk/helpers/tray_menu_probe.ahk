#Requires AutoHotkey v2.0
#SingleInstance Off
; Probe of WI-0072 (doc/MEASUREMENTS.md, doc/howto/gui-and-hotkeys.md): what an open tray menu does to a running
; AutoHotkey process. The driver tools/tray_menu_probe.py opens the tray menu of this script, navigates it, posts
; WM_AHF_WAKE (0x8001) like a peer does, and reads the result file. This script only records; it never blocks.
;   ahkrun.py --timeout 60 tests/ahk/helpers/tray_menu_probe.ahk <mode> <runMs> <outFile> [tray|gui]
;   tray (default): the menu is the tray menu of this script; gui: the menu is the context menu of a ListView of a Gui
;   (the driver posts WM_CONTEXTMENU to it, the ContextMenu event shows the menu).
;   mode: idle    nothing else runs
;         thread  a thread runs a loop of Sleep(20) for runMs - 1500 ms (progress is recorded)
;         load    every wake message costs about 2 ms of work (a busy handler)
; Output: one line per event in <outFile>: "kind wallMs value" (wallMs = GetSystemTimePreciseAsFileTime in ms since 1970,
; the same clock as the driver's time.time()). Kinds: start, tick (100 ms timer), pong (value = latency ms from the
; driver's send time), prog (thread progress), done.

mode := A_Args.Length >= 1 ? A_Args[1] : "idle"
runMs := A_Args.Length >= 2 ? Integer(A_Args[2]) : 15000
outFile := A_Args.Length >= 3 ? A_Args[3] : A_ScriptDir "\tray_menu_probe.txt"
opener := A_Args.Length >= 4 ? A_Args[4] : "tray"

lines := []
WallMs() {
    ft := Buffer(8, 0)
    DllCall("GetSystemTimePreciseAsFileTime", "Ptr", ft)
    return Integer(NumGet(ft, 0, "Int64") / 10000 - 11644473600000)
}

Rec(kind, value := "") {
    global lines
    lines.Push(kind " " WallMs() " " value)
}

OnPong(wParam, lParam, msg, hwnd) {
    global mode
    Rec("pong", WallMs() - wParam)
    if (mode = "load") {
        t := A_TickCount
        while (A_TickCount - t < 2) {
        }
    }
    return 0
}

Tick() {
    Rec("tick")
}

LongThread() {
    global runMs
    end := A_TickCount + runMs - 1500
    n := 0
    while (A_TickCount < end) {
        Sleep(20)
        n += 1
        Rec("prog", n)
    }
    Rec("prog.end", n)
}

Finish() {
    global lines, outFile
    Rec("done")
    text := ""
    for line in lines
        text .= line "`n"
    try FileDelete(outFile)
    FileAppend(text, outFile, "UTF-8")
    ExitApp(0)
}

Rec("start", mode)
OnMessage(0x8001, OnPong)
SetTimer(Tick, 100)
if (mode = "thread")
    SetTimer(LongThread, -500)
; The tray icon of this script is the one the driver right-clicks (no #NoTrayIcon here).
A_TrayMenu.Delete()
A_TrayMenu.Add("Item 1", (*) => 0)
A_TrayMenu.Add("Item 2", (*) => 0)
A_TrayMenu.Add("Item 3", (*) => 0)
if (opener = "gui") {
    g := Gui("+AlwaysOnTop", "probe-gui")
    lv := g.Add("ListView", "w300 h200", ["Col"])
    lv.Add(, "row 1")
    lv.OnEvent("ContextMenu", (ctl, *) => ShowGuiMenu())
    g.Show("w320 h240")
}
ShowGuiMenu() {
    m := Menu()
    m.Add("Item 1", (*) => 0)
    m.Add("Item 2", (*) => 0)
    m.Add("Item 3", (*) => 0)
    m.Show()
}
SetTimer(Finish, -runMs)
