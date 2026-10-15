#Requires AutoHotkey v2.0
; Unit tests for src/core/Log.ahk and src/core/Time.ahk (WI-0003).
#Include lib\Assert.ahk
#Include ..\..\src\core\Log.ahk
#Include ..\..\src\core\Time.ahk

CountingSink(level, source, text, flowId := "") {
    Log.memoryLines.Push(level "|" source "|" text "|" flowId)
}

FailingSink(level, source, text, flowId := "") {
    throw ValueError("sink is broken")
}

ResetLog() {
    Log.Configure("")
    Log.memoryLines := []
    Log.sinkErrors := 0
    Log.lastSinkError := ""
    Log.ring := []
    Log.level := 3
}

CheckNoSinkWritesNothing() {
    ResetLog()
    Log.Write("a0", "engine", "started")
    Assert.Equal(Log.memoryLines.Length, 0)
    Assert.Equal(Log.sinkErrors, 0)
}

CheckSinkReceivesFourArguments() {
    ResetLog()
    Log.Configure(Log.Memory)
    Log.Write("f1", "engine", "step done", "Flow 1")
    Log.Configure("")
    Assert.Equal(Log.memoryLines.Length, 1)
    line := Log.memoryLines[1]
    Assert.Equal(line["level"], "f1")
    Assert.Equal(line["source"], "engine")
    Assert.Equal(line["text"], "step done")
    Assert.Equal(line["flowId"], "Flow 1")
}

CheckFlowIdDefaultsToEmpty() {
    ResetLog()
    Log.Configure(Log.Memory)
    Log.Write("t0", "trigger", "armed")
    Log.Configure("")
    Assert.Equal(Log.memoryLines[1]["flowId"], "")
}

CheckCustomSinkGetsCallArguments() {
    ResetLog()
    Log.Configure(CountingSink)
    Log.Write("a3", "storage", "file written")
    Log.Configure("")
    Assert.Equal(Log.memoryLines[1], "a3|storage|file written|")
}

CheckAllValidLevelsAccepted() {
    ResetLog()
    Log.Configure(Log.Memory)
    for level in ["a0", "a1", "a2", "a3", "f0", "f3", "t0", "t3"]
        Log.Write(level, "x", "y")
    Log.Configure("")
    Assert.Equal(Log.memoryLines.Length, 8)
}

WriteBadLevel() {
    Log.Write("x9", "engine", "bad")
}

WriteEmptyLevel() {
    Log.Write("", "engine", "bad")
}

CheckInvalidLevelThrows() {
    err := Assert.Throws(WriteBadLevel, AhfError)
    Assert.Equal(err.code, "internal")
    Assert.Throws(WriteEmptyLevel, AhfError)
}

CheckFailingSinkDoesNotBreakCaller() {
    ResetLog()
    Log.Configure(FailingSink)
    Log.Write("a0", "engine", "one")
    Log.Write("a0", "engine", "two")
    Log.Configure("")
    Assert.Equal(Log.sinkErrors, 2)
    Assert.Equal(Log.lastSinkError, "ValueError: sink is broken")
}

CheckTimeNeverGoesBackwards() {
    previous := Time.NowMs()
    loop 10000 {
        now := Time.NowMs()
        if (now < previous)
            throw AssertFailed("time went backwards at call " A_Index)
        previous := now
    }
    Assert.True(previous > 0)
}

CheckRingKeepsTheLastEntriesOfEveryLevel() {
    ResetLog()
    loop Log.RING_MAX + 20
        Log.Write("a3", "x", "n" A_Index)
    Assert.Equal(Log.ring.Length, Log.RING_MAX)
    Assert.Equal(Log.Recent()[1]["text"], "n21")
    Assert.Equal(Log.Recent()[Log.RING_MAX]["text"], "n" (Log.RING_MAX + 20))
    last := Log.Recent(3)
    Assert.Equal(last.Length, 3)
    Assert.Equal(last[1]["text"], "n" (Log.RING_MAX + 18))
    Assert.Equal(last[3]["level"], "a3")
    Assert.Equal(last[3]["source"], "x")
}

CheckRingFillsWithoutASink() {
    ResetLog()
    Log.Write("f2", "engine", "no sink", "Flow 1")
    Assert.Equal(Log.Recent().Length, 1)
    Assert.Equal(Log.Recent()[1]["flowId"], "Flow 1")
    Assert.Equal(StrLen(Log.Recent()[1]["ts"]), 14)
}

CheckRecentReturnsCopies() {
    ResetLog()
    Log.Write("a1", "x", "orig")
    Log.Recent()[1]["text"] := "changed"
    Assert.Equal(Log.Recent()[1]["text"], "orig")
}

CheckLevelDecidesWhatReachesTheSinkButNotTheRing() {
    ResetLog()
    Log.Configure(Log.Memory)
    Log.SetLevel(2)
    for level in ["a0", "a1", "a2", "a3", "f3", "t2", "t3"]
        Log.Write(level, "x", level)
    Log.Configure("")
    Log.level := 3
    Assert.Equal(Log.memoryLines.Length, 4)                    ; a0 a1 a2 t2
    Assert.Equal(Log.memoryLines[4]["level"], "t2")
    Assert.Equal(Log.Recent().Length, 7)                       ; the ring has all of them
}

CheckLevelZeroLetsOnlyTheMostImportantPass() {
    ResetLog()
    Log.Configure(Log.Memory)
    Log.SetLevel(0)
    for level in ["a0", "a1", "f0", "f1"]
        Log.Write(level, "x", level)
    Log.Configure("")
    Assert.Equal(Log.memoryLines.Length, 2)
}

ParseBad7() {
    Log.ParseLevel("7")
}

ParseBadText() {
    Log.ParseLevel("high")
}

CheckParseLevel() {
    Assert.Equal(Log.ParseLevel("0"), 0)
    Assert.Equal(Log.ParseLevel("3"), 3)
    Assert.Equal(Log.ParseLevel(2), 2)
    Assert.Equal(Assert.Throws(ParseBad7, AhfError).code, "bad_args")
    Assert.Throws(ParseBadText, AhfError)
}

TestRun.Init()

TestRun.Case("without a sink Write does nothing", CheckNoSinkWritesNothing)
TestRun.Case("the sink receives level, source, text and flowId", CheckSinkReceivesFourArguments)
TestRun.Case("flowId defaults to an empty string", CheckFlowIdDefaultsToEmpty)
TestRun.Case("a custom sink function is called with the arguments", CheckCustomSinkGetsCallArguments)
TestRun.Case("all levels a0-a3, f0-f3, t0-t3 are accepted", CheckAllValidLevelsAccepted)
TestRun.Case("an unknown or empty level throws AhfError", CheckInvalidLevelThrows)
TestRun.Case("a failing sink does not break the caller and is counted", CheckFailingSinkDoesNotBreakCaller)
TestRun.Case("Time.NowMs never goes backwards", CheckTimeNeverGoesBackwards)
TestRun.Case("the ring keeps the last 500 entries of every level", CheckRingKeepsTheLastEntriesOfEveryLevel)
TestRun.Case("the ring fills even without a sink", CheckRingFillsWithoutASink)
TestRun.Case("Recent returns copies", CheckRecentReturnsCopies)
TestRun.Case("the level decides what reaches the sink, not what reaches the ring", CheckLevelDecidesWhatReachesTheSinkButNotTheRing)
TestRun.Case("level 0 lets only digit 0 pass", CheckLevelZeroLetsOnlyTheMostImportantPass)
TestRun.Case("ParseLevel accepts 0 to 3 and refuses everything else", CheckParseLevel)

TestRun.Finish()
