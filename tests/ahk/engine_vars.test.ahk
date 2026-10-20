#Requires AutoHotkey v2.0
; Integration of the variable model with the Executor (WI-0040): real flows, instances, threads, loop stack and
; VarAccess, driven by EngineOwner (no processes). Instance and thread variables are separated per instance and
; per thread, static variables per flow, global variables are shared, nested loops keep their loop variables.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include helpers\ExecutorKit.ahk

; What Test_Vars read: "instanceId|elementId|value" in the order of the reads.
class VarLog {
    static lines := []

    static Reset() {
        VarLog.lines := []
    }

    ; The values read by an element (of all instances), joined by commas.
    static Values(elementId) {
        out := ""
        for line in VarLog.lines {
            parts := StrSplit(line, "|")
            if (parts[2] = elementId)
                out .= (out = "" ? "" : ",") parts[3]
        }
        return out
    }

    ; The value read by an element in one instance (the last one).
    static ValueIn(instId, elementId) {
        found := "<no read>"
        for line in VarLog.lines {
            parts := StrSplit(line, "|")
            if (parts[1] = instId && parts[2] = elementId)
                found := parts[3]
        }
        return found
    }
}

; The test elements of this file are classes of the package VarsTest (E0045): a flow names them with
; "package":"VarsTest", the registry knows them as VarsTest.<class>.
class VarsTest {
    ; Op "set": SetVar(Name, Value, Scope); Value "@inst" is the instance ID, "@thread" the thread ID.
    ; Op "get": records GetVar(Name) ("<none>" if it does not exist).
    class Test_Vars extends AhfElement {
        static Mode := "inline"
        static Run(ctx, params) {
            if (params.Op = "set") {
                value := params.Value
                if (value = "@inst")
                    value := ctx.instanceId
                else if (value = "@thread")
                    value := ctx.threadId
                ctx.SetVar(params.Name, value, params.HasProp("Scope") ? params.Scope : "")
            } else {
                VarLog.lines.Push(ctx.instanceId "|" ctx.elementId "|" ctx.GetVar(params.Name, "<none>"))
            }
            ctx.Finish("normal")
        }
    }

    ; A counting loop as the v1 loops do it: at "head" the loop variable starts at 1, at "tail" it counts on; the
    ; element finishes "head" (run the body) or "tail" (leave). The loop stack is pushed and popped by the Scheduler.
    class Test_Loop extends AhfElement {
        static Mode := "inline"
        static Run(ctx, params) {
            if (ctx.entryPoint = "head")
                ctx.SetVar("A_Index", 1, "loop")
            else
                ctx.SetVar("A_Index", ctx.GetVar("A_Index") + 1, "loop")
            ctx.Finish(ctx.GetVar("A_Index") <= Integer(params.Count) ? "head" : "tail")
        }
    }
}
ElementRegistry.Register(VarsTest.Test_Vars)
ElementRegistry.Register(VarsTest.Test_Loop)

SetEl(id, name, value, scope := "") => El(id, "VarsTest.Test_Vars", '{"Op":"set","Name":"' name '","Value":"' value '","Scope":"' scope '"}')
GetEl(id, name) => El(id, "VarsTest.Test_Vars", '{"Op":"get","Name":"' name '"}')
LoopEl(id, count) => '"' id '":{"ID":"' id '","type":"loop","package":"VarsTest","class":"Test_Loop","pars":{"Count":"' count '"}}'
LoopConn(id, from, to, fromPart := "", toPart := "") => '"' id '":{"ID":"' id '","from":"' from '","to":"' to
    . '","type":"Connection","ConnectionType":"normal"' (fromPart = "" ? "" : ',"fromPart":"' fromPart '"')
    . (toPart = "" ? "" : ',"toPart":"' toPart '"') '}'

Start(owner, flowId := "f") {
    id := owner.executor.StartFlow(owner.flows.Get(flowId))
    owner.Drive()
    return id
}

; Two instances of one flow wait at the same place: each sees its own instance and thread variables.
CheckInstancesAreSeparated() {
    VarLog.Reset()
    owner := NewOwner(FlowText([SetEl("s1", "x", "@inst"), SetEl("s2", "A_T", "@inst", "thread"), El("h", "ExecKit.Test_Hold")
        , GetEl("g1", "x"), GetEl("g2", "A_T")]
        , [Conn("c1", "t0", "s1"), Conn("c2", "s1", "s2"), Conn("c3", "s2", "h"), Conn("c4", "h", "g1"), Conn("c5", "g1", "g2")]
        , "parallel"))
    first := Start(owner)
    Probe.Release("h")                       ; only the first instance waits at h so far
    owner.Drive()
    second := Start(owner)
    Probe.Release("h")
    owner.Drive()
    Assert.Equal(VarLog.ValueIn(first, "g1"), first, "instance variable of the first instance")
    Assert.Equal(VarLog.ValueIn(first, "g2"), first, "thread variable of the first instance")
    Assert.Equal(VarLog.ValueIn(second, "g1"), second)
    Assert.Equal(VarLog.ValueIn(second, "g2"), second)
}

; Two instances at the same time: the second sets its variables while the first waits.
CheckInstancesRunningTogether() {
    VarLog.Reset()
    owner := NewOwner(FlowText([SetEl("s1", "x", "@inst"), El("h", "ExecKit.Test_Hold"), GetEl("g1", "x")]
        , [Conn("c1", "t0", "s1"), Conn("c2", "s1", "h"), Conn("c3", "h", "g1")], "parallel"))
    first := Start(owner)
    held := Probe.held["h"]
    second := Start(owner)                   ; replaces the entry of h in Probe.held
    held.Finish("normal")
    owner.Drive()
    Probe.Release("h")
    owner.Drive()
    Assert.Equal(VarLog.ValueIn(first, "g1"), first, "the second instance did not change x of the first")
    Assert.Equal(VarLog.ValueIn(second, "g1"), second)
}

; Two branches of one instance: each thread has its own thread variables, both share the instance variables.
CheckThreadsAreSeparated() {
    VarLog.Reset()
    owner := NewOwner(FlowText([SetEl("a1", "A_T", "one", "thread"), SetEl("b1", "A_T", "two", "thread")
        , SetEl("a2", "shared", "from a"), El("h", "ExecKit.Test_Hold"), GetEl("a3", "A_T"), GetEl("b3", "A_T"), GetEl("b4", "shared")]
        , [Conn("c1", "t0", "a1"), Conn("c2", "t0", "b1"), Conn("c3", "a1", "a2"), Conn("c4", "a2", "a3")
        , Conn("c5", "b1", "h"), Conn("c6", "h", "b3"), Conn("c7", "b3", "b4")]))
    Start(owner)
    Probe.Release("h")                       ; branch b goes on after branch a has set "shared"
    owner.Drive()
    Assert.Equal(VarLog.Values("a3"), "one")
    Assert.Equal(VarLog.Values("b3"), "two")
    Assert.Equal(VarLog.Values("b4"), "from a", "instance variables are shared by the threads")
}

; static belongs to one flow, global to all flows; both outlive the instance.
CheckStaticPerFlowAndGlobalShared() {
    VarLog.Reset()
    owner := NewOwner(FlowText([SetEl("s1", "static_s", "f"), SetEl("s2", "global_g", "from f"), GetEl("g1", "static_s")]
        , [Conn("c1", "t0", "s1"), Conn("c2", "s1", "s2"), Conn("c3", "s2", "g1")]))
    owner.flows.Load("g", FlowText([GetEl("r1", "static_s"), GetEl("r2", "global_g"), SetEl("s3", "static_s", "g")
        , GetEl("r3", "static_s")]
        , [Conn("c1", "t0", "r1"), Conn("c2", "r1", "r2"), Conn("c3", "r2", "s3"), Conn("c4", "s3", "r3")]))
    Start(owner, "f")
    Start(owner, "g")
    Start(owner, "f")
    Assert.Equal(VarLog.Values("r1"), "<none>", "static_s of f is not visible in g")
    Assert.Equal(VarLog.Values("r2"), "from f", "global_g is shared")
    Assert.Equal(VarLog.Values("r3"), "g")
    Assert.Equal(VarLog.Values("g1"), "f,f", "f keeps its static_s, also in the next instance")
    Assert.Equal(owner.vars.Static("f")["static_s"], "f")
    Assert.Equal(owner.vars.Static("g")["static_s"], "g")
    Assert.Equal(owner.vars.Global["global_g"], "from f")
}

; Instance variables end with the instance: a new instance starts empty.
CheckNewInstanceStartsEmpty() {
    VarLog.Reset()
    owner := NewOwner(FlowText([GetEl("g1", "x"), SetEl("s1", "x", "set")]
        , [Conn("c1", "t0", "g1"), Conn("c2", "g1", "s1")]))
    Start(owner)
    Start(owner)
    Assert.Equal(VarLog.Values("g1"), "<none>,<none>")
}

; Nested loops: the inner loop hides A_Index of the outer loop and gives it back when it ends.
CheckNestedLoops() {
    VarLog.Reset()
    owner := NewOwner(FlowText([LoopEl("L1", 2), LoopEl("L2", 3), GetEl("body", "A_Index"), GetEl("after", "A_Index")]
        , [LoopConn("c1", "t0", "L1", "", "head")
        , LoopConn("c2", "L1", "L2", "head", "head")
        , LoopConn("c3", "L2", "body", "head")
        , LoopConn("c4", "body", "L2", "", "tail")
        , LoopConn("c5", "L2", "L1", "tail", "tail")
        , LoopConn("c6", "L1", "after", "tail")]))
    Start(owner)
    Assert.Equal(VarLog.Values("body"), "1,2,3,1,2,3", "inner A_Index")
    ; WI-0089: the states of an element that change within one batch interval are coalesced; the batch carries the latest
    ; state, so the sequence of the loop's runs is not visible here (the end is checked below and by the runstate tests).
    Assert.Equal(owner.ElementStates("L1"), "finished")
    Assert.Equal(VarLog.Values("after"), "<none>", "no loop variable after the loops")
    Assert.Equal(owner.LastEndReason(), "finished")
}

; A worker job carries no copies of the variables (M-0045, WI-0050); the job keeps the engine context of the element, which
; the variable requests use; its exports come back by name.
CheckWorkerImportsAndExports() {
    VarLog.Reset()
    owner := NewOwner(FlowText([SetEl("s1", "x", "inst value"), SetEl("s2", "A_T", "thread value", "thread")
        , SetEl("s3", "global_g", "global value"), El("w", "ExecKit.Test_Wk"), GetEl("g1", "out"), GetEl("g2", "A_Out")]
        , [Conn("c1", "t0", "s1"), Conn("c2", "s1", "s2"), Conn("c3", "s2", "s3"), Conn("c4", "s3", "w")
        , Conn("c5", "w", "g1"), Conn("c6", "g1", "g2")]))
    Start(owner)
    Assert.Equal(owner.workers.imports[1].Count, 0, "no copies of the variables")
    ctx := owner.workers.payloads["fx-1"]["ctx"]
    Assert.Equal(ctx.GetVar("x"), "inst value")
    Assert.Equal(ctx.GetVar("A_T"), "thread value")
    Assert.Equal(ctx.GetVar("global_g"), "global value")
    Assert.Equal(ctx.GetVarLocation("A_TriggerID"), "thread", "thread variables of the trigger")
    owner.workers.Complete("fx-1", "normal", Map("out", "o", "A_Out", "ao"))
    owner.Drive()
    Assert.Equal(VarLog.Values("g1"), "o", "a plain export is an instance variable")
    Assert.Equal(VarLog.Values("g2"), "ao", "an A_ export is a thread variable")
}

; The trigger thread has A_TriggerID and A_TriggerTime (v1 newInstance); every branch inherits them.
CheckTriggerVariables() {
    VarLog.Reset()
    owner := NewOwner(FlowText([GetEl("g1", "A_TriggerID"), GetEl("g2", "A_TriggerTime")]
        , [Conn("c1", "t0", "g1"), Conn("c2", "t0", "g2")]))
    Start(owner)
    Assert.Equal(VarLog.Values("g1"), "t0")
    Assert.Equal(StrLen(VarLog.Values("g2")), 14)
}

TestRun.Case("instances: each one sees its own instance and thread variables", CheckInstancesAreSeparated)
TestRun.Case("instances: a second instance does not change the first", CheckInstancesRunningTogether)
TestRun.Case("threads: own thread variables, shared instance variables", CheckThreadsAreSeparated)
TestRun.Case("static per flow, global shared, both outlive the instance", CheckStaticPerFlowAndGlobalShared)
TestRun.Case("a new instance starts without instance variables", CheckNewInstanceStartsEmpty)
TestRun.Case("nested loops: the loop stack keeps the outer A_Index", CheckNestedLoops)
TestRun.Case("worker: no imports, the job keeps the context, exports come back by name", CheckWorkerImportsAndExports)
TestRun.Case("trigger variables A_TriggerID and A_TriggerTime", CheckTriggerVariables)

TestRun.Finish()
