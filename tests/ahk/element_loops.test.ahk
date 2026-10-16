#Requires AutoHotkey v2.0
; Tests for the loop elements of the package Default (WI-0054): the names and parameters of v1, the splitting of
; Loop_Parse_A_String, and runs in the Executor with the stand-in owner (helpers/ExecutorKit.ahk): passes, break, the
; loop variables inside the body and their restoration after the loop, also after an exception. The flows in real
; processes (log, probes, v1 files, 100,000 passes) are tests/integration/test_core_c_loops.py.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include helpers\ExecutorKit.ahk
#Include ..\..\src\elements\Default\_includes_engine.ahk

; --- flows ---------------------------------------------------------------------------------------------------------
; A loop element. parts of the connections: HEAD, TAIL, BREAK (any case).
LoopEl(id, cls, pars := "{}") => '"' id '":{"ID":"' id '","type":"Loop","class":"' cls '","pars":' pars ',"HeightOfVerticalBar":"280"}'
; A connection with the parts of a loop: fromPart (the part of a loop that it leaves) and toPart (the part it enters)
Link(id, from, to, fromPart := "", toPart := "", type := "normal") {
    parts := (fromPart != "" ? ',"fromPart":"' fromPart '"' : "") (toPart != "" ? ',"toPart":"' toPart '"' : "")
    return '"' id '":{"ID":"' id '","from":"' from '","to":"' to '","type":"Connection","ConnectionType":"' type '"' parts '}'
}

; The flow text in the new format (no conversion of the expressions) in strict mode (E0034)
StrictFlow(elements, connections) {
    els := Trig()
    for e in elements
        els .= "," e
    cons := ""
    for c in connections
        cons .= (cons = "" ? "" : ",") c
    return '{"formatVersion":2,"name":"f","flowSettings":{"ExecutionPolicy":"default","strictTypes":true},"allElements":{'
        . els '},"allConnections":{' cons '}}'
}

; Runs the flow to its end. seen: the lines that the elements put into Probe by onRun, in order.
Run(text, onRun) {
    owner := NewOwner(text)
    Probe.onRun := onRun
    owner.executor.StartFlow(owner.flows.Get("f"))
    loop 200 {
        owner.Drive()
        if (!owner.executor.IsExecuting("f"))
            break
    }
    return owner
}

; "a_index/a_loopkey/a_loopfield" as the element sees them ("-" for a missing variable)
Vars(ctx) {
    out := ""
    for name in ["a_index", "a_loopkey", "a_loopfield"]
        out .= (out = "" ? "" : "/") (ctx.VarLocation(name) ? ctx.GetVar(name) : "-")
    return out
}

; Records "<element id>:<variables>" for every element that has the class ExecKit.Test_Count
Recorder(seen) {
    return (ctx) => seen.Push(ctx.elementId ":" Vars(ctx))
}

Joined(list) {
    out := ""
    for item in list
        out .= (out = "" ? "" : " ") item
    return out
}

Cnt(id) => El(id, "ExecKit.Test_Count")

; --- passes ----------------------------------------------------------------------------------------------------------
SimpleLoopPasses() {
    seen := []
    text := StrictFlow([LoopEl("L", "Loop_SimpleLoop", '{"Infinite":0,"repeatCount":3}'), Cnt("b"), Cnt("z")]
        , [Link("c1", "t0", "L", "", "HEAD"), Link("c2", "L", "b", "HEAD"), Link("c3", "b", "L", "", "TAIL")
        , Link("c4", "L", "z", "TAIL")])
    owner := Run(text, Recorder(seen))
    Assert.Equal(Joined(seen), "b:1/-/- b:2/-/- b:3/-/- z:-/-/-")
    Assert.Equal(owner.LastEndReason(), "finished")
}

SimpleLoopZeroPassesAndBreak() {
    seen := []
    zero := StrictFlow([LoopEl("L", "Loop_SimpleLoop", '{"Infinite":0,"repeatCount":0}'), Cnt("b"), Cnt("z")]
        , [Link("c1", "t0", "L", "", "HEAD"), Link("c2", "L", "b", "HEAD"), Link("c3", "b", "L", "", "TAIL")
        , Link("c4", "L", "z", "TAIL")])
    Run(zero, Recorder(seen))
    Assert.Equal(Joined(seen), "z:-/-/-")
    ; the body leads to the break part: one pass, then the loop is left
    seen := []
    broken := StrictFlow([LoopEl("L", "Loop_SimpleLoop", '{"Infinite":1}'), Cnt("b"), Cnt("z")]
        , [Link("c1", "t0", "L", "", "HEAD"), Link("c2", "L", "b", "HEAD"), Link("c3", "b", "L", "", "break")
        , Link("c4", "L", "z", "TAIL")])
    Run(broken, Recorder(seen))
    Assert.Equal(Joined(seen), "b:1/-/- z:-/-/-")
}

ListLoopVariablesAndCopy() {
    seen := []
    ; "s" sets the list; the body "b" replaces the list: the loop goes on with its copy
    rec := Recorder(seen)
    onRun := (ctx) => (ctx.elementId = "s" ? ctx.SetVar("l", ListOf("x", "y", "z")) : 0
        , ctx.elementId = "b" ? ctx.SetVar("l", ListOf("q")) : 0, rec(ctx))
    text := StrictFlow([Cnt("s"), LoopEl("L", "Loop_Work_through_a_list", '{"VarValue":"l"}'), Cnt("b"), Cnt("z")]
        , [Link("c0", "t0", "s"), Link("c1", "s", "L", "", "HEAD"), Link("c2", "L", "b", "HEAD")
        , Link("c3", "b", "L", "", "TAIL"), Link("c4", "L", "z", "TAIL")])
    Run(text, onRun)
    Assert.Equal(Joined(seen), "s:-/-/- b:1/1/x b:2/2/y b:3/3/z z:-/-/-")
}

ListOf(values*) {
    m := Map()
    m.CaseSense := "Off"
    for v in values
        m[A_Index] := v
    return m
}

; A change of the flow while the loop runs (E0001, ARCHITECTURE 4.2): the running body keeps what it started with, and the
; loop reads its parameters from the newest revision at its next entry (as v1 read them from the current state).
FlowChangeDuringTheLoop() {
    shape := (count) => StrictFlow([LoopEl("L", "Loop_SimpleLoop", '{"Infinite":0,"repeatCount":' count '}')
        , El("h", "ExecKit.Test_Hold"), Cnt("z")]
        , [Link("c1", "t0", "L", "", "HEAD"), Link("c2", "L", "h", "HEAD"), Link("c3", "h", "L", "", "TAIL")
        , Link("c4", "L", "z", "TAIL")])
    owner := NewOwner(shape(3))
    owner.executor.StartFlow(owner.flows.Get("f"))
    owner.Drive()
    Assert.True(Probe.held.Has("h"), "the first pass runs")
    Commit(owner, shape(5))                                ; the user raises the count while pass 1 is running
    loop 12 {
        if (Probe.held.Has("h"))
            Probe.Release("h")
        owner.Drive()
    }
    Assert.Equal(Probe.Count("h"), 5)
    Assert.Equal(owner.LastEndReason(), "finished")
}

; --- nesting and exception -----------------------------------------------------------------------------------------------
NestedLoopsRestoreTheOuterVariables() {
    seen := []
    rec := Recorder(seen)
    onRun := (ctx) => (ctx.elementId = "s" ? ctx.SetVar("l", ListOf("x", "y")) : 0, rec(ctx))
    text := StrictFlow([Cnt("s"), LoopEl("LO", "Loop_Work_through_a_list", '{"VarValue":"l"}')
        , LoopEl("LI", "Loop_Parse_A_String", '{"VarValue":"p,q","Delimiters":",","OmitChars":""}'), Cnt("bi"), Cnt("bo"), Cnt("z")]
        , [Link("c0", "t0", "s"), Link("c1", "s", "LO", "", "HEAD"), Link("c2", "LO", "LI", "HEAD", "HEAD")
        , Link("c3", "LI", "bi", "HEAD"), Link("c4", "bi", "LI", "", "TAIL"), Link("c5", "LI", "bo", "TAIL")
        , Link("c6", "bo", "LO", "", "TAIL"), Link("c7", "LO", "z", "TAIL")])
    Run(text, onRun)
    ; The inner loop sets A_Index and A_LoopField and leaves A_LoopKey alone, so inside it A_LoopKey is the one of the outer
    ; loop (as in v1: entering a loop saves the loop variables and does not clear them). After it, all are the outer's.
    Assert.Equal(Joined(seen), "s:-/-/- bi:1/1/p bi:2/1/q bo:1/1/x bi:1/2/p bi:2/2/q bo:2/2/y z:-/-/-")
}

LeavingThroughExceptionRestoresTheOuterVariables() {
    seen := []
    rec := Recorder(seen)
    onRun := (ctx) => (ctx.elementId = "s" ? ctx.SetVar("l", ListOf("x", "y")) : 0, rec(ctx))
    ; the inner loop fails when it checks the condition for its second pass (strict mode: a type error)
    inner := '{"Expression":"a_index = 1 or \"a\" + 1","EvaluateOnFirstIteration":1}'
    text := StrictFlow([Cnt("s"), LoopEl("LO", "Loop_Work_through_a_list", '{"VarValue":"l"}')
        , LoopEl("LI", "Loop_Condition", inner), Cnt("bi"), Cnt("be"), Cnt("z")]
        , [Link("c0", "t0", "s"), Link("c1", "s", "LO", "", "HEAD"), Link("c2", "LO", "LI", "HEAD", "HEAD")
        , Link("c3", "LI", "bi", "HEAD"), Link("c4", "bi", "LI", "", "TAIL"), Link("c5", "LI", "be", "", "", "exception")
        , Link("c6", "be", "LO", "", "TAIL"), Link("c7", "LO", "z", "TAIL")])
    owner := Run(text, onRun)
    Assert.Equal(Joined(seen), "s:-/-/- bi:1/1/x be:1/1/x bi:1/2/y be:2/2/y z:-/-/-")
    Assert.Equal(owner.LastEndReason(), "finished")
}

; --- Loop_Parse_A_String.Split -------------------------------------------------------------------------------------------
FieldsOf(text, delimiters, omitChars) {
    out := ""
    for , field in Default.Loop_Parse_A_String.Split(text, delimiters, omitChars)
        out .= "[" field "]"
    return out
}

ParseSplit() {
    Assert.Equal(FieldsOf("a,b,c", ",", ""), "[a][b][c]")
    Assert.Equal(FieldsOf("a,,b,", ",", ""), "[a][][b][]")
    Assert.Equal(FieldsOf("a;b,c d", ";, ", ""), "[a][b][c][d]")
    Assert.Equal(FieldsOf("abc", "", ""), "[a][b][c]")                 ; empty delimiters: every character
    Assert.Equal(FieldsOf("", ",", ""), "")                             ; no field at all
    Assert.Equal(FieldsOf(",,", ",", ""), "[][][]")
    Assert.Equal(FieldsOf("AxaXb", "a", ""), "[Ax][Xb]")               ; case sensitive
    Assert.Equal(FieldsOf(" a , b ", ",", " "), "[a][b]")
    Assert.Equal(FieldsOf("a b, c d", ",", " "), "[a b][c d]")          ; omitted at the ends only
    Assert.Equal(FieldsOf("a,   ,b", ",", " "), "[a][][b]")
    ; the delimiter text CSV (any case) is the CSV mode of AutoHotkey, as in v1 (checked with the v1 interpreter), not the
    ; characters C, S and V; other texts with these letters are characters
    Assert.Equal(FieldsOf('a,"b,c",d', "CSV", ""), "[a][b,c][d]")
    Assert.Equal(FieldsOf('a,"b,c",d', "csv", ""), "[a][b,c][d]")
    Assert.Equal(FieldsOf("acbsvd", "Csv", ""), "[acbsvd]")            ; "Csv" is the CSV mode too, but "cs" is not: characters
    Assert.Equal(FieldsOf("acbsvd", "cs", ""), "[a][b][vd]")
}

; --- names and parameters of v1 -----------------------------------------------------------------------------------------
NamesAreThoseOfV1() {
    Assert.Equal(Default.Loop_SimpleLoop.Name(), "Simple loop")
    Assert.Equal(Default.Loop_SimpleLoop.Category(), "General")
    Assert.Equal(Default.Loop_Condition.Name(), "Condition")
    Assert.Equal(Default.Loop_Work_through_a_list.Name(), "Work through a list")
    Assert.Equal(Default.Loop_Parse_A_String.Name(), "Parse a string")
    for cls in [Default.Loop_Condition, Default.Loop_Work_through_a_list, Default.Loop_Parse_A_String]
        Assert.Equal(cls.Category(), "Variable")
    Assert.Equal(Default.Loop_SimpleLoop.GenerateName("", {Infinite: 1, repeatCount: 5}), "Simple loop: Endless loop")
    Assert.Equal(Default.Loop_SimpleLoop.GenerateName("", {Infinite: 0, repeatCount: 5}), "Simple loop: 5 Repeats")
    Assert.Equal(Default.Loop_Condition.GenerateName("", {Expression: "a_index <= 3"}), "Condition - a_index <= 3")
    Assert.Equal(Default.Loop_Work_through_a_list.GenerateName("", {VarValue: "myList"}), "Work through a list: myList")
    Assert.Equal(Default.Loop_Parse_A_String.GenerateName("", {VarValue: "a,b", Delimiters: ",", OmitChars: " "})
        , "Parse a string - a,b - , -  ")
}

ParameterIdsAndDefaultsAreThoseOfV1() {
    Assert.Equal(ParamIds(Default.Loop_SimpleLoop), "Infinite repeatCount")
    Assert.Equal(ParamIds(Default.Loop_Condition), "Expression EvaluateOnFirstIteration")
    Assert.Equal(ParamIds(Default.Loop_Work_through_a_list), "VarValue")
    Assert.Equal(ParamIds(Default.Loop_Parse_A_String), "VarValue Delimiters OmitChars")
    p := Default.Loop_Condition.Parameters("")
    Assert.Equal(p[2].default, "a_index <= 5")
    Assert.Equal(p[2].content, "Expression")                          ; the loader converts a v1 text (WI-0039)
    Assert.Equal(Default.Loop_SimpleLoop.Parameters("")[3].default, 5)
}

ParamIds(cls) {
    out := ""
    for item in cls.Parameters("") {
        if (item.HasProp("id"))
            out .= (out = "" ? "" : " ") item.id
    }
    return out
}

TestRun.Init()

TestRun.Case("Loops: the names, categories and generated names are those of v1", NamesAreThoseOfV1)
TestRun.Case("Loops: parameter IDs and defaults are those of v1", ParameterIdsAndDefaultsAreThoseOfV1)
TestRun.Case("Loop_Parse_A_String: splitting by delimiters and omit characters", ParseSplit)
TestRun.Case("Loop_SimpleLoop: the passes and A_Index", SimpleLoopPasses)
TestRun.Case("Loop_SimpleLoop: no pass, and break", SimpleLoopZeroPassesAndBreak)
TestRun.Case("Loop_Work_through_a_list: the variables, and the copy of the list", ListLoopVariablesAndCopy)
TestRun.Case("Loops: a change of the flow during the loop takes effect at the next entry (E0001)", FlowChangeDuringTheLoop)
TestRun.Case("Loops: nested loops get their variables back", NestedLoopsRestoreTheOuterVariables)
TestRun.Case("Loops: left through exception the outer variables are back", LeavingThroughExceptionRestoresTheOuterVariables)

TestRun.Finish()
