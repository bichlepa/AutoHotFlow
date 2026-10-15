#Requires AutoHotkey v2.0
; Unit tests for src/core/Ids.ahk (WI-0003).
#Include lib\Assert.ahk
#Include ..\..\src\core\Ids.ahk

NextWithoutConfigure() {
    Ids.processName := ""
    return Ids.Next()
}

ConfigureEmpty() {
    Ids.Configure("")
}

NextNumber(id) {
    return Integer(SubStr(id, InStr(id, "#") + 1))
}

CheckCountsFromOne() {
    Ids.Configure("engine")
    Assert.Equal(Ids.Next(), "engine#1")
    Assert.Equal(Ids.Next(), "engine#2")
}

CheckConfigureResets() {
    Ids.Configure("storage")
    Assert.Equal(Ids.Next(), "storage#1")
}

CheckPrefix() {
    Ids.Configure("editor")
    Assert.Equal(Ids.Next("msg-"), "msg-1")
    Assert.Equal(Ids.Next("msg-"), "msg-2")
    Assert.Equal(Ids.Next(), "editor#3")
}

CheckManyIds() {
    Ids.Configure("worker")
    seen := Map()
    last := 0
    loop 100000 {
        id := Ids.Next()
        if (seen.Has(id))
            throw AssertFailed("duplicate id " id " at call " A_Index)
        seen[id] := true
        n := NextNumber(id)
        if (n != last + 1)
            throw AssertFailed("expected number " (last + 1) " but got " n " at call " A_Index)
        last := n
    }
    Assert.Equal(last, 100000)
}

; F-0014: an interrupting timer must not get the same id as the interrupted call.
; The timer and the main loop both take ids; all ids must be different.
global raceSeen := Map()
global raceDup := ""

RaceTick() {
    global raceSeen, raceDup
    loop 20 {
        id := Ids.Next()
        if (raceSeen.Has(id) && raceDup = "")
            raceDup := id
        raceSeen[id] := true
    }
}

CheckInterruptingTimer() {
    global raceSeen, raceDup
    Ids.Configure("race")
    raceSeen := Map()
    raceDup := ""
    SetTimer(RaceTick, 1)
    stop := A_TickCount + 1500
    while (A_TickCount < stop) {
        id := Ids.Next()
        if (raceSeen.Has(id) && raceDup = "")
            raceDup := id
        raceSeen[id] := true
    }
    SetTimer(RaceTick, 0)
    if (raceDup != "")
        throw AssertFailed("duplicate id " raceDup " after " raceSeen.Count " ids")
}

CheckUnconfigured() {
    err := Assert.Throws(NextWithoutConfigure, AhfError)
    Assert.Equal(err.code, "internal")
}

CheckEmptyName() {
    err := Assert.Throws(ConfigureEmpty, AhfError)
    Assert.Equal(err.code, "internal")
}

TestRun.Init()

TestRun.Case("Next returns processName#n counting from 1", CheckCountsFromOne)
TestRun.Case("Configure resets the counter", CheckConfigureResets)
TestRun.Case("Next with prefix returns prefix followed by n", CheckPrefix)
TestRun.Case("100000 ids are unique and strictly ascending", CheckManyIds)
TestRun.Case("an interrupting timer never gets the same id", CheckInterruptingTimer)
TestRun.Case("Next without Configure throws AhfError with code internal", CheckUnconfigured)
TestRun.Case("Configure rejects an empty process name", CheckEmptyName)

TestRun.Finish()
