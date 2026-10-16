#Requires AutoHotkey v2.0
; Unit tests for the runaway guard (WI-0066, REQ-EXE-170, E0062): src/engine/core/RunawayGuard.ahk (the window, the limits
; of flowSettings, the throttled refusal log) and its use in the Executor with the stand-in owner (helpers/ExecutorKit.ahk).
; The stop of the flow reaches the engine through LimitReached, which the stand-in records. The engine side (triggers
; disabled, saved, still disabled after a restart) is tests/integration/test_runaway.py.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include helpers\ExecutorKit.ahk
#Include ..\..\src\elements\Default\_includes_engine.ahk

; --- the window ----------------------------------------------------------------------------------------------------

WindowCountsWithinSixtySeconds() {
    g := RunawayGuard()
    g.Count("f", 1000)
    g.Count("f", 1500)
    Assert.Equal(g.Count("f", 1999), 3, "three executions in the second 1")
    Assert.Equal(g.Count("f", 60999), 4, "second 1 is still in the window at second 60")
}

WindowForgetsTheOldSeconds() {
    g := RunawayGuard()
    g.Count("f", 1000)
    g.Count("f", 1200)
    Assert.Equal(g.Count("f", 61000), 1, "second 1 is out of the window at second 61")
}

WindowReusesTheBucketOfTheSameIndex() {
    g := RunawayGuard()
    loop 5
        g.Count("f", 1000)
    ; second 61 has the same bucket index as second 1: the old count must not stay in the total
    Assert.Equal(g.Count("f", 61000), 1)
    Assert.Equal(g.Count("f", 61500), 2)
}

WindowIsPerFlow() {
    g := RunawayGuard()
    loop 3
        g.Count("a", 1000)
    Assert.Equal(g.Count("b", 1000), 1, "the count of flow b is its own")
}

WindowLongGapClearsEverything() {
    g := RunawayGuard()
    loop 10
        g.Count("f", 1000 + A_Index)
    Assert.Equal(g.Count("f", 1000000), 1, "after a long gap only the new execution counts")
}

; --- the limits of flowSettings --------------------------------------------------------------------------------------

DefWithSettings(settings) {
    return {Raw: Map("flowSettings", settings)}
}

LimitOfMissingKeyIsTheDefault() {
    Assert.Equal(RunawayGuard.LimitOf(DefWithSettings(Map()), "maxParallelInstances", 100), 100)
    Assert.Equal(RunawayGuard.LimitOf({Raw: Map()}, "maxParallelInstances", 100), 100, "no flowSettings at all")
}

LimitOfDefaultWordIsTheDefault() {
    Assert.Equal(RunawayGuard.LimitOf(DefWithSettings(Map("maxParallelInstances", "default")), "maxParallelInstances", 100), 100)
}

LimitOfWholeNumberIsTaken() {
    Assert.Equal(RunawayGuard.LimitOf(DefWithSettings(Map("maxParallelInstances", 7)), "maxParallelInstances", 100), 7)
    Assert.Equal(RunawayGuard.LimitOf(DefWithSettings(Map("maxParallelInstances", 0)), "maxParallelInstances", 100), 0,
        "0 means no limit")
}

LimitOfOtherValuesAreTheDefault() {
    Assert.Equal(RunawayGuard.LimitOf(DefWithSettings(Map("maxParallelInstances", "many")), "maxParallelInstances", 100), 100)
    Assert.Equal(RunawayGuard.LimitOf(DefWithSettings(Map("maxParallelInstances", -3)), "maxParallelInstances", 100), 100)
}

; --- the refusal log -----------------------------------------------------------------------------------------------

RefusedLogIsThrottled() {
    g := RunawayGuard()
    line := g.Refused("f", "the limit is reached", 1000)
    Assert.True(InStr(line, "1 start refused"), "the first refusal is logged at once: " line)
    Assert.Equal(g.Refused("f", "the limit is reached", 2000), "", "no second line within 10 s")
    Assert.Equal(g.Refused("f", "the limit is reached", 3000), "")
    line := g.Refused("f", "the limit is reached", 11000)
    Assert.True(InStr(line, "3 starts refused"), "the next line tells the number refused since the last one: " line)
}

RefusedLogIsPerFlow() {
    g := RunawayGuard()
    g.Refused("a", "x", 1000)
    Assert.True(g.Refused("b", "x", 1000) != "", "flow b has its own throttle")
}

; --- the Executor --------------------------------------------------------------------------------------------------

; A loop with `passes` passes whose body is Test_Count (two element executions per pass). settings: more keys of flowSettings.
LoopFlowText(passes, settings := "") {
    els := Trig() . ',"L":{"ID":"L","type":"Loop","class":"Loop_SimpleLoop","pars":{"Infinite":0,"repeatCount":'
        . passes . '},"HeightOfVerticalBar":"280"}' . "," . El("B", "ExecKit.Test_Count")
    cons := '"c1":{"ID":"c1","from":"t0","to":"L","toPart":"HEAD","ConnectionType":"normal","type":"Connection"}'
        . ',"c2":{"ID":"c2","from":"L","to":"B","fromPart":"HEAD","ConnectionType":"normal","type":"Connection"}'
        . ',"c3":{"ID":"c3","from":"B","to":"L","toPart":"TAIL","ConnectionType":"normal","type":"Connection"}'
    return '{"name":"f","flowSettings":{"ExecutionPolicy":"default"' settings '},"formatVersion":2,"allElements":{' els
        . '},"allConnections":{' cons '}}'
}

; Drives the owner until the flow is not executing any more (bounded, so a bug fails instead of hanging).
RunToEnd(owner) {
    loop 100000 {
        if (!owner.executor.IsExecuting("f"))
            return
        owner.Drive()
    }
    throw Error("the flow is still executing after 100000 ticks")
}

EndlessLoopIsStoppedAtTheLimit() {
    owner := NewOwner(LoopFlowText(100000, ',"maxExecutionsPerMinute":50'))
    owner.executor.StartFlow(owner.flows.Get("f"))
    RunToEnd(owner)
    Assert.Equal(owner.LastEndReason(), "limit", "the instance ends with reason limit")
    Assert.True(owner.HasProp("limits") && owner.limits.Length = 1, "the engine is told once")
    Assert.Equal(owner.limits[1]["kind"], "executionsPerMinute")
    Assert.Equal(owner.limits[1]["limit"], 50)
    Assert.True(Probe.runs.Length <= 60, "the flow stopped within a few executions over the limit: " Probe.runs.Length)
}

LoopOfTenThousandPassesPassesWithTheDefaults() {
    owner := NewOwner(LoopFlowText(10000))
    owner.executor.StartFlow(owner.flows.Get("f"))
    RunToEnd(owner)
    Assert.Equal(owner.LastEndReason(), "finished", "20,000 executions are under the default limit")
    Assert.True(!owner.HasProp("limits"), "the engine was not told about a limit")
    Assert.Equal(Probe.runs.Length, 10000)
}

ZeroExecutionLimitMeansNoLimit() {
    owner := NewOwner(LoopFlowText(300, ',"maxExecutionsPerMinute":0'))
    owner.executor.StartFlow(owner.flows.Get("f"))
    RunToEnd(owner)
    Assert.Equal(owner.LastEndReason(), "finished")
    Assert.Equal(Probe.runs.Length, 300)
}

ParallelLimitRefusesTheThirdStart() {
    text := FlowText([El("h", "ExecKit.Test_Hold")], [Conn("c1", "t0", "h")], "parallel")
    text := StrReplace(text, '"ExecutionPolicy":"parallel"', '"ExecutionPolicy":"parallel","maxParallelInstances":2')
    owner := NewOwner(text)
    rec := owner.flows.Get("f")
    owner.executor.StartFlow(rec)
    owner.executor.StartFlow(rec)
    owner.Drive()
    err := Assert.Throws(StartCall.Bind(owner, rec), AhfError)
    Assert.Equal(err.code, ErrCode.LIMIT)
    Assert.True(InStr(err.Message, "maxParallelInstances"), "the message names the limit: " err.Message)
    Assert.Equal(Probe.runs.Length, 2, "the refused start did not run")
}

WaitingLimitRefusesTheThirdQueuedStart() {
    text := FlowText([El("h", "ExecKit.Test_Hold")], [Conn("c1", "t0", "h")], "wait")
    text := StrReplace(text, '"ExecutionPolicy":"wait"', '"ExecutionPolicy":"wait","maxWaitingInstances":1')
    owner := NewOwner(text)
    rec := owner.flows.Get("f")
    owner.executor.StartFlow(rec)
    owner.Drive()
    owner.executor.StartFlow(rec)                ; queued: the one waiting instance is the limit
    err := Assert.Throws(StartCall.Bind(owner, rec), AhfError)
    Assert.Equal(err.code, ErrCode.LIMIT)
    Assert.True(InStr(err.Message, "maxWaitingInstances"), "the message names the limit: " err.Message)
    Assert.Equal(Probe.runs.Length, 1)
}

ZeroParallelLimitAllowsEveryStart() {
    text := FlowText([El("h", "ExecKit.Test_Hold")], [Conn("c1", "t0", "h")], "parallel")
    text := StrReplace(text, '"ExecutionPolicy":"parallel"', '"ExecutionPolicy":"parallel","maxParallelInstances":0')
    owner := NewOwner(text)
    rec := owner.flows.Get("f")
    loop 5
        owner.executor.StartFlow(rec)
    owner.Drive()
    Assert.Equal(Probe.runs.Length, 5)
}

RefusedStartsAreLoggedOnce() {
    text := FlowText([El("h", "ExecKit.Test_Hold")], [Conn("c1", "t0", "h")], "parallel")
    text := StrReplace(text, '"ExecutionPolicy":"parallel"', '"ExecutionPolicy":"parallel","maxParallelInstances":1')
    owner := NewOwner(text)
    rec := owner.flows.Get("f")
    owner.executor.StartFlow(rec)
    owner.Drive()
    loop 50
        Assert.Throws(StartCall.Bind(owner, rec), AhfError)
    n := 0
    for line in Log.memoryLines {
        if (line["level"] = "f1" && InStr(line["text"], "refused"))
            n += 1
    }
    Assert.True(n <= 1, "50 refused starts within a second give at most one log line, got " n)
}

StartCall(owner, rec) {
    return owner.executor.StartFlow(rec)
}

TestRun.Init()

TestRun.Case("The window counts the executions of the last 60 seconds", WindowCountsWithinSixtySeconds)
TestRun.Case("The window forgets the seconds older than 60 s", WindowForgetsTheOldSeconds)
TestRun.Case("A bucket reused by a later second does not keep the old count", WindowReusesTheBucketOfTheSameIndex)
TestRun.Case("The window counts per flow", WindowIsPerFlow)
TestRun.Case("A long gap clears the window", WindowLongGapClearsEverything)
TestRun.Case("A missing limit key is the built-in default", LimitOfMissingKeyIsTheDefault)
TestRun.Case("The word default is the built-in default", LimitOfDefaultWordIsTheDefault)
TestRun.Case("A whole number is the limit, 0 means no limit", LimitOfWholeNumberIsTaken)
TestRun.Case("Any other value is the built-in default", LimitOfOtherValuesAreTheDefault)
TestRun.Case("The refusal log is written at most once per 10 s, with the number refused", RefusedLogIsThrottled)
TestRun.Case("The refusal log throttle is per flow", RefusedLogIsPerFlow)
TestRun.Case("An endless loop is stopped at the execution limit with reason limit", EndlessLoopIsStoppedAtTheLimit)
TestRun.Case("A loop over 10,000 passes passes the default limits", LoopOfTenThousandPassesPassesWithTheDefaults)
TestRun.Case("A limit of 0 switches the execution limit off", ZeroExecutionLimitMeansNoLimit)
TestRun.Case("The parallel limit refuses the start over it with code limit", ParallelLimitRefusesTheThirdStart)
TestRun.Case("The waiting limit refuses the queued start over it with code limit", WaitingLimitRefusesTheThirdQueuedStart)
TestRun.Case("A parallel limit of 0 allows every start", ZeroParallelLimitAllowsEveryStart)
TestRun.Case("Refused starts are logged once in a burst", RefusedStartsAreLoggedOnce)

TestRun.Finish()
