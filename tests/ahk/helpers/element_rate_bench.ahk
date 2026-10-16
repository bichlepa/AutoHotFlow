#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, StdOut
; Measurement for WI-0066 (REQ-EXE-170): how many element executions per second the engine does with inline elements,
; and how many instances per second a flood of starts with policy parallel gives. Not a unit test. The owner counts the
; events instead of keeping them. An element execution is one evt.element.state with state "running" (every start of an
; element, the trigger of an instance included, the same point that the runaway guard counts).
; A_Args[1] = result file, A_Args[2] = passes of each loop (default 20000), A_Args[3] = instances of the flood (default 5000).
; Usage:
;   python tools/ahkrun.py --timeout 600 tests/ahk/helpers/element_rate_bench.ahk <result file> [passes] [instances]
#Include ExecutorKit.ahk
#Include ..\..\..\src\elements\Default\_includes_engine.ahk

class RateOwner extends EngineOwner {
    Emit(to, msgType, payload) {
        if (msgType = "evt.element.state" && payload["state"] = "running")
            this.runs := (this.HasProp("runs") ? this.runs : 0) + 1
    }
}

QpcMs() {
    static freq := 0
    if (!freq)
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)
    DllCall("QueryPerformanceCounter", "Int64*", &t := 0)
    return t * 1000 / freq
}

; A loop (repeatCount passes) whose body is one element of the given class with the given parameters.
BodyLoopFlow(bodyCls, bodyPars, passes) {
    els := Trig() . ',"L":{"ID":"L","type":"Loop","class":"Loop_SimpleLoop","pars":{"Infinite":0,"repeatCount":'
        . passes . '},"HeightOfVerticalBar":"280"}' . "," . El("B", bodyCls, bodyPars)
    cons := '"c1":{"ID":"c1","from":"t0","to":"L","toPart":"HEAD","ConnectionType":"normal","type":"Connection"}'
        . ',"c2":{"ID":"c2","from":"L","to":"B","fromPart":"HEAD","ConnectionType":"normal","type":"Connection"}'
        . ',"c3":{"ID":"c3","from":"B","to":"L","toPart":"TAIL","ConnectionType":"normal","type":"Connection"}'
    return '{"name":"f","flowSettings":{"ExecutionPolicy":"default","strictTypes":true},"formatVersion":2,"allElements":{' els '},"allConnections":{' cons '}}'
}

MeasureLoop(label, bodyCls, bodyPars, passes) {
    owner := RateOwner()
    owner.flows.Load("f", BodyLoopFlow(bodyCls, bodyPars, passes))
    owner.runs := 0
    start := QpcMs()
    owner.executor.StartFlow(owner.flows.Get("f"))
    while (owner.executor.IsExecuting("f")) {
        owner.Drive()
        if (QpcMs() - start > 480000)
            return label ": gave up after 480 s`n"
    }
    ms := QpcMs() - start
    for line in Log.memoryLines {
        if (line["level"] = "a0" || line["level"] = "f0")
            return label ": log entry " line["level"] ": " line["text"] "`n"
    }
    return Format("{1}: {2} passes, {3} element executions in {4:.0f} ms = {5:.0f} element executions per second, {6:.1f} us per execution`n"
        , label, passes, owner.runs, ms, owner.runs * 1000 / ms, ms * 1000 / owner.runs)
}

; A flood: n starts of one flow (trigger and one element that finishes at once), policy parallel, as fast as the caller can.
MeasureFlood(n) {
    owner := RateOwner()
    owner.flows.Load("f", FlowText([El("e1", "Default.Action_Do_nothing")], [Conn("c1", "t0", "e1")], "parallel"))
    rec := owner.flows.Get("f")
    owner.runs := 0
    start := QpcMs()
    loop n {
        owner.executor.StartFlow(rec)
        if (Mod(A_Index, 100) = 0)
            owner.Drive()
    }
    while (owner.executor.IsExecuting("f")) {
        owner.Drive()
        if (QpcMs() - start > 480000)
            return "flood: gave up after 480 s`n"
    }
    ms := QpcMs() - start
    return Format("Flood, policy parallel: {1} instances (trigger + Action_Do_nothing) in {2:.0f} ms = {3:.0f} instances per second, {4} element executions ({5:.0f} per second)`n"
        , n, ms, n * 1000 / ms, owner.runs, owner.runs * 1000 / ms)
}

resultPath := A_Args[1]
passes := A_Args.Length >= 2 ? Integer(A_Args[2]) : 20000
instances := A_Args.Length >= 3 ? Integer(A_Args[3]) : 5000
Log.Configure(Log.Memory)
Ids.Configure("bench")
if FileExist(resultPath)
    FileDelete(resultPath)
report := ""
report .= MeasureLoop("Loop with body Action_Do_nothing", "Default.Action_Do_nothing", "{}", passes)
report .= MeasureLoop("Loop with body Action_New_variable", "Default.Action_New_variable", '{"Varname":"v","VarValue":"1","onlyIfNotExist":0}', passes)
report .= MeasureFlood(instances)
FileAppend(report, resultPath, "UTF-8-RAW")
