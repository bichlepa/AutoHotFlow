#Requires AutoHotkey v2.0
; Unit tests for src/supervisor/DiagLog.ahk (WI-23): the log sink of the supervisor and the ring of the
; unhandled errors of the roles. The hub is a fake that records what is sent.
#Include lib\Assert.ahk
#Include ..\..\src\supervisor\DiagLog.ahk

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

TestRun.Init()

TestRun.Case("entries wait in the queue until storage is connected, then go out in order", CheckQueuedUntilStorageIsThere)
TestRun.Case("a new entry never overtakes the queue", CheckSentDirectlyWhileConnectedAndInOrder)
TestRun.Case("the queue is bounded and counts what it drops", CheckQueueIsBounded)
TestRun.Case("an entry that the hub refuses stays in the queue", CheckRefusedEntryStaysQueued)
TestRun.Case("a log call inside the send does not recurse into the sink", CheckNoRecursionWhileSending)

TestRun.Finish()
