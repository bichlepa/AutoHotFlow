#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, StdOut
; Measurement for WI-0054 (acceptance criterion): time per pass of the loop elements with an empty body, in an Executor
; with the stand-in owner (no IPC, no events sent). The loop head leads straight to the loop tail. Not a unit test.
; A_Args[1] = result file, A_Args[2] = number of passes (default 20000). Usage:
;   python tools/ahkrun.py --timeout 300 tests/ahk/helpers/loop_bench.ahk <result file> [passes]
#Include ExecutorKit.ahk
#Include ..\..\..\src\elements\Default\_includes_engine.ahk

; The owner counts the events instead of keeping them (a million Maps would be the measurement)
class BenchOwner extends EngineOwner {
    Emit(to, msgType, payload) {
        this.eventCount := (this.HasProp("eventCount") ? this.eventCount : 0) + 1
    }
}

QpcMs() {
    static freq := 0
    if (!freq)
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)
    DllCall("QueryPerformanceCounter", "Int64*", &t := 0)
    return t * 1000 / freq
}

LoopFlow(cls, pars) {
    els := Trig() ',"L":{"ID":"L","type":"Loop","class":"' cls '","pars":' pars ',"HeightOfVerticalBar":"280"}'
    cons := '"c1":{"ID":"c1","from":"t0","to":"L","toPart":"HEAD","ConnectionType":"normal","type":"Connection"},"c2":{"ID":"c2","from":"L","to":"L","fromPart":"HEAD","toPart":"TAIL","ConnectionType":"normal","type":"Connection"}'
    return '{"name":"f","flowSettings":{"ExecutionPolicy":"default","strictTypes":true},"formatVersion":2,"allElements":{' els '},"allConnections":{' cons '}}'
}

Measure(label, cls, pars, passes) {
    owner := BenchOwner()
    owner.flows.Load("f", LoopFlow(cls, pars))
    owner.eventCount := 0
    start := QpcMs()
    owner.executor.StartFlow(owner.flows.Get("f"))
    while (owner.executor.IsExecuting("f")) {
        owner.Drive()
        if (QpcMs() - start > 240000)
            return label ": gave up after 240 s`n"
    }
    ms := QpcMs() - start
    for line in Log.memoryLines {
        if (line["level"] = "a0" || line["level"] = "f0" || line["level"] = "f1")
            return label ": log entry " line["level"] ": " line["text"] "`n"
    }
    return Format("{1}: {2} passes in {3:.0f} ms = {4:.1f} us per pass (a pass is one run of the loop element; {5} events)`n"
        , label, passes, ms, ms * 1000 / passes, owner.eventCount)
}

; For comparison: a chain of `passes` elements that finish at once (the cost of the executor per element without a loop)
ChainFlow(n) {
    els := Trig()
    cons := ""
    prev := "t0"
    loop n {
        els .= "," El("e" A_Index, "ExecKit.Test_Count")
        cons .= (cons = "" ? "" : ",") Conn("c" A_Index, prev, "e" A_Index)
        prev := "e" A_Index
    }
    return '{"name":"f","flowSettings":{"ExecutionPolicy":"default"},"allElements":{' els '},"allConnections":{' cons '}}'
}

MeasureChain(passes) {
    owner := BenchOwner()
    owner.flows.Load("f", ChainFlow(passes))
    owner.eventCount := 0
    start := QpcMs()
    owner.executor.StartFlow(owner.flows.Get("f"))
    while (owner.executor.IsExecuting("f"))
        owner.Drive()
    ms := QpcMs() - start
    return Format("Chain of elements that finish at once: {1} elements in {2:.0f} ms = {3:.1f} us per element`n", passes, ms, ms * 1000 / passes)
}

resultPath := A_Args[1]
passes := A_Args.Length >= 2 ? Integer(A_Args[2]) : 20000
Log.Configure(Log.Memory)
Ids.Configure("bench")
if FileExist(resultPath)
    FileDelete(resultPath)
report := ""
report .= Measure("Loop_SimpleLoop", "Loop_SimpleLoop", '{"Infinite":0,"repeatCount":' passes '}', passes)
report .= Measure("Loop_SimpleLoop, count as a calculation", "Loop_SimpleLoop", '{"Infinite":0,"repeatCount":"' passes ' + 0"}', passes)
report .= Measure("Loop_Condition", "Loop_Condition", '{"Expression":"a_index <= ' passes '","EvaluateOnFirstIteration":1}', passes)
report .= MeasureChain(Min(passes, 3000))
FileAppend(report, resultPath, "UTF-8-RAW")
