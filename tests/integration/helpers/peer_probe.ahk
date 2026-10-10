#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent
; Peer probe for tests/integration/test_peer.py (WI-05). Not a test on its own.
;   AutoHotkey64.exe peer_probe.ahk <resultFile> <hubPipe> name=<peer> mode=serve|ask
;                    [hubHwnd=<n>] [target=<name>] [steps=a,b,...] [n=<count>]
;
; serve: answers cmd.echo (returns the payload) and cmd.boom (throws), records every evt.* it
;        receives, subscribes to topic "news", and records ready/closed transitions.
; ask:   runs the steps against target (default "srv"), each started by the previous answer:
;        echo, boom, unknown, event, timeout, hang, loop (n sequential cmd.echo requests).
;        timeout sends to "silent" (a Python peer that does not answer) with 300 ms.
;        hang sends to "silent" with 8000 ms and waits for the connection to end.
;
; Result file: JSON lines written by Kit.Record. Record types: started, ready, closed, event,
; sent, answer, after_timeout, loop, done, error.
#Include ..\..\..\src\core\ipc\Peer.ahk
#Include PipeTestKit.ahk

class Role {
    static resultPath := ""
    static peer := ""
    static opts := ""
    static mode := ""
    static target := "srv"
    static steps := []
    static stepIndex := 0
    static connectStart := 0
    static cbCount := 0
    static requestStart := 0
    static loopTotal := 0
    static loopDone := 0
    static loopBad := 0
    static loopStart := 0
    static loopHandlesStart := 0
    static loopHandlesMid := 0

    static Main() {
        Role.resultPath := A_Args[1]
        try FileDelete(Role.resultPath)
        Role.opts := Kit.Options(A_Args, 3)
        Role.mode := Role.opts["mode"]
        name := Role.opts["name"]
        hwnd := Role.opts.Has("hubHwnd") ? Integer(Role.opts["hubHwnd"]) : 0
        Role.target := Role.opts.Has("target") ? Role.opts["target"] : "srv"
        Role.loopTotal := Role.opts.Has("n") ? Integer(Role.opts["n"]) : 0
        Role.peer := Peer(name, A_Args[2], Map("hubHwnd", hwnd))
        Role.peer.OnReady := () => Role.OnReady()
        Role.peer.OnClosed := () => Role.OnClosed()
        if (Role.mode = "serve") {
            Role.peer.On("cmd.echo", (msg) => Map("echo", msg.payload))
            Role.peer.On("cmd.boom", (msg) => Role.Boom(msg))
            Role.peer.On("evt.", (msg) => Role.OnEvent(msg))
            Role.peer.Subscribe("news")
        } else {
            Role.steps := StrSplit(Role.opts["steps"], ",")
        }
        Kit.Record(Role.resultPath, Map("type", "started", "name", name, "mode", Role.mode, "hwnd", Wake.Hwnd
            , "pid", DllCall("GetCurrentProcessId", "uint")))
        Role.connectStart := Time.NowMs()
        Role.peer.Connect()
    }

    ; --- lifecycle ---------------------------------------------------------------------------

    static OnReady() {
        Kit.Record(Role.resultPath, Map("type", "ready", "name", Role.peer.name, "status", Role.peer.status
            , "elapsedMs", Round(Time.NowMs() - Role.connectStart, 1) + 0))
        if (Role.mode = "ask" && Role.stepIndex = 0)
            Role.NextStep()
    }

    static OnClosed() {
        Kit.Record(Role.resultPath, Map("type", "closed", "name", Role.peer.name, "reason", Role.peer.closeReason))
    }

    ; --- serve mode --------------------------------------------------------------------------

    static Boom(msg) {
        throw AhfError("probe boom", ErrCode.BUSY)
    }

    static OnEvent(msg) {
        Kit.Record(Role.resultPath, Map("type", "event", "msgType", msg.type, "from", msg.from, "to", msg.to
            , "payload", msg.payload))
    }

    ; --- ask mode ----------------------------------------------------------------------------

    static NextStep() {
        Role.stepIndex += 1
        if (Role.stepIndex > Role.steps.Length) {
            Role.Finish()
            return
        }
        name := Role.steps[Role.stepIndex]
        Kit.Record(Role.resultPath, Map("type", "step", "name", name))
        if (name = "echo")
            Role.StepRequest("echo", "cmd.echo", Map("x", 1))
        else if (name = "boom")
            Role.StepRequest("boom", "cmd.boom", Map())
        else if (name = "unknown")
            Role.StepRequest("unknown", "cmd.nothing", Map())
        else if (name = "event")
            Role.StepEvent()
        else if (name = "timeout")
            Role.StepTimeout()
        else if (name = "hang")
            Role.StepHang()
        else if (name = "loop")
            Role.StepLoop()
        else {
            Kit.Record(Role.resultPath, Map("type", "error", "message", "unknown step " name))
            ExitApp(3)
        }
    }

    static StepRequest(label, msgType, payload) {
        id := Role.peer.Request(Role.target, msgType, payload, (res) => Role.OnAnswer(label, res), 5000)
        Kit.Record(Role.resultPath, Map("type", "sent", "step", label, "id", id))
    }

    static OnAnswer(label, res) {
        Kit.Record(Role.resultPath, Map("type", "answer", "step", label, "msgType", res.type, "corr", res.corr
            , "from", res.from, "payload", res.payload))
        Role.NextStep()
    }

    static StepEvent() {
        id := Role.peer.Send(Role.target, "evt.test.hello", Map("n", 7))
        Kit.Record(Role.resultPath, Map("type", "sent", "step", "event", "id", id))
        Role.NextStep()
    }

    static StepTimeout() {
        Role.cbCount := 0
        Role.requestStart := Time.NowMs()
        id := Role.peer.Request("silent", "cmd.wait", Map(), (res) => Role.OnTimeoutAnswer(res), 300)
        Kit.Record(Role.resultPath, Map("type", "sent", "step", "timeout", "id", id))
    }

    static OnTimeoutAnswer(res) {
        Role.cbCount += 1
        Kit.Record(Role.resultPath, Map("type", "answer", "step", "timeout", "count", Role.cbCount
            , "elapsedMs", Round(Time.NowMs() - Role.requestStart, 1) + 0, "msgType", res.type
            , "payload", res.payload))
        if (Role.cbCount = 1)
            SetTimer(() => Role.AfterTimeout(), -800)
    }

    static AfterTimeout() {
        Kit.Record(Role.resultPath, Map("type", "after_timeout", "count", Role.cbCount
            , "lateReplies", Role.peer.lateReplies, "pending", Role.peer.PendingCount))
        Role.NextStep()
    }

    static StepHang() {
        Role.requestStart := Time.NowMs()
        id := Role.peer.Request("silent", "cmd.wait", Map(), (res) => Role.OnHangAnswer(res), 8000)
        Kit.Record(Role.resultPath, Map("type", "sent", "step", "hang", "id", id))
    }

    static OnHangAnswer(res) {
        Kit.Record(Role.resultPath, Map("type", "answer", "step", "hang", "count", 1
            , "elapsedMs", Round(Time.NowMs() - Role.requestStart, 1) + 0, "msgType", res.type
            , "payload", res.payload))
    }

    static StepLoop() {
        Role.loopDone := 0
        Role.loopBad := 0
        Role.loopStart := Time.NowMs()
        Role.loopHandlesStart := Kit.HandleCount()
        Role.LoopNext()
    }

    static LoopNext() {
        if (Role.loopDone >= Role.loopTotal) {
            Kit.Record(Role.resultPath, Map("type", "loop", "n", Role.loopDone, "bad", Role.loopBad
                , "elapsedMs", Round(Time.NowMs() - Role.loopStart, 1) + 0, "pending", Role.peer.PendingCount
                , "handlesStart", Role.loopHandlesStart, "handlesMid", Role.loopHandlesMid
                , "handlesEnd", Kit.HandleCount()))
            Role.NextStep()
            return
        }
        Role.loopDone += 1
        if (Role.loopDone = 1000)
            Role.loopHandlesMid := Kit.HandleCount()
        Role.peer.Request(Role.target, "cmd.echo", Map("i", Role.loopDone), (res) => Role.LoopAnswer(res), 5000)
    }

    static LoopAnswer(res) {
        echo := res.payload.Get("echo", Map())
        if (!res.payload.Get("ok", false) || echo.Get("i", -1) != Role.loopDone)
            Role.loopBad += 1
        Role.LoopNext()
    }

    static Finish() {
        Kit.Record(Role.resultPath, Map("type", "done", "steps", Role.steps.Length))
        Role.peer.Close()
        ExitApp(0)
    }
}

Role.Main()
