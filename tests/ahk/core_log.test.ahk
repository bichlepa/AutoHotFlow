#Requires AutoHotkey v2.0
; Unit tests for src/core/Log.ahk and src/core/Time.ahk (WI-03).
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

TestRun.Init()

TestRun.Case("without a sink Write does nothing", CheckNoSinkWritesNothing)
TestRun.Case("the sink receives level, source, text and flowId", CheckSinkReceivesFourArguments)
TestRun.Case("flowId defaults to an empty string", CheckFlowIdDefaultsToEmpty)
TestRun.Case("a custom sink function is called with the arguments", CheckCustomSinkGetsCallArguments)
TestRun.Case("all levels a0-a3, f0-f3, t0-t3 are accepted", CheckAllValidLevelsAccepted)
TestRun.Case("an unknown or empty level throws AhfError", CheckInvalidLevelThrows)
TestRun.Case("a failing sink does not break the caller and is counted", CheckFailingSinkDoesNotBreakCaller)
TestRun.Case("Time.NowMs never goes backwards", CheckTimeNeverGoesBackwards)

TestRun.Finish()
