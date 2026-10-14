#Requires AutoHotkey v2.0
#SingleInstance Off
; Measurement for WI-42 (acceptance criterion): ctx.EvalParams of an element with 10 parameters of mixed content types
; (expressions with the parse cache, %var% substitution, a variable name, a path, a raw text), in an Executor with
; the stand-in owner, so the context, the variable access and the evaluator are the real ones. Not a unit test.
; A_Args[1] = result file. Usage: python tools/ahkrun.py tests/ahk/helpers/evalparams_bench.ahk <result file>
#Include ExecutorKit.ahk

class Bench_TenParams extends AhfElement {
    static Mode := "inline"
    static rounds := 2000
    static perCall := 0

    static Parameters(ctx) => [
        {type: "Label", label: "Bench"},
        {type: "Edit", id: "Expr", content: "Expression"},
        {type: "Edit", id: "Num", content: "number"},
        {type: "Edit", id: "Int", content: "integer"},
        {type: "Edit", id: "PosInt", content: "positiveInteger"},
        {type: "Edit", id: "Cond", content: ["String", "Expression"], contentID: "CondType"},
        {type: "Edit", id: "Text", content: "String"},
        {type: "Edit", id: "Text2", content: "String", WarnIfEmpty: true},
        {type: "Edit", id: "VarName", content: "VariableName"},
        {type: "File", id: "File"},
        {type: "Edit", id: "Raw", content: "RawString"}
    ]

    static Run(ctx, params) {
        ctx.EvalParams(params)                  ; fills the parse cache
        start := QpcMs()
        loop Bench_TenParams.rounds
            ctx.EvalParams(params)
        Bench_TenParams.perCall := (QpcMs() - start) / Bench_TenParams.rounds
        ctx.Finish("normal")
    }
}
ElementRegistry.Register(Bench_TenParams)

QpcMs() {
    static freq := 0
    if (!freq)
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)
    DllCall("QueryPerformanceCounter", "Int64*", &t := 0)
    return t * 1000 / freq
}

resultPath := A_Args[1]
if FileExist(resultPath)
    FileDelete(resultPath)
; global variables, so that no element has to set them first (a lookup costs the same in every scope)
pars := '{"Expr":"global_x + 1","Num":"global_price * global_count","Int":"global_count // 2","PosInt":"global_count",'
    . '"Cond":"global_count >= 10 and global_name = \"abc\"","CondType":"expression","Text":"Total: %global_name%",'
    . '"Text2":"%global_count% items","VarName":"var_%global_i%","File":"out\\%global_name%.txt","Raw":"raw text"}'
owner := NewOwner(FlowText([El("b", "Bench_TenParams", pars)], [Conn("c1", "t0", "b")]))
for name, value in Map("x", 5, "price", 2.5, "count", 12, "name", "abc", "i", 3)
    owner.vars.Global["global_" name] := value
owner.executor.StartFlow(owner.flows.Get("f"))
owner.Drive()
if (!Bench_TenParams.perCall)
    FileAppend("the bench element did not run: " (Log.memoryLines.Length ? Log.memoryLines[-1]["text"] : "") "`n", resultPath, "UTF-8-RAW")
else
    FileAppend(Format("EvalParams with 10 parameters: {1:.3f} ms per call ({2} rounds, parse cache hit)`n"
        , Bench_TenParams.perCall, Bench_TenParams.rounds), resultPath, "UTF-8-RAW")
