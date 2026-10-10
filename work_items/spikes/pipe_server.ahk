#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent
; Spike: named pipe server (byte mode, overlapped) + wake via PostMessage.
pipeName := StrReplace("//./pipe/ahf_spike", "/", "\")
WM_WAKE := 0x8001
h := DllCall("CreateNamedPipeW", "str", pipeName, "uint", 0x40000003 ; DUPLEX|OVERLAPPED
    , "uint", 0, "uint", 1, "uint", 65536, "uint", 65536, "uint", 0, "ptr", 0, "ptr")
if (h = -1)
    ExitApp(2)
ov := Buffer(32, 0)
ev := DllCall("CreateEventW", "ptr", 0, "int", 1, "int", 0, "ptr", 0, "ptr")
NumPut("ptr", ev, ov, 2*A_PtrSize + 8)  ; hEvent offset (Internal, InternalHigh, Offset/OffsetHigh union, hEvent)
connected := false
FileAppend(A_ScriptHwnd, A_ScriptDir "/hwnd.txt")
DllCall("ConnectNamedPipe", "ptr", h, "ptr", ov)
buf := Buffer(65536)
OnMessage(WM_WAKE, Wake)
SetTimer(Poll, 250)  ; fallback poll
pendingRead := false
Poll() {
    global
    if !connected {
        if DllCall("WaitForSingleObject", "ptr", ev, "uint", 0) = 0 {
            connected := true
            StartRead()
        }
        return
    }
    Drain()
}
Wake(*) {
    global
    if connected
        Drain()
    else
        Poll()
}
StartRead() {
    global
    DllCall("ResetEvent", "ptr", ev)
    pendingRead := true
    ok := DllCall("ReadFile", "ptr", h, "ptr", buf, "uint", 65536, "uint*", &n := 0, "ptr", ov)
}
Drain() {
    global
    if !pendingRead
        return
    if DllCall("GetOverlappedResult", "ptr", h, "ptr", ov, "uint*", &n := 0, "int", 0) {
        pendingRead := false
        s := StrGet(buf, n, "UTF-8")
        reply := "echo:" s
        sz := StrPut(reply, "UTF-8") - 1
        wb := Buffer(sz)
        StrPut(reply, wb, "UTF-8")
        wov := Buffer(32, 0)
        DllCall("WriteFile", "ptr", h, "ptr", wb, "uint", sz, "uint*", &w := 0, "ptr", wov)
        DllCall("GetOverlappedResult", "ptr", h, "ptr", wov, "uint*", &w, "int", 1)
        StartRead()
    }
}
