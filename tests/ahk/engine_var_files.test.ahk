#Requires AutoHotkey v2.0
; Unit tests for VarWriter and VarLoader (WI-41): the working copy of the global and static variables and its files
; through storage. A stand-in for the engine records the requests and lets the test answer them (no process, no files).
#Include lib\Assert.ahk
#Include ..\..\src\engine\Engine.ahk

; No timer may run between two lines of a case (the writer arms its own timer); every case calls _Run itself.
Critical("On")

class FakeRes {
    __New(payload) {
        this.payload := payload
    }
}

class FakePeer {
    __New() {
        this.sent := []            ; Map(type, payload, cb, timeoutMs)
        this.refuse := ""          ; when set, Request throws an AhfError with this code
    }

    Request(to, type, payload, cb, timeoutMs := 5000) {
        if (this.refuse != "")
            throw AhfError("refused", this.refuse)
        this.sent.Push(Map("to", to, "type", type, "payload", payload, "cb", cb, "timeoutMs", timeoutMs))
    }

    ; Answers request n (1-based) with the payload.
    Answer(n, payload) {
        this.sent[n]["cb"](FakeRes(payload))
    }
}

class FakeEngine {
    __New() {
        this.peer := FakePeer()
        this.logs := []
        this.errors := []          ; Map(op, path, message)
    }

    _Log(level, source, text) {
        this.logs.Push(level " " text)
    }

    _StorageError(op, path, message) {
        this.errors.Push(Map("op", op, "path", path, "message", message))
    }
}

Failure(code) => Map("ok", false, "error", Map("code", code, "message", "probe"))

NewWriter(engine, store) => VarWriter(engine, store, 0, 4000)

; --- VarWriter ---------------------------------------------------------------------------------------------

CaseManyChangesOfOneVariableAreOneWriteWithTheLatestState() {
    eng := FakeEngine(), store := EngineVars()
    w := NewWriter(eng, store)
    store.Global["a"] := "1"
    w.Touch("global", "", "a")
    store.Global["a"] := "2"
    w.Touch("global", "", "A")           ; same variable, other spelling
    store.Global["a"] := "3"
    w.Touch("global", "", "a")
    Assert.Equal(w.Pending, 1)
    w._Run()
    Assert.Equal(eng.peer.sent.Length, 1)
    req := eng.peer.sent[1]
    Assert.Equal(req["type"], "cmd.storage.var.set")
    Assert.Equal(req["payload"]["content"], "3")
    Assert.Equal(req["payload"]["type"], "normal")
    Assert.Equal(req["payload"]["scope"], "global")
    Assert.Equal(req["timeoutMs"], 4000)
    Assert.Equal(w.Pending, 0)
    Assert.Equal(w.Inflight, 1)
    eng.peer.Answer(1, Map("ok", true))
    Assert.Equal(w.Inflight, 0)
}

CaseAnObjectGoesAsJsonAndAStaticCarriesItsFlow() {
    eng := FakeEngine(), store := EngineVars()
    w := NewWriter(eng, store)
    obj := VarValues.NewMap()
    obj[1] := "x"
    obj[2] := 2.5
    store.Static("Flow 7")["list"] := obj
    store.Static("Flow 7")["number"] := 5
    w.Touch("static", "Flow 7", "list")
    w.Touch("static", "Flow 7", "number")
    w._Run()
    Assert.Equal(eng.peer.sent.Length, 2)
    for req in eng.peer.sent {
        Assert.Equal(req["payload"]["flowId"], "Flow 7")
        Assert.Equal(req["payload"]["scope"], "static")
        if (req["payload"]["name"] = "list") {
            Assert.Equal(req["payload"]["type"], "object")
            Assert.Equal(Json.Parse(req["payload"]["content"]).Length, 2)
        } else {
            Assert.Equal(req["payload"]["type"], "normal")
            Assert.Equal(req["payload"]["content"], "5")
        }
    }
}

CaseAVariableThatIsGoneIsDeleted() {
    eng := FakeEngine(), store := EngineVars()
    w := NewWriter(eng, store)
    store.Global["gone"] := "1"
    w.Touch("global", "", "gone")
    store.Global.Delete("gone")
    w.Touch("global", "", "gone")
    w._Run()
    Assert.Equal(eng.peer.sent.Length, 1)
    Assert.Equal(eng.peer.sent[1]["type"], "cmd.storage.var.delete")
}

CaseASilentStorageIsReportedOnceAndTheWriteIsRetried() {
    eng := FakeEngine(), store := EngineVars()
    w := NewWriter(eng, store)
    store.Global["a"] := "1"
    w.Touch("global", "", "a")
    w._Run()
    eng.peer.Answer(1, Failure("timeout"))
    Assert.Equal(eng.errors.Length, 1)
    Assert.Equal(eng.errors[1]["op"], "var.set")
    Assert.Equal(w.Pending, 1)                       ; marked again
    for key, entry in w._dirty
        entry["due"] := 0                            ; the retry time is over
    w._Run()
    Assert.Equal(eng.peer.sent.Length, 2)
    eng.peer.Answer(2, Failure("peer_gone"))
    Assert.Equal(eng.errors.Length, 1)               ; not reported again
    Assert.Equal(w.Pending, 1)
    for key, entry in w._dirty
        entry["due"] := 0
    w._Run()
    eng.peer.Answer(3, Map("ok", true))
    Assert.Equal(w.Pending, 0)
    Assert.Equal(store.Global["a"], "1")             ; the working copy was never touched
    ; after a success the next failure is reported again
    w.Touch("global", "", "a")
    w._Run()
    eng.peer.Answer(4, Failure("timeout"))
    Assert.Equal(eng.errors.Length, 2)
}

CaseARefusedNameIsReportedAndNotRetried() {
    eng := FakeEngine(), store := EngineVars()
    w := NewWriter(eng, store)
    store.Global["a"] := "1"
    w.Touch("global", "", "a")
    w._Run()
    eng.peer.Answer(1, Failure("bad_payload"))
    Assert.Equal(eng.errors.Length, 1)
    Assert.Equal(w.Pending, 0)
}

CaseAFullSendQueueMarksTheVariableAgain() {
    eng := FakeEngine(), store := EngineVars()
    w := NewWriter(eng, store)
    store.Global["a"] := "1"
    w.Touch("global", "", "a")
    eng.peer.refuse := "busy"
    w._Run()
    Assert.Equal(eng.errors.Length, 1)
    Assert.Equal(w.Pending, 1)
    Assert.Equal(w.Inflight, 0)
}

CaseFlushAllSendsEverythingWithTheDeadlineAndStopsTheWriter() {
    eng := FakeEngine(), store := EngineVars()
    w := VarWriter(eng, store, 60000, 4000)          ; far from due
    store.Global["a"] := "1"
    store.Global["b"] := "2"
    w.Touch("global", "", "a")
    w.Touch("global", "", "b")
    w._Run()
    Assert.Equal(eng.peer.sent.Length, 0)            ; the delay is not over
    Assert.Equal(w.FlushAll(3000), 2)
    Assert.Equal(eng.peer.sent.Length, 2)
    Assert.Equal(eng.peer.sent[1]["timeoutMs"], 3000)
    Assert.Equal(w.Pending, 0)
    w.Touch("global", "", "a")                       ; closed: nothing is marked any more
    Assert.Equal(w.Pending, 0)
    eng.peer.Answer(1, Failure("timeout"))           ; a failure at the end is not retried
    Assert.Equal(w.Pending, 0)
}

CaseVarAccessMarksOnlyGlobalAndStaticChanges() {
    store := EngineVars()
    seen := []
    store.OnChange := (scope, flowId, name) => seen.Push(scope "|" flowId "|" name)
    inst := {Vars: VarValues.NewMap(), HiddenVars: VarValues.NewMap()}
    access := VarAccess(store, "", "", Map("flowId", "F1"))
    access.SetVar("global_x", "1")
    access.SetVar("static_y", "2")
    Assert.Equal(seen.Length, 2)
    Assert.Equal(seen[1], "global||global_x")
    Assert.Equal(seen[2], "static|F1|static_y")
    access.Set(["global_o", "k"], 3)
    Assert.Equal(seen[3], "global||global_o")
    access.DeleteVar("global_o")
    Assert.Equal(seen[4], "global||global_o")
    Assert.Equal(access.DeleteVar("global_missing"), 0)
    Assert.Equal(seen.Length, 4)
}

; A refused assignment must not leave a half-made object behind: the working copy and the file would disagree.
CaseARefusedMemberAssignmentCreatesNothing() {
    store := EngineVars()
    seen := []
    store.OnChange := (scope, flowId, name) => seen.Push(name)
    access := VarAccess(store, "", "", Map("flowId", "F1"))
    refused := false
    try {
        access.Set(["global_o", VarValues.NewMap(), "x"], 3)
    } catch ExprResolveError {
        refused := true
    }
    Assert.True(refused)
    Assert.True(!store.Global.Has("global_o"))
    Assert.Equal(seen.Length, 0)
}

class ThrowingStopper {
    Stop() {
        throw Error("probe: stop failed")
    }
    StopAll(reason) {
        throw Error("probe: stop failed")
    }
}

; The variables are the only thing a shutdown must not lose: a failing step before them may not skip the flush.
CaseShutdownFlushesTheVariablesEvenWhenStoppingTheInstancesFails() {
    eng := FakeEngine(), store := EngineVars()
    w := VarWriter(eng, store, 60000, 4000)
    store.Global["a"] := "1"
    w.Touch("global", "", "a")
    eng.workers := ThrowingStopper()
    eng.executor := ThrowingStopper()
    eng.varWriter := w
    try {
        Engine.Prototype.OnShutdown.Call(eng, 3000)
    }
    Assert.Equal(eng.peer.sent.Length, 1)
}

; --- VarLoader ---------------------------------------------------------------------------------------------

CaseLoaderListsThenReadsTwoAtATimeAndParsesObjects() {
    eng := FakeEngine(), store := EngineVars()
    loader := VarLoader(eng, store)
    state := Map("done", 0, "down", "")
    loader.Run(["F1"], () => state["done"] += 1, (why) => state["down"] := why)
    Assert.Equal(eng.peer.sent.Length, 2)            ; the two lists
    eng.peer.Answer(1, Map("ok", true, "names", ["g1", "g2", "g3"]))
    eng.peer.Answer(2, Map("ok", true, "names", ["s1"]))
    Assert.Equal(eng.peer.sent.Length, 4)            ; two gets in flight, not three
    eng.peer.Answer(3, Map("ok", true, "exists", true, "type", "normal", "content", "007"))
    Assert.Equal(eng.peer.sent.Length, 5)
    eng.peer.Answer(4, Map("ok", true, "exists", true, "type", "object", "content", '{"a":[1,2],"b":{"c":"x"}}'))
    eng.peer.Answer(5, Map("ok", true, "exists", false))
    Assert.Equal(eng.peer.sent.Length, 6)
    eng.peer.Answer(6, Map("ok", true, "exists", true, "type", "normal", "content", "static text"))
    Assert.Equal(state["done"], 1)
    Assert.Equal(store.Global["g1"], "007")
    Assert.Equal(Type(store.Global["g1"]), "String")
    Assert.Equal(store.Global["g2"]["a"][2], 2)
    Assert.Equal(store.Global["g2"]["b"]["c"], "x")
    Assert.True(!store.Global.Has("g3"))
    Assert.Equal(store.Static("F1")["s1"], "static text")
    Assert.Equal(loader.Count, 3)
}

CaseLoaderStopsWhenStorageIsGoneAndContinuesWithWhatIsLeft() {
    eng := FakeEngine(), store := EngineVars()
    loader := VarLoader(eng, store)
    state := Map("done", 0, "down", "")
    loader.Run([], () => state["done"] += 1, (why) => state["down"] := why)
    eng.peer.Answer(1, Map("ok", true, "names", ["a", "b", "c"]))
    Assert.Equal(eng.peer.sent.Length, 3)            ; gets of a and b
    eng.peer.Answer(2, Map("ok", true, "exists", true, "type", "normal", "content", "A"))
    Assert.Equal(eng.peer.sent.Length, 4)            ; get of c
    eng.peer.Answer(3, Failure("peer_gone"))         ; b is lost
    Assert.Equal(state["down"], "")                  ; c is still on its way
    eng.peer.Answer(4, Map("ok", true, "exists", true, "type", "normal", "content", "C"))
    Assert.True(state["down"] != "")
    Assert.Equal(state["done"], 0)
    Assert.Equal(eng.errors.Length, 0)               ; waiting for storage is not an error
    Assert.Equal(eng.peer.sent.Length, 4)            ; nothing else was sent
    loader.Run([], () => state["done"] += 1, (why) => state["down"] := why)
    Assert.Equal(eng.peer.sent.Length, 5)            ; only b again
    Assert.Equal(eng.peer.sent[5]["payload"]["name"], "b")
    eng.peer.Answer(5, Map("ok", true, "exists", true, "type", "normal", "content", "B"))
    Assert.Equal(state["done"], 1)
    Assert.Equal(store.Global["a"] . store.Global["b"] . store.Global["c"], "ABC")
}

CaseLoaderReportsAnUnreadableVariableAndGoesOn() {
    eng := FakeEngine(), store := EngineVars()
    loader := VarLoader(eng, store)
    state := Map("done", 0)
    loader.Run([], () => state["done"] += 1, (why) => 0)
    eng.peer.Answer(1, Map("ok", true, "names", ["bad", "worse", "good"]))
    eng.peer.Answer(2, Failure("internal"))
    eng.peer.Answer(3, Map("ok", true, "exists", true, "type", "object", "content", "{not json"))
    eng.peer.Answer(4, Map("ok", true, "exists", true, "type", "normal", "content", "fine"))
    Assert.Equal(state["done"], 1)
    Assert.Equal(eng.errors.Length, 2)
    Assert.Equal(eng.errors[1]["op"], "var.get")
    Assert.Equal(store.Global["good"], "fine")
    Assert.True(!store.Global.Has("bad"))
}

CaseLoaderKeepsAVariableThatWasSetMeanwhile() {
    eng := FakeEngine(), store := EngineVars()
    loader := VarLoader(eng, store)
    loader.Run([], () => 0, (why) => 0)
    eng.peer.Answer(1, Map("ok", true, "names", ["a"]))
    store.Global["a"] := "newer"
    eng.peer.Answer(2, Map("ok", true, "exists", true, "type", "normal", "content", "older"))
    Assert.Equal(store.Global["a"], "newer")
}

CaseLoaderWithNothingToLoadIsDoneAfterTheLists() {
    eng := FakeEngine(), store := EngineVars()
    loader := VarLoader(eng, store)
    state := Map("done", 0)
    loader.Run(["F1", "F2"], () => state["done"] += 1, (why) => 0)
    Assert.Equal(eng.peer.sent.Length, 2)
    eng.peer.Answer(1, Map("ok", true, "names", []))
    Assert.Equal(eng.peer.sent.Length, 3)
    eng.peer.Answer(2, Map("ok", true, "names", []))
    eng.peer.Answer(3, Map("ok", true, "names", []))
    Assert.Equal(state["done"], 1)
}

TestRun.Init()
TestRun.Case("many changes of one variable are one write with the latest state", CaseManyChangesOfOneVariableAreOneWriteWithTheLatestState)
TestRun.Case("an object goes as JSON and a static carries its flow", CaseAnObjectGoesAsJsonAndAStaticCarriesItsFlow)
TestRun.Case("a variable that is gone is deleted", CaseAVariableThatIsGoneIsDeleted)
TestRun.Case("a silent storage is reported once and the write is retried", CaseASilentStorageIsReportedOnceAndTheWriteIsRetried)
TestRun.Case("a refused name is reported and not retried", CaseARefusedNameIsReportedAndNotRetried)
TestRun.Case("a full send queue marks the variable again", CaseAFullSendQueueMarksTheVariableAgain)
TestRun.Case("FlushAll sends everything with the deadline and stops the writer", CaseFlushAllSendsEverythingWithTheDeadlineAndStopsTheWriter)
TestRun.Case("VarAccess marks only global and static changes", CaseVarAccessMarksOnlyGlobalAndStaticChanges)
TestRun.Case("a refused member assignment creates nothing", CaseARefusedMemberAssignmentCreatesNothing)
TestRun.Case("a shutdown flushes the variables although stopping the instances fails", CaseShutdownFlushesTheVariablesEvenWhenStoppingTheInstancesFails)
TestRun.Case("the loader lists, reads two at a time and parses objects", CaseLoaderListsThenReadsTwoAtATimeAndParsesObjects)
TestRun.Case("the loader stops when storage is gone and continues with what is left", CaseLoaderStopsWhenStorageIsGoneAndContinuesWithWhatIsLeft)
TestRun.Case("the loader reports an unreadable variable and goes on", CaseLoaderReportsAnUnreadableVariableAndGoesOn)
TestRun.Case("the loader keeps a variable that was set meanwhile", CaseLoaderKeepsAVariableThatWasSetMeanwhile)
TestRun.Case("the loader with nothing to load is done after the lists", CaseLoaderWithNothingToLoadIsDoneAfterTheLists)
TestRun.Finish()
