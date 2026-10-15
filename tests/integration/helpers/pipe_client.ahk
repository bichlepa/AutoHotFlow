#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent
; Pipe client for tests/integration/test_pipe.py (WI-0004).
;   AutoHotkey64.exe pipe_client.ahk <resultFile> <pipeName> mode=<mode> [n=N] [wake=0|1] [timeout=ms]
;
; Modes:
;   exchange   sends frames 0..n-1 (Kit.GenText) and verifies the n frames it receives the same way
;              (the peer must send the same sequence), then records "done" and exits.
;   cycles     n times: connect, send "ping:<i>", wait for that echo, close. Records the process
;              handle count after 10 cycles and after the last one.
;   hold       connects, records "connected", then idles until the test kills the process.
;   watch      connects, records "connected", records "close" when the peer is gone, exits.
;   pingpong   n round trips of "ping:<i>" with the echo of the peer, records latencies in microseconds.
;              wake=0 does not announce the window handle (neither side posts wake messages).
;   connect_fail  tries to connect to a pipe that does not exist, records error type and elapsed time.
; Result file: JSON lines.
#Include ..\..\..\src\core\ipc\PipeConnection.ahk
#Include ..\..\..\src\core\ipc\Wake.ahk
#Include PipeTestKit.ahk

class Role {
    static resultPath := ""
    static pipeName := ""
    static opts := ""
    static conn := ""
    static n := 0

    ; Timer callbacks: a static method is not a valid SetTimer callback in AHK v2, a function property is.
    static SendStepFn := (*) => Role.SendStep()
    static RunCyclesFn := (*) => Role.RunCycles()
    static CheckDoneFn := (*) => Role.CheckDone()
    static ProgressFn := (*) => Kit.Record(Role.resultPath, Map("type", "progress", "sent", Role.sendNext
        , "received", Role.recvNext, "bad", Role.bad, "queuedFrames", Role.conn.QueuedFrames
        , "queuedBytes", Role.conn.QueuedBytes, "open", Role.conn.IsOpen ? 1 : 0))

    ; exchange state
    static sendNext := 0
    static recvNext := 0
    static bad := 0
    static firstBad := -1

    ; pingpong state
    static wakeOn := true
    static pingNext := 0
    static pingSentAt := 0.0
    static latencies := []

    static Main() {
        Role.resultPath := A_Args[1]
        Role.pipeName := A_Args[2]
        Role.opts := Kit.Options(A_Args, 3)
        try FileDelete(Role.resultPath)
        Role.n := Role.opts.Has("n") ? Integer(Role.opts["n"]) : 0
        Role.wakeOn := !Role.opts.Has("wake") || Role.opts["wake"] != "0"
        mode := Role.opts["mode"]
        if (mode = "connect_fail") {
            Role.ConnectFail()
            return
        }
        if (mode = "cycles") {
            SetTimer(Role.RunCyclesFn, -1)
            return
        }
        Role.conn := PipeConnection.Connect(Role.pipeName, 5000)
        Role.conn.OnFrame := (c, text) => Role.OnFrame(text)
        Role.conn.OnClose := (c, reason) => Role.OnClose(reason)
        if (Role.opts.Has("mt"))
            Wake.MaxThreads := Integer(Role.opts["mt"])
        Wake.Install(() => Role.conn.Pump())
        Kit.Record(Role.resultPath, Map("type", "connected", "hwnd", Wake.Hwnd, "pid", ProcessExist()))
        Role.conn.SendFrame("hello:" (Role.wakeOn ? Wake.Hwnd : 0))
        if (mode = "exchange") {
            SetTimer(Role.SendStepFn, 1)
            SetTimer(Role.ProgressFn, 2000)     ; diagnostics for a stalled exchange
            SetTimer(Role.CheckDoneFn, 20)      ; the send queue drains without a frame arriving
        }
        else if (mode = "pingpong")
            Role.SendPing()
    }

    static ConnectFail() {
        start := Time.NowMs()
        try {
            PipeConnection.Connect(Role.pipeName, Integer(Role.opts["timeout"]))
            Kit.Record(Role.resultPath, Map("type", "error", "error", "none"))
        } catch as e {
            Kit.Record(Role.resultPath, Map("type", "error", "error", Type(e), "code", e.code
                , "elapsedMs", Round(Time.NowMs() - start, 1) + 0))
        }
        ExitApp(0)
    }

    static OnClose(reason) {
        Kit.Record(Role.resultPath, Map("type", "close", "reason", reason, "t", Time.NowMs()))
        ExitApp(0)
    }

    static OnFrame(text) {
        mode := Role.opts["mode"]
        if (SubStr(text, 1, 6) = "hello:") {
            if (Role.wakeOn)
                Role.conn.PeerHwnd := Integer(SubStr(text, 7))
            return
        }
        if (mode = "exchange") {
            if (!(text == Kit.GenText(Role.recvNext))) {
                Role.bad += 1
                if (Role.firstBad < 0)
                    Role.firstBad := Role.recvNext
            }
            Role.recvNext += 1
            Role.CheckDone()
        } else if (mode = "pingpong") {
            Role.latencies.Push(Round((Time.NowMs() - Role.pingSentAt) * 1000))
            if (Role.pingNext >= Role.n)
                Role.FinishPingPong()
            else
                Role.SendPing()
        }
    }

    static SendStep() {
        budget := 100
        while (budget > 0 && Role.sendNext < Role.n && Role.conn.QueuedBytes < 1048576
            && Role.conn.QueuedFrames < 100) {
            Role.conn.SendFrame(Kit.GenText(Role.sendNext))
            Role.sendNext += 1
            budget -= 1
        }
        if (Role.sendNext >= Role.n)
            SetTimer(Role.SendStepFn, 0)
        Role.CheckDone()
    }

    static CheckDone() {
        if (Role.sendNext >= Role.n && Role.recvNext >= Role.n && Role.conn.QueuedFrames = 0) {
            Kit.Record(Role.resultPath, Map("type", "done", "sent", Role.sendNext, "received", Role.recvNext
                , "bad", Role.bad, "firstBad", Role.firstBad))
            ; Closing is safe: bytes already written stay readable for the peer.
            Role.conn.OnClose := ""
            Role.conn.Close()
            ExitApp(0)
        }
    }

    static SendPing() {
        Role.pingNext += 1
        Role.pingSentAt := Time.NowMs()
        Role.conn.SendFrame("ping:" Role.pingNext)
    }

    static FinishPingPong() {
        ; The first round trip includes the server accepting the new connection (no wake message
        ; exists for that yet), so it is reported separately and not part of the statistics.
        first := Role.latencies.RemoveAt(1)
        sorted := ""
        for v in Role.latencies
            sorted .= v "`n"
        sorted := Sort(RTrim(sorted, "`n"), "N")
        values := StrSplit(sorted, "`n")
        count := values.Length
        median := Integer(values[Ceil(count / 2)])
        p99 := Integer(values[Min(count, Ceil(count * 0.99))])
        Kit.Record(Role.resultPath, Map("type", "pingpong", "count", count, "medianUs", median
            , "p99Us", p99, "maxUs", Integer(values[count]), "firstUs", first, "wake", Role.wakeOn ? 1 : 0))
        Role.conn.OnClose := ""
        Role.conn.Close()
        ExitApp(0)
    }

    static RunCycles() {
        handles10 := 0
        loop Role.n {
            i := A_Index
            conn := PipeConnection.Connect(Role.pipeName, 5000)
            got := Map("ok", false)
            conn.OnFrame := (c, text) => (text == "ping:" i) ? got.Set("ok", true) : 0
            conn.SendFrame("hello:0")
            conn.SendFrame("ping:" i)
            deadline := Time.NowMs() + 5000
            while (!got["ok"] && Time.NowMs() < deadline && conn.IsOpen) {
                conn.Pump()
                DllCall("Sleep", "uint", 1)
            }
            if (!got["ok"]) {
                Kit.Record(Role.resultPath, Map("type", "error", "error", "no echo", "cycle", i))
                ExitApp(4)
            }
            conn.Close()
            if (i = 10)
                handles10 := Kit.HandleCount()
        }
        Kit.Record(Role.resultPath, Map("type", "done", "cycles", Role.n, "handlesAfter10", handles10
            , "handlesEnd", Kit.HandleCount()))
        ExitApp(0)
    }
}

Role.Main()
