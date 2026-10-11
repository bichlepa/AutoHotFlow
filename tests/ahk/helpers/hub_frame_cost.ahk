#Requires AutoHotkey v2.0
#SingleInstance Off
; Benchmark for WI-24: what does the hub spend on routing one large frame (a res.storage.flow.read with
; the text of a flow file)? Not a unit test. The hub is not started (no pipe): two fake connections stand
; in for storage (sender) and engine (target), the frame goes through Hub._OnFrame exactly as a pipe read
; would deliver it. Only the routing is measured, no I/O.
; A_Args: 1 = result file (one JSON line of type "bench"), 2 = flow file, 3 = repetitions.
#Include ..\..\..\src\supervisor\Hub.ahk

class FakeConn {
    __New() {
        this.sent := 0
        this.lastLength := 0
        this.lastText := ""
        this.PeerHwnd := 0
    }
    SendFrame(text) {
        this.sent += 1
        this.lastLength := StrLen(text)
        this.lastText := text
        return true
    }
    Pump() {
    }
    Close() {
    }
}

resultPath := A_Args[1]
flowPath := A_Args[2]
runs := Integer(A_Args[3])

flowText := FileRead(flowPath, "UTF-8")
theHub := Hub("unused", "bench")
fromConn := FakeConn()
toConn := FakeConn()
for name, conn in Map("storage", fromConn, "engine", toConn) {
    theHub._links[name] := Map("name", name, "conn", conn, "pid", 0, "hwnd", 0, "topics", Map(), "helloAt", 0)
    theHub._byConn[ObjPtr(conn)] := name
}

frame := Message("engine", "storage", "storage#1", "res.storage.flow.read"
    , Map("ok", true, "text", flowText), "engine#1").Serialize()

theHub._OnFrame(fromConn, frame)            ; warm up (first call loads code paths)
total := 0.0
worst := 0.0
loop runs {
    t0 := Time.NowMs()
    theHub._OnFrame(fromConn, frame)
    dt := Time.NowMs() - t0
    total += dt
    worst := Max(worst, dt)
}

; The target must have received a frame that still carries the same payload, sent from "storage".
delivered := toConn.lastText
ok := (toConn.sent = runs + 1) && (StrLen(delivered) = StrLen(frame))
try {
    parsed := Message.Parse(delivered)
    ok := ok && parsed.from = "storage" && parsed.to = "engine" && parsed.payload["text"] == flowText
} catch {
    ok := false
}

FileAppend(Json.Stringify(Map("type", "bench", "frame_chars", StrLen(frame), "runs", runs
    , "mean_ms", Number(Round(total / runs, 3)), "max_ms", Number(Round(worst, 3)), "delivered_ok", ok ? 1 : 0)) "`n"
    , resultPath, "UTF-8-RAW")
