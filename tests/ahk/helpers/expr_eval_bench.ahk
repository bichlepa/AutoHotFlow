#Requires AutoHotkey v2.0
#SingleInstance Off
; Measurement for WI-38 (acceptance criterion): evaluating typical parameter expressions with the parse cache.
; Not a unit test. A_Args[1] = result file; one text line per expression and a summary line.
; Usage: python tools/ahkrun.py tests/ahk/helpers/expr_eval_bench.ahk <result file>
#Include ..\lib\ExprTestResolver.ahk
#Include ..\..\..\src\expr\Expr.ahk

resultPath := A_Args[1]
if FileExist(resultPath)
    FileDelete(resultPath)

vars := Map("x", 5, "count", 12, "name", "abc", "done", 0, "price", 2.5, "i", 1, "offset", 3)
o := ExprTestResolver.NewMap()
o["width"] := 7
vars["o"] := o
resolver := ExprTestResolver(vars)
; a log function is installed, as in the engine (nothing is logged by these expressions)
logCount := 0
logFn := (level, text) => logCount += 1

samples := [
    ["expression", "x"],
    ["expression", "x + 1"],
    ["expression", "count * price"],
    ["expression", "count >= 10"],
    ["expression", 'name = "abc"'],
    ["expression", '(count >= 10 and name = "abc") or not done'],
    ["expression", 'count / 4 . " units"'],
    ["expression", "o.width * (offset - 3) + count // 2"],
    ["expression", 'round(price * count, 1) . " total"'],
    ["script", "total := 0`nif count > 3 {`n    total := count * price`n} else {`n    total := 0`n}`nlabel := `"Sum: `" total"]
]
rounds := 5000
lines := ""
sum := 0
sumExpr := 0
for sample in samples {
    kind := sample[1]
    text := sample[2]
    Expr.Evaluate(text, resolver, logFn, kind)   ; fills the parse cache
    start := QpcMs()
    loop rounds
        Expr.Evaluate(text, resolver, logFn, kind)
    each := (QpcMs() - start) / rounds
    sum += each
    if (kind = "expression")
        sumExpr += each
    lines .= Format("{1} {2:7.1f} us per evaluation  {3}`n", kind, each * 1000, StrReplace(text, "`n", "|"))
}
exprCount := samples.Length - 1
lines .= Format("average of the {1} expressions: {2:.1f} us ({3} rounds each, parse cache hit, log function installed)`n", exprCount, sumExpr / exprCount * 1000, rounds)
FileAppend(lines, resultPath, "UTF-8-RAW")

QpcMs() {
    static freq := 0
    if (!freq)
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)
    DllCall("QueryPerformanceCounter", "Int64*", &t := 0)
    return t * 1000 / freq
}
