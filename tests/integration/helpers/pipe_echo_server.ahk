#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent
; Pipe server for tests/integration/test_pipe.py (WI-0004).
;   AutoHotkey64.exe pipe_echo_server.ahk <resultFile> <pipeName> [maxBytes=N] [maxFrames=N]
;
; Accepts any number of clients. Per connection:
;   * sends "hello:<hwnd>" on connect; "hello:<hwnd>" from the client sets PeerHwnd (wake-up),
;   * echoes every other frame unchanged,
;   * "ctl:gen:N"        sends test frames 0..N-1 (Kit.GenText) with backpressure,
;   * "ctl:expect:N"     verifies the next N frames against Kit.GenText instead of echoing,
;   * "ctl:flood:S:C"    sends C frames of S bytes in a tight loop, stops when SendFrame fails,
;   * "ctl:farewell"     sends "bye" and closes at once (data must stay readable for the peer),
;   * "ctl:burstend:S:C:T"  sends C frames "<i>|" + S bytes and "last", then ends the connection after its send
;                        queue is written, at most T ms (CloseWhenFlushed, WI-0030); record "drained" {flushed},
;   * "note:<text>"      is not echoed but recorded {type: note, id, text},
;   * "ctl:poke:<id>"    sends "poke" to the client <id> at once; record "poke" {wasOpen, ok} (WI-0030),
;   * "ctl:close"        closes the connection,
;   * "ctl:exit"         ends the process.
; Result file: JSON lines {type: ready|connect|close|verified|gen_done|flood|error, ...}.
#Include ..\..\..\src\core\ipc\PipeListener.ahk
#Include ..\..\..\src\core\ipc\Wake.ahk
#Include PipeTestKit.ahk

class EchoServer {
    static resultPath := ""
    static listener := ""
    static clients := []
    static nextId := 0
    static maxBytes := 0
    static maxFrames := 0
    static genTimerOn := false

    static Start() {
        EchoServer.resultPath := A_Args[1]
        try FileDelete(EchoServer.resultPath)
        opts := Kit.Options(A_Args, 3)
        EchoServer.maxBytes := opts.Has("maxBytes") ? Integer(opts["maxBytes"]) : 0
        EchoServer.maxFrames := opts.Has("maxFrames") ? Integer(opts["maxFrames"]) : 0
        try {
            EchoServer.listener := PipeListener(A_Args[2])
        } catch as e {
            Kit.Record(EchoServer.resultPath, Map("type", "error", "message", e.Message))
            ExitApp(3)
        }
        if (opts.Has("mt"))
            Wake.MaxThreads := Integer(opts["mt"])
        Wake.Install(EchoServer.Pump)
        SetTimer(EchoServer.StatusFn, 1000)
        Kit.Record(EchoServer.resultPath, Map("type", "ready", "hwnd", Wake.Hwnd, "pid", ProcessExist()))
    }

    static Pump := (*) => EchoServer._Pump()
    static StatusFn := (*) => EchoServer._Status()
    static lastStatus := ""

    ; Diagnostics for a stalled exchange: one record per change of the connection state.
    static _Status() {
        text := ""
        for c in EchoServer.clients {
            k := c.conn
            text .= c.id ":" k.IsOpen ":rp=" k._readPending ":wp=" k._writePending ":q=" k.QueuedFrames
                . ":buf=" k._reader.Buffered ":pumping=" k._pumping ";"
        }
        if (text != "" && text != EchoServer.lastStatus)
            Kit.Record(EchoServer.resultPath, Map("type", "status", "text", text))
        EchoServer.lastStatus := text
    }

    static _Pump() {
        loop {
            conn := EchoServer.listener.Accept()
            if (conn = "")
                break
            EchoServer._Add(conn)
        }
        live := []
        for c in EchoServer.clients {
            c.conn.Pump()
            if (c.conn.IsOpen)
                live.Push(c)
        }
        EchoServer.clients := live
    }

    static _Add(conn) {
        EchoServer.nextId += 1
        c := {id: EchoServer.nextId, conn: conn, genTotal: 0, genNext: 0, expectTotal: 0, expectNext: 0, bad: 0}
        if (EchoServer.maxBytes > 0)
            conn.maxQueueBytes := EchoServer.maxBytes
        if (EchoServer.maxFrames > 0)
            conn.maxQueueFrames := EchoServer.maxFrames
        conn.OnFrame := (cn, text) => EchoServer._OnFrame(c, text)
        conn.OnClose := (cn, reason) => Kit.Record(EchoServer.resultPath
            , Map("type", "close", "id", c.id, "reason", reason, "t", Time.NowMs()))
        EchoServer.clients.Push(c)
        Kit.Record(EchoServer.resultPath, Map("type", "connect", "id", c.id, "t", Time.NowMs()))
        conn.SendFrame("hello:" Wake.Hwnd)
    }

    static _OnFrame(c, text) {
        if (c.expectNext < c.expectTotal) {
            if (!(text == Kit.GenText(c.expectNext)))
                c.bad += 1
            c.expectNext += 1
            if (c.expectNext = c.expectTotal)
                Kit.Record(EchoServer.resultPath, Map("type", "verified", "id", c.id
                    , "count", c.expectNext, "bad", c.bad))
            return
        }
        if (SubStr(text, 1, 6) = "hello:") {
            c.conn.PeerHwnd := Integer(SubStr(text, 7))
            return
        }
        if (SubStr(text, 1, 5) = "note:") {
            Kit.Record(EchoServer.resultPath, Map("type", "note", "id", c.id, "text", text))
            return
        }
        if (SubStr(text, 1, 4) != "ctl:") {
            ok := c.conn.SendFrame(text)
            if (StrLen(text) > 1000000)
                Kit.Record(EchoServer.resultPath, Map("type", "echo_big", "chars", StrLen(text), "sendOk", ok ? 1 : 0))
            return
        }
        parts := StrSplit(text, ":")
        switch parts[2] {
            case "gen":
                c.genTotal := Integer(parts[3])
                c.genNext := 0
                if (!EchoServer.genTimerOn) {
                    EchoServer.genTimerOn := true
                    SetTimer(EchoServer._GenTick, 1)
                }
            case "expect":
                c.expectTotal := Integer(parts[3])
                c.expectNext := 0
                c.bad := 0
            case "flood":
                EchoServer._Flood(c, Integer(parts[3]), Integer(parts[4]))
            case "farewell":
                c.conn.SendFrame("bye")
                c.conn.Close()
            case "burstend":
                EchoServer._BurstEnd(c, Integer(parts[3]), Integer(parts[4]), Integer(parts[5]))
            case "poke":
                EchoServer._Poke(Integer(parts[3]))
            case "close":
                c.conn.Close()
            case "exit":
                ExitApp(0)
        }
    }

    static _GenTick := (*) => EchoServer._GenStep()

    static _GenStep() {
        busy := false
        for c in EchoServer.clients {
            if (!c.conn.IsOpen || c.genNext >= c.genTotal)
                continue
            budget := 200
            while (budget > 0 && c.genNext < c.genTotal && c.conn.QueuedBytes < 1048576
                && c.conn.QueuedFrames < 100) {
                if (!c.conn.SendFrame(Kit.GenText(c.genNext)))
                    break
                c.genNext += 1
                budget -= 1
            }
            if (c.genNext >= c.genTotal)
                Kit.Record(EchoServer.resultPath, Map("type", "gen_done", "id", c.id, "sent", c.genNext))
            else
                busy := true
        }
        if (!busy) {
            SetTimer(EchoServer._GenTick, 0)
            EchoServer.genTimerOn := false
        }
    }

    ; Sends count frames "<i>|xxx..." of about size bytes and a frame "last", then ends the connection
    ; (WI-0030, F-0023 cause A). The frames that do not fit into the pipe wait in the send queue.
    static _BurstEnd(c, size, count, timeoutMs) {
        pad := Kit.Repeat("x", size)
        loop count
            c.conn.SendFrame(A_Index "|" pad)
        c.conn.SendFrame("last")
        Kit.Record(EchoServer.resultPath, Map("type", "burstend", "id", c.id, "queuedFrames", c.conn.QueuedFrames))
        start := Time.NowMs()
        c.conn.CloseWhenFlushed(timeoutMs, (flushed) => Kit.Record(EchoServer.resultPath, Map("type", "drained"
            , "id", c.id, "flushed", flushed ? 1 : 0, "elapsedMs", Round(Time.NowMs() - start, 1) + 0)))
    }

    ; Sends "poke" to the client with this id, before its frames are read (WI-0030). Records whether it was open.
    static _Poke(id) {
        for other in EchoServer.clients {
            if (other.id = id) {
                wasOpen := other.conn.IsOpen
                ok := other.conn.SendFrame("poke")
                Kit.Record(EchoServer.resultPath, Map("type", "poke", "id", id, "wasOpen", wasOpen ? 1 : 0
                    , "ok", ok ? 1 : 0))
                return
            }
        }
        Kit.Record(EchoServer.resultPath, Map("type", "poke", "id", id, "wasOpen", 0, "ok", 0))
    }

    static _Flood(c, size, count) {
        text := Kit.Repeat("f", size)
        start := Time.NowMs()
        sent := 0
        failedAt := -1
        loop count {
            if (!c.conn.SendFrame(text)) {
                failedAt := A_Index
                break
            }
            sent += 1
        }
        Kit.Record(EchoServer.resultPath, Map("type", "flood", "id", c.id, "sent", sent
            , "failedAt", failedAt, "elapsedMs", Round(Time.NowMs() - start, 1) + 0, "isOpen", c.conn.IsOpen ? 1 : 0))
    }
}

EchoServer.Start()
