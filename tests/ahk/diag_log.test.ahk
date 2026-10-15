#Requires AutoHotkey v2.0
; Unit tests for src/supervisor/DiagLog.ahk (WI-0023): the log sink of the supervisor and the ring of the
; unhandled errors of the roles. The hub is a fake that records what is sent.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\supervisor\DiagLog.ahk
#Include ..\..\src\core\Time.ahk

class FakeLogHub {
    __New() {
        this.linked := false
        this.accept := true
        this.sent := []
        this.onSend := ""
    }
    HasLink(name) => this.linked && name = "storage"
    Send(name, type, payload) {
        if (IsObject(this.onSend))
            this.onSend.Call()
        if (!this.accept)
            return false
        this.sent.Push(Map("to", name, "type", type, "payload", payload))
        return true
    }
}

NewDiag(&hub) {
    hub := FakeLogHub()
    Log.Configure("")
    d := DiagLog(hub)
    Log.Configure(d.SinkFn)
    return d
}

CheckQueuedUntilStorageIsThere() {
    d := NewDiag(&hub)
    Log.Write("a1", "children", "started engine")
    Log.Write("a0", "hub", "second")
    Assert.Equal(hub.sent.Length, 0)
    Assert.Equal(d.Stats()["queued"], 2)
    hub.linked := true
    d.Flush()
    Log.Configure("")
    Assert.Equal(hub.sent.Length, 2)
    Assert.Equal(hub.sent[1]["type"], "evt.log.append")
    Assert.Equal(hub.sent[1]["to"], "storage")
    Assert.Equal(hub.sent[1]["payload"]["text"], "started engine")
    Assert.Equal(hub.sent[1]["payload"]["source"], "children")
    Assert.Equal(hub.sent[1]["payload"]["level"], "a1")
    Assert.Equal(hub.sent[2]["payload"]["text"], "second")
    Assert.Equal(d.Stats()["queued"], 0)
}

CheckSentDirectlyWhileConnectedAndInOrder() {
    d := NewDiag(&hub)
    Log.Write("a1", "x", "before")
    hub.linked := true
    Log.Write("a1", "x", "after")      ; the queue is not empty yet: the new entry waits behind the old one
    Assert.Equal(hub.sent.Length, 0)
    d.Flush()
    Log.Write("a1", "x", "live")
    Log.Configure("")
    Assert.Equal(hub.sent.Length, 3)
    Assert.Equal(hub.sent[1]["payload"]["text"], "before")
    Assert.Equal(hub.sent[2]["payload"]["text"], "after")
    Assert.Equal(hub.sent[3]["payload"]["text"], "live")
}

CheckQueueIsBounded() {
    d := NewDiag(&hub)
    loop Role.LOG_QUEUE_MAX + 7
        Log.Write("a1", "x", "n" A_Index)
    Log.Configure("")
    Assert.Equal(d.Stats()["queued"], Role.LOG_QUEUE_MAX)
    Assert.Equal(d.Stats()["dropped"], 7)
    hub.linked := true
    d.Flush()
    Assert.Equal(hub.sent[1]["payload"]["text"], "n8")           ; the oldest seven are gone
}

CheckRefusedEntryStaysQueued() {
    d := NewDiag(&hub)
    hub.linked := true
    hub.accept := false
    Log.Write("a0", "x", "refused")
    Assert.Equal(d.Stats()["queued"], 1)
    hub.accept := true
    d.Flush()
    Log.Configure("")
    Assert.Equal(hub.sent.Length, 1)
}

CheckNoRecursionWhileSending() {
    d := NewDiag(&hub)
    hub.linked := true
    ; a send that itself logs (an error inside the hub) must not log into the sink again
    hub.onSend := () => Log.Write("a0", "hub", "send trouble")
    Log.Write("a1", "x", "one")
    Log.Configure("")
    Assert.Equal(hub.sent.Length, 1)
    Assert.Equal(hub.sent[1]["payload"]["text"], "one")
}

CheckErrorRingKeepsTheLast50AndLogs() {
    d := NewDiag(&hub)
    loop DiagLog.ERROR_RING_MAX + 5
        d.AddError("engine", Map("name", "engine", "errorType", "ValueError", "message", "m" A_Index, "file", "f.ahk"
            , "line", 7, "stack", "s", "mode", "Exit"))
    Log.Configure("")
    errs := d.Errors()
    Assert.Equal(errs.Length, DiagLog.ERROR_RING_MAX)
    Assert.Equal(errs[1]["message"], "m6")
    Assert.Equal(errs[errs.Length]["message"], "m" (DiagLog.ERROR_RING_MAX + 5))
    Assert.Equal(errs[1]["from"], "engine")
    Assert.Equal(errs[1]["line"], 7)
    Assert.Equal(errs[1]["stack"], "s")
}

CheckErrorIsLoggedAtA0WithSourceAndPlace() {
    d := NewDiag(&hub)
    hub.linked := true
    d.AddError("engine", Map("errorType", "TypeError", "message", "bad", "file", "E.ahk", "line", 12, "mode", "Return"))
    Log.Configure("")
    Assert.Equal(hub.sent.Length, 1)
    Assert.Equal(hub.sent[1]["payload"]["level"], "a0")
    Assert.Equal(hub.sent[1]["payload"]["source"], "diag")
    Assert.Equal(hub.sent[1]["payload"]["text"], "unhandled TypeError in engine: bad (E.ahk, line 12, Return)")
}

CheckErrorWithoutLoggingAndWithMissingFields() {
    d := NewDiag(&hub)
    hub.linked := true
    d.AddError("x", Map("message", "only a message"), false)
    d.AddError("x", "not a map", false)
    Log.Configure("")
    Assert.Equal(hub.sent.Length, 0)
    Assert.Equal(d.Errors().Length, 2)
    Assert.Equal(d.Errors()[1]["errorType"], "")
    Assert.Equal(d.Errors()[2]["message"], "not a map")
}

ThrowForPayload() {
    throw ValueError("payload test")
}

CheckErrorPayloadOfARealError() {
    try {
        ThrowForPayload()
    } catch as e {
        p := Role.ErrorPayload("echo:a", e, "Exit")
    }
    Assert.Equal(p["name"], "echo:a")
    Assert.Equal(p["errorType"], "ValueError")
    Assert.Equal(p["message"], "payload test")
    Assert.Equal(p["mode"], "Exit")
    Assert.True(InStr(p["file"], "diag_log.test.ahk"), p["file"])
    Assert.True(p["line"] > 0)
    Assert.True(InStr(p["stack"], "ThrowForPayload"), "stack: " p["stack"])
}

CheckLongStackIsCut() {
    e := Error("x")
    e.Stack := ""
    loop 1000
        e.Stack .= "line of the stack`n"
    p := Role.ErrorPayload("x", e, "Exit")
    Assert.True(StrLen(p["stack"]) <= Role.MAX_STACK_CHARS + 3)
}

CheckErrorLimitIsMoreThan20InTheWindow() {
    r := Role(Map())
    now := Time.NowMs()
    loop Role.ERROR_LIMIT
        r.errorTimes.Push(now)
    Assert.True(!r._TooManyErrors(), "exactly the limit is still fine")
    r.errorTimes.Push(now)
    Assert.True(r._TooManyErrors(), "one more is too many")
}

CheckOldErrorsLeaveTheWindow() {
    r := Role(Map())
    old := Time.NowMs() - Role.ERROR_WINDOW_MS - 1000
    loop Role.ERROR_LIMIT + 10
        r.errorTimes.Push(old)
    Assert.True(!r._TooManyErrors())
    Assert.Equal(r.errorTimes.Length, 0)
}

TestRun.Init()

TestRun.Case("entries wait in the queue until storage is connected, then go out in order", CheckQueuedUntilStorageIsThere)
TestRun.Case("a new entry never overtakes the queue", CheckSentDirectlyWhileConnectedAndInOrder)
TestRun.Case("the queue is bounded and counts what it drops", CheckQueueIsBounded)
TestRun.Case("an entry that the hub refuses stays in the queue", CheckRefusedEntryStaysQueued)
TestRun.Case("a log call inside the send does not recurse into the sink", CheckNoRecursionWhileSending)
TestRun.Case("the error ring keeps the last 50 errors", CheckErrorRingKeepsTheLast50AndLogs)
TestRun.Case("an error is logged at a0 with its source and place", CheckErrorIsLoggedAtA0WithSourceAndPlace)
TestRun.Case("an error without logging or with missing fields is kept", CheckErrorWithoutLoggingAndWithMissingFields)
TestRun.Case("the error payload carries type, message, file, line, stack and mode", CheckErrorPayloadOfARealError)
TestRun.Case("a very long stack is cut", CheckLongStackIsCut)
TestRun.Case("more than 20 errors in the window are too many, 20 are not", CheckErrorLimitIsMoreThan20InTheWindow)
TestRun.Case("errors older than the window do not count", CheckOldErrorsLeaveTheWindow)

TestRun.Finish()
