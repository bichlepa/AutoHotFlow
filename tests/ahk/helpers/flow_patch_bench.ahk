#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, StdOut
; Benchmark for WI-0093 (task 6, doc/MEASUREMENTS.md MS-0053): the engine time of one patch on a generated flow of 300
; elements. The engine's work for a patch is FlowPatch.Apply plus the building of the new FlowDefinition (the commit
; itself is a pointer change). Not a unit test. Each case runs the patch on the same base flow and measures the
; time with QueryPerformanceCounter.
; A_Args: 1 = result file (one JSON line of type "bench" per case), 2 = repetitions per case.
#Include ..\..\..\src\core\FlowPatch.ahk
#Include ..\..\..\src\engine\core\FlowDefinition.ahk

ELEMENTS := 300

class Clock {
    static freq := 0
    static Init() {
        DllCall("QueryPerformanceFrequency", "Int64*", &f := 0)
        Clock.freq := f
    }
    static Now() {
        DllCall("QueryPerformanceCounter", "Int64*", &t := 0)
        return t
    }
    static Ms(from, to) => (to - from) * 1000 / Clock.freq
}

Index() {
    m := Map()
    m.CaseSense := "Off"
    return m
}

; The generated flow: a manual trigger and 299 actions in a chain, 299 connections.
BuildFlow() {
    els := Index()
    cons := Index()
    for i in Range(1, ELEMENTS) {
        id := "element" Format("{:010}", i)
        el := Map("ID", id, "type", (i = 1) ? "trigger" : "action", "class", (i = 1) ? "Trigger_Manual" : "Action_Do_nothing"
            , "name", id, "package", "Default", "packageVersion", "1.2.0", "x", 0, "y", i * 10, "pars", Map())
        if (i = 1)
            el["DefaultTrigger"] := Json.True
        els[id] := el
        if (i > 1) {
            cid := "connection" Format("{:010}", 100000 + i)
            cons[cid] := Map("ID", cid, "from", "element" Format("{:010}", i - 1), "to", id, "ConnectionType", "normal"
                , "type", "Connection")
        }
    }
    settings := Index()
    settings["ExecutionPolicy"] := "default"
    settings["strictTypes"] := Json.True
    return Map("name", "Generated", "category", "", "ElementIDCounter", String(ELEMENTS * 2 + 1), "flowSettings", settings
        , "allElements", els, "allConnections", cons)
}

Range(from, to) {
    out := []
    loop to - from + 1
        out.Push(from + A_Index - 1)
    return out
}

; One patch: the operations and the function that the engine runs for them.
Commit(base, ops) {
    raw := FlowPatch.Apply(base, ops)
    return FlowDefinition("bench", raw, 2)
}

MoveOne(base, rep) {
    id := "element" Format("{:010}", 150)
    return [Map("op", "element.update", "id", id, "fields", Map("x", rep))]
}

MoveThirty(base, rep) {
    ops := []
    for i in Range(100, 129)
        ops.Push(Map("op", "element.update", "id", "element" Format("{:010}", i), "fields", Map("x", rep + i)))
    return ops
}

AddThirty(base, rep) {
    ops := []
    for k in Range(1, 30) {
        id := "element" Format("{:010}", ELEMENTS * 2 + k)
        ops.Push(Map("op", "element.add", "element", Map("ID", id, "type", "action", "class", "Action_Do_nothing"
            , "name", id, "package", "Default", "packageVersion", "1.2.0", "x", rep, "y", k, "pars", Map())))
        cid := "connection" Format("{:010}", 200000 + k)
        ops.Push(Map("op", "connection.add", "connection", Map("ID", cid, "from", "element" Format("{:010}", 10 + k)
            , "to", id, "ConnectionType", "normal", "type", "Connection")))
    }
    return ops
}

Measure(name, reps, makeOps, base, resultPath) {
    times := []
    for rep in Range(1, reps + 5) {
        ops := makeOps(base, rep)
        t0 := Clock.Now()
        Commit(base, ops)
        t1 := Clock.Now()
        if (rep > 5)                  ; the first five runs warm the code up
            times.Push(Clock.Ms(t0, t1))
    }
    sorted := []
    for t in times
        sorted.Push(t)
    sum := 0
    for t in sorted
        sum += t
    ; the sort: insertion sort on a small array (Array has no Sort in AHK v2)
    for i in Range(2, sorted.Length) {
        v := sorted[i]
        j := i - 1
        while (j >= 1 && sorted[j] > v) {
            sorted[j + 1] := sorted[j]
            j -= 1
        }
        sorted[j + 1] := v
    }
    p95 := sorted[Min(sorted.Length, Ceil(0.95 * sorted.Length))]
    line := '{"type":"bench","case":"' name '","runs":' sorted.Length ',"mean_ms":' Format("{:.3f}", sum / sorted.Length)
        . ',"p95_ms":' Format("{:.3f}", p95) ',"max_ms":' Format("{:.3f}", sorted[sorted.Length]) "}"
    FileAppend(line "`n", resultPath, "UTF-8")
}

Main() {
    resultPath := A_Args[1]
    reps := Integer(A_Args[2])
    Clock.Init()
    try FileDelete(resultPath)
    base := BuildFlow()
    Measure("move one element", reps, MoveOne, base, resultPath)
    Measure("move 30 elements", reps, MoveThirty, base, resultPath)
    Measure("add 30 elements with connections", reps, AddThirty, base, resultPath)
    ExitApp(0)
}

Main()
