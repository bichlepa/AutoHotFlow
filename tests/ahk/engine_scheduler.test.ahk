#Requires AutoHotkey v2.0
; Unit tests for src/engine/core/Scheduler.ahk (WI-0008, ARCHITECTURE 5.2, v1 Execution Task.ahk 98-170).
#Include lib\Assert.ahk
#Include ..\..\src\engine\core\Scheduler.ahk
#Include ..\..\src\engine\core\FlowDefinition.ahk

SavedFlowsDir() {
    return A_ScriptDir "\..\data\flows\v1_examples"
}

ReadText(path) {
    text := FileRead(path, "UTF-8")
    if (SubStr(text, 1, 1) = Chr(0xFEFF))
        text := SubStr(text, 2)
    return text
}

Lines(parts*) {
    out := ""
    for i, p in parts
        out .= ((i > 1) ? "`n" : "") p
    return out
}

; New thread IDs "t2", "t3", ... for one test. The counter lives in the closure, not in a global.
MakeIds() {
    counter := Map("n", 1)
    return () => NextId(counter)
}

NextId(counter) {
    counter["n"] += 1
    return "t" counter["n"]
}

; Element IDs in the handmade flows below: trigger "t0", actions "a", "b", "c", loop "L".

; trigger t0 -> a -> b
LinearFlow() {
    return FlowDefinition.FromText("linear", Lines(
        '{"allElements":{',
        '"t0":{"ID":"t0","type":"trigger","class":"trigger_Manual","pars":{}},',
        '"a":{"ID":"a","type":"action","class":"action_Sleep","pars":{}},',
        '"b":{"ID":"b","type":"action","class":"action_Do_nothing","pars":{}}},',
        '"allConnections":{',
        '"c1":{"ID":"c1","from":"t0","to":"a","type":"Connection","ConnectionType":"normal"},',
        '"c2":{"ID":"c2","from":"a","to":"b","type":"Connection","ConnectionType":"normal"}}}'))
}

; trigger t0 -> condition a, a Yes -> b, a No -> c
YesNoFlow() {
    return FlowDefinition.FromText("yesno", Lines(
        '{"allElements":{',
        '"t0":{"ID":"t0","type":"trigger","class":"trigger_Manual","pars":{}},',
        '"a":{"ID":"a","type":"Condition","class":"condition_Debug","pars":{}},',
        '"b":{"ID":"b","type":"action","class":"action_Do_nothing","pars":{}},',
        '"c":{"ID":"c","type":"action","class":"action_Do_nothing","pars":{}}},',
        '"allConnections":{',
        '"c1":{"ID":"c1","from":"t0","to":"a","type":"Connection","ConnectionType":"normal"},',
        '"c2":{"ID":"c2","from":"a","to":"b","type":"Connection","ConnectionType":"Yes"},',
        '"c3":{"ID":"c3","from":"a","to":"c","type":"Connection","ConnectionType":"No"}}}'))
}

; trigger t0 -> a, and a has two normal connections, to b and to c
TwoConnectionsFlow() {
    return FlowDefinition.FromText("two", Lines(
        '{"allElements":{',
        '"t0":{"ID":"t0","type":"trigger","class":"trigger_Manual","pars":{}},',
        '"a":{"ID":"a","type":"action","class":"action_Sleep","pars":{}},',
        '"b":{"ID":"b","type":"action","class":"action_Do_nothing","pars":{}},',
        '"c":{"ID":"c","type":"action","class":"action_Do_nothing","pars":{}}},',
        '"allConnections":{',
        '"c1":{"ID":"c1","from":"t0","to":"a","type":"Connection","ConnectionType":"normal"},',
        '"c2":{"ID":"c2","from":"a","to":"b","type":"Connection","ConnectionType":"normal"},',
        '"c3":{"ID":"c3","from":"a","to":"c","type":"Connection","ConnectionType":"normal"}}}'))
}

; trigger t0 -> L (entry HEAD). L HEAD -> B, B -> L (entry TAIL), L TAIL -> X.
; L "Exception" -> X as well. The loop element is "L" (type loop).
LoopFlow() {
    return FlowDefinition.FromText("loop", Lines(
        '{"allElements":{',
        '"t0":{"ID":"t0","type":"trigger","class":"trigger_Manual","pars":{}},',
        '"L":{"ID":"L","type":"loop","class":"Loop_SimpleLoop","pars":{}},',
        '"B":{"ID":"B","type":"action","class":"action_Do_nothing","pars":{}},',
        '"X":{"ID":"X","type":"action","class":"action_Do_nothing","pars":{}}},',
        '"allConnections":{',
        '"c1":{"ID":"c1","from":"t0","to":"L","toPart":"HEAD","type":"Connection","ConnectionType":"normal"},',
        '"c2":{"ID":"c2","from":"L","to":"B","fromPart":"HEAD","type":"Connection","ConnectionType":"normal"},',
        '"c3":{"ID":"c3","from":"B","to":"L","toPart":"TAIL","type":"Connection","ConnectionType":"normal"},',
        '"c4":{"ID":"c4","from":"L","to":"X","fromPart":"TAIL","type":"Connection","ConnectionType":"normal"},',
        '"c5":{"ID":"c5","from":"L","to":"X","type":"Connection","ConnectionType":"Exception"}}}'))
}

; Loop L with two TAIL connections (to X and to Y) and two Exception connections (to X and to Y).
LoopTwoExitsFlow() {
    return FlowDefinition.FromText("loop2", Lines(
        '{"allElements":{',
        '"t0":{"ID":"t0","type":"trigger","class":"trigger_Manual","pars":{}},',
        '"L":{"ID":"L","type":"loop","class":"Loop_SimpleLoop","pars":{}},',
        '"B":{"ID":"B","type":"action","class":"action_Do_nothing","pars":{}},',
        '"X":{"ID":"X","type":"action","class":"action_Do_nothing","pars":{}},',
        '"Y":{"ID":"Y","type":"action","class":"action_Do_nothing","pars":{}}},',
        '"allConnections":{',
        '"c1":{"ID":"c1","from":"t0","to":"L","toPart":"HEAD","type":"Connection","ConnectionType":"normal"},',
        '"c2":{"ID":"c2","from":"L","to":"B","fromPart":"HEAD","type":"Connection","ConnectionType":"normal"},',
        '"c3":{"ID":"c3","from":"B","to":"L","toPart":"TAIL","type":"Connection","ConnectionType":"normal"},',
        '"c4":{"ID":"c4","from":"L","to":"X","fromPart":"TAIL","type":"Connection","ConnectionType":"normal"},',
        '"c5":{"ID":"c5","from":"L","to":"Y","fromPart":"TAIL","type":"Connection","ConnectionType":"normal"},',
        '"c6":{"ID":"c6","from":"L","to":"X","type":"Connection","ConnectionType":"Exception"},',
        '"c7":{"ID":"c7","from":"L","to":"Y","type":"Connection","ConnectionType":"Exception"}}}'))
}

; trigger t0 -> a. a has two normal connections: c2 to the head of loop L, c3 to the plain action c.
BranchIntoLoopFlow(loopFirst := true) {
    first := loopFirst ? '"c2":{"ID":"c2","from":"a","to":"L","toPart":"HEAD","type":"Connection","ConnectionType":"normal"},'
        : '"c2":{"ID":"c2","from":"a","to":"c","type":"Connection","ConnectionType":"normal"},'
    second := loopFirst ? '"c3":{"ID":"c3","from":"a","to":"c","type":"Connection","ConnectionType":"normal"}}}'
        : '"c3":{"ID":"c3","from":"a","to":"L","toPart":"HEAD","type":"Connection","ConnectionType":"normal"}}}'
    return FlowDefinition.FromText("branchloop", Lines(
        '{"allElements":{',
        '"t0":{"ID":"t0","type":"trigger","class":"trigger_Manual","pars":{}},',
        '"a":{"ID":"a","type":"action","class":"action_Do_nothing","pars":{}},',
        '"L":{"ID":"L","type":"loop","class":"Loop_SimpleLoop","pars":{}},',
        '"c":{"ID":"c","type":"action","class":"action_Do_nothing","pars":{}}},',
        '"allConnections":{',
        '"c1":{"ID":"c1","from":"t0","to":"a","type":"Connection","ConnectionType":"normal"},',
        first, second))
}

; trigger t0 -> a, and one connection to an unknown element (dangling, ignored)
DanglingFlow() {
    return FlowDefinition.FromText("dangling", Lines(
        '{"allElements":{',
        '"t0":{"ID":"t0","type":"trigger","class":"trigger_Manual","pars":{}},',
        '"a":{"ID":"a","type":"action","class":"action_Do_nothing","pars":{}}},',
        '"allConnections":{',
        '"c1":{"ID":"c1","from":"t0","to":"a","type":"Connection","ConnectionType":"normal"},',
        '"c2":{"ID":"c2","from":"t0","to":"","type":"Connection","ConnectionType":"normal"}}}'))
}

; Starts an instance on a trigger element and returns [instance, triggerThread].
StartTrigger(flow, triggerId := "t0") {
    inst := Instance("i1", flow.FlowId)
    thread := inst.Start("t1", triggerId)
    return [inst, thread]
}

; Runs the element of a ready thread with the given result: ready -> running -> finished.
RunElement(thread, result) {
    Assert.True(thread.Dispatch(), "dispatch of " thread.Id)
    Assert.Equal(thread.Finish(result), "finished")
}

; Moves a finished thread on and returns the outcome Map.
Advance(inst, flow, thread) {
    return Scheduler.Advance(inst, flow, thread, MakeIds())
}

ResolveNextSimple() {
    flow := LinearFlow()
    inst := StartTrigger(flow)[1]
    thread := inst.Threads["t1"]
    matches := Scheduler.ResolveNext(flow, thread, "Normal")
    Assert.Equal(matches.Length, 1)
    Assert.Equal(matches[1]["to"], "a")
}

ResolveNextYesNo() {
    flow := YesNoFlow()
    thread := ThreadState("t5", "i1", "a")
    yes := Scheduler.ResolveNext(flow, thread, "yes")
    no := Scheduler.ResolveNext(flow, thread, "NO")
    Assert.Equal(yes.Length, 1)
    Assert.Equal(yes[1]["to"], "b")
    Assert.Equal(no.Length, 1)
    Assert.Equal(no[1]["to"], "c")
}

ResolveNextWithoutMatch() {
    flow := YesNoFlow()
    thread := ThreadState("t5", "i1", "a")
    Assert.Equal(Scheduler.ResolveNext(flow, thread, "exception").Length, 0)
    Assert.Equal(Scheduler.ResolveNext(flow, ThreadState("t6", "i1", "b"), "Normal").Length, 0)
}

ResolveNextReturnsEveryMatch() {
    flow := TwoConnectionsFlow()
    thread := ThreadState("t5", "i1", "a")
    matches := Scheduler.ResolveNext(flow, thread, "normal")
    Assert.Equal(matches.Length, 2)
    Assert.Equal(matches[1]["to"], "b")
    Assert.Equal(matches[2]["to"], "c")
}

ResolveNextIgnoresDangling() {
    flow := DanglingFlow()
    matches := Scheduler.ResolveNext(flow, ThreadState("t5", "i1", "t0"), "Normal")
    Assert.Equal(matches.Length, 1)
    Assert.Equal(matches[1]["to"], "a")
}

LinearFlowRunsToEnd() {
    flow := LinearFlow()
    pair := StartTrigger(flow)
    inst := pair[1]
    trig := pair[2]

    out := Advance(inst, flow, trig)
    Assert.Equal(out["outcome"], "next")
    Assert.Equal(out["threadIds"].Length, 1)
    a := inst.Threads["t1"]
    Assert.Equal(a.State, "ready")
    Assert.Equal(a.ElementId, "a")

    RunElement(a, "normal")
    out := Advance(inst, flow, a)
    Assert.Equal(out["outcome"], "next")
    b := inst.Threads["t1"]
    Assert.Equal(b.ElementId, "b")

    RunElement(b, "normal")
    out := Advance(inst, flow, b)
    Assert.Equal(out["outcome"], "removed")
    Assert.Equal(out["unhandled"], false)
    Assert.Equal(inst.Threads.Count, 0)
    Assert.Equal(inst.State, "ended")
}

YesNoTakesTheMatchingBranch() {
    flow := YesNoFlow()
    pair := StartTrigger(flow)
    inst := pair[1]
    Advance(inst, flow, pair[2])
    cond := inst.Threads["t1"]
    RunElement(cond, "No")
    out := Advance(inst, flow, cond)
    Assert.Equal(out["outcome"], "next")
    Assert.Equal(inst.Threads["t1"].ElementId, "c")
}

TwoConnectionsCloneTheThread() {
    flow := TwoConnectionsFlow()
    pair := StartTrigger(flow)
    inst := pair[1]
    Advance(inst, flow, pair[2])
    a := inst.Threads["t1"]
    RunElement(a, "normal")
    out := Advance(inst, flow, a)
    Assert.Equal(out["outcome"], "next")
    ids := out["threadIds"]
    Assert.Equal(ids.Length, 2)
    Assert.Equal(ids[1], "t1")
    Assert.Equal(inst.Threads.Count, 2)
    Assert.Equal(inst.Threads[ids[1]].ElementId, "b")
    Assert.Equal(inst.Threads[ids[2]].ElementId, "c")
    Assert.Equal(inst.Threads[ids[2]].State, "ready")
    Assert.Equal(inst.Threads[ids[2]].InstanceId, "i1")
}

ExceptionWithoutConnectionIsUnhandled() {
    flow := LinearFlow()
    pair := StartTrigger(flow)
    inst := pair[1]
    Advance(inst, flow, pair[2])
    a := inst.Threads["t1"]
    RunElement(a, "exception")
    out := Advance(inst, flow, a)
    Assert.Equal(out["outcome"], "removed")
    Assert.Equal(out["unhandled"], true)
    Assert.Equal(inst.State, "ended")
}

NormalWithoutConnectionIsNotUnhandled() {
    flow := LinearFlow()
    pair := StartTrigger(flow)
    inst := pair[1]
    Advance(inst, flow, pair[2])
    a := inst.Threads["t1"]
    RunElement(a, "normal")
    Advance(inst, flow, a)
    b := inst.Threads["t1"]
    RunElement(b, "normal")
    out := Advance(inst, flow, b)
    Assert.Equal(out["unhandled"], false)
}

ExceptionWithConnectionIsHandled() {
    flow := LoopFlow()
    pair := StartTrigger(flow)
    inst := pair[1]
    Advance(inst, flow, pair[2])
    loopThread := inst.Threads["t1"]
    RunElement(loopThread, "exception")
    out := Advance(inst, flow, loopThread)
    Assert.Equal(out["outcome"], "next")
    Assert.Equal(out["unhandled"], false)
}

AdvanceRequiresFinishedThread() {
    flow := LinearFlow()
    pair := StartTrigger(flow)
    inst := pair[1]
    Assert.Equal(Advance(inst, flow, ThreadState("t9", "i1", "a"))["outcome"], "not_finished")
    Assert.Equal(inst.Threads.Count, 1)
}

LoopPushesOnHeadAndPopsOnTail() {
    flow := LoopFlow()
    pair := StartTrigger(flow)
    inst := pair[1]
    Advance(inst, flow, pair[2])
    loopThread := inst.Threads["t1"]
    Assert.Equal(loopThread.ElementId, "L")
    Assert.Equal(loopThread.Loops.Depth, 1)

    RunElement(loopThread, "head")
    Advance(inst, flow, loopThread)
    body := inst.Threads["t1"]
    Assert.Equal(body.ElementId, "B")
    Assert.Equal(body.Loops.Depth, 1)

    body.Loops.Visible["i"] := 2     ; value inside the loop, must be undone by the pop
    RunElement(body, "normal")
    Advance(inst, flow, body)
    back := inst.Threads["t1"]
    Assert.Equal(back.ElementId, "L")
    Assert.Equal(back.EntryPoint, "TAIL")
    Assert.Equal(back.Loops.Depth, 1)

    RunElement(back, "tail")
    out := Advance(inst, flow, back)
    Assert.Equal(out["outcome"], "next")
    after := inst.Threads["t1"]
    Assert.Equal(after.ElementId, "X")
    Assert.Equal(after.Loops.Depth, 0)
    Assert.Equal(after.Loops.Visible.Has("i"), false)   ; state at the push, before "i" was set
}

LoopExitWithExceptionPopsToo() {
    flow := LoopFlow()
    pair := StartTrigger(flow)
    inst := pair[1]
    Advance(inst, flow, pair[2])
    loopThread := inst.Threads["t1"]
    RunElement(loopThread, "exception")
    Advance(inst, flow, loopThread)
    Assert.Equal(inst.Threads["t1"].ElementId, "X")
    Assert.Equal(inst.Threads["t1"].Loops.Depth, 0)
}

; Enters the loop of LoopTwoExitsFlow, sets a variable inside it and finishes the loop element with
; the given result. Returns [instance, flow, outcome].
LeaveLoopTwoWays(result) {
    flow := LoopTwoExitsFlow()
    pair := StartTrigger(flow)
    inst := pair[1]
    Advance(inst, flow, pair[2])
    loopThread := inst.Threads["t1"]
    Assert.Equal(loopThread.Loops.Depth, 1)
    loopThread.Loops.Visible["i"] := 2     ; value inside the loop, must be undone by the pop
    RunElement(loopThread, result)
    return [inst, flow, Advance(inst, flow, loopThread)]
}

LoopTwoTailConnectionsPopOnce() {
    r := LeaveLoopTwoWays("tail")
    inst := r[1]
    out := r[3]
    Assert.Equal(out["outcome"], "next")
    Assert.Equal(out["threadIds"].Length, 2)
    Assert.Equal(inst.Threads.Count, 2)
    targets := ""
    for id in out["threadIds"] {
        t := inst.Threads[id]
        Assert.Equal(t.State, "ready")
        Assert.Equal(t.Loops.Depth, 0, "stack depth of " id)
        Assert.Equal(t.Loops.Visible.Has("i"), false, "loop variable restored in " id)
        targets .= t.ElementId
    }
    Assert.Equal(targets, "XY")
}

LoopTwoExceptionConnectionsPopOnce() {
    r := LeaveLoopTwoWays("exception")
    inst := r[1]
    out := r[3]
    Assert.Equal(out["outcome"], "next")
    Assert.Equal(out["threadIds"].Length, 2)
    for id in out["threadIds"] {
        t := inst.Threads[id]
        Assert.Equal(t.State, "ready")
        Assert.Equal(t.Loops.Depth, 0, "stack depth of " id)
        Assert.Equal(t.Loops.Visible.Has("i"), false, "loop variable restored in " id)
    }
}

LoopLeftInsideOuterLoopKeepsOuterLevel() {
    ; The thread already sits inside an outer loop (depth 1 before entering L): both exits keep depth 1.
    flow := LoopTwoExitsFlow()
    pair := StartTrigger(flow)
    inst := pair[1]
    pair[2].Loops.Push()                  ; outer loop level
    Advance(inst, flow, pair[2])
    loopThread := inst.Threads["t1"]
    Assert.Equal(loopThread.Loops.Depth, 2)
    RunElement(loopThread, "tail")
    out := Advance(inst, flow, loopThread)
    Assert.Equal(out["threadIds"].Length, 2)
    for id in out["threadIds"]
        Assert.Equal(inst.Threads[id].Loops.Depth, 1, "stack depth of " id)
}

BranchIntoLoopPushesOnlyTheLoopThread(loopFirst) {
    flow := BranchIntoLoopFlow(loopFirst)
    pair := StartTrigger(flow)
    inst := pair[1]
    Advance(inst, flow, pair[2])
    a := inst.Threads["t1"]
    RunElement(a, "normal")
    out := Advance(inst, flow, a)
    Assert.Equal(out["threadIds"].Length, 2)
    for id in out["threadIds"] {
        t := inst.Threads[id]
        if (t.ElementId = "L")
            Assert.Equal(t.Loops.Depth, 1, "thread in the loop")
        else
            Assert.Equal(t.Loops.Depth, 0, "thread beside the loop (" t.ElementId ")")
    }
}

BranchIntoLoopFirst() {
    BranchIntoLoopPushesOnlyTheLoopThread(true)
}

BranchIntoLoopSecond() {
    BranchIntoLoopPushesOnlyTheLoopThread(false)
}

RealFlowRunsFromTriggerToEnd() {
    text := ReadText(SavedFlowsDir() "\Flow 464187831.json")
    flow := FlowDefinition.FromText("464187831", text)
    pair := StartTrigger(flow, "element0000000001")
    inst := pair[1]
    trig := pair[2]

    Advance(inst, flow, trig)
    first := inst.Threads["t1"]
    Assert.Equal(first.ElementId, "element0000000004")
    Assert.Equal(flow.ElementClass(first.ElementId), "action_Encode_string")

    RunElement(first, "normal")
    Advance(inst, flow, first)
    second := inst.Threads["t1"]
    Assert.Equal(second.ElementId, "element0000000007")
    Assert.Equal(flow.ElementClass(second.ElementId), "condition_Debug_dialog")

    RunElement(second, "normal")
    out := Advance(inst, flow, second)
    Assert.Equal(out["outcome"], "removed")
    Assert.Equal(inst.State, "ended")
}

; F-0012: leaving a loop whose stack is empty must end the thread as unhandled, not throw.
LoopLeftWithEmptyStackEndsTheThread() {
    flow := LoopFlow()
    pair := StartTrigger(flow)
    inst := pair[1]
    Advance(inst, flow, pair[2])
    loopThread := inst.Threads["t1"]
    loopThread.Loops.Pop()                ; simulate a loop that was entered without the push
    Assert.Equal(loopThread.Loops.Depth, 0)
    RunElement(loopThread, "tail")
    out := Advance(inst, flow, loopThread)
    Assert.Equal(out["outcome"], "removed")
    Assert.Equal(out["unhandled"], true)
    Assert.Equal(inst.Threads.Count, 0)
    Assert.Equal(inst.State, "ended")
}

TestRun.Init()

TestRun.Case("ResolveNext: a normal connection matches a Normal result", ResolveNextSimple)
TestRun.Case("ResolveNext: Yes and No match case-insensitively", ResolveNextYesNo)
TestRun.Case("ResolveNext: a result without a connection gives an empty list", ResolveNextWithoutMatch)
TestRun.Case("ResolveNext: every matching connection is returned in order", ResolveNextReturnsEveryMatch)
TestRun.Case("ResolveNext: dangling connections never match", ResolveNextIgnoresDangling)
TestRun.Case("Advance: a linear flow runs to the end and ends the instance", LinearFlowRunsToEnd)
TestRun.Case("Advance: the Yes/No branch taken is the one of the result", YesNoTakesTheMatchingBranch)
TestRun.Case("Advance: two matching connections clone the thread once", TwoConnectionsCloneTheThread)
TestRun.Case("Advance: exception without connection is removed and reported unhandled", ExceptionWithoutConnectionIsUnhandled)
TestRun.Case("Advance: normal without connection is removed, not unhandled", NormalWithoutConnectionIsNotUnhandled)
TestRun.Case("Advance: exception with a connection is handled by it", ExceptionWithConnectionIsHandled)
TestRun.Case("Advance: a thread that is not finished is not moved", AdvanceRequiresFinishedThread)
TestRun.Case("Loop: head pushes, tail pops and restores the loop variables", LoopPushesOnHeadAndPopsOnTail)
TestRun.Case("Loop: leaving with exception pops the loop stack too", LoopExitWithExceptionPopsToo)
TestRun.Case("Loop: two tail connections pop the loop stack once, both threads are ready", LoopTwoTailConnectionsPopOnce)
TestRun.Case("Loop: two exception connections pop the loop stack once", LoopTwoExceptionConnectionsPopOnce)
TestRun.Case("Loop: leaving a loop inside an outer loop keeps the outer level in every branch", LoopLeftInsideOuterLoopKeepsOuterLevel)
TestRun.Case("Advance: branching into a loop pushes only the loop thread (loop connection first)", BranchIntoLoopFirst)
TestRun.Case("Advance: branching into a loop pushes only the loop thread (loop connection second)", BranchIntoLoopSecond)
TestRun.Case("Loop: leaving with an empty stack ends the thread as unhandled (F-0012)", LoopLeftWithEmptyStackEndsTheThread)
TestRun.Case("real flow 464187831 runs from trigger to end", RealFlowRunsFromTriggerToEnd)

TestRun.Finish()
