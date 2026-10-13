#Requires AutoHotkey v2.0
#SingleInstance Off
; Measurement for WI-37 task 4: parsing a typical expression without and with the parse cache.
; Not a unit test. A_Args[1] = result file; one text line per expression and a summary line.
; Usage: python tools/ahkrun.py tests/ahk/helpers/expr_bench.ahk <result file>
#Include ..\..\..\src\expr\Expr.ahk

resultPath := A_Args[1]
if FileExist(resultPath)
    FileDelete(resultPath)

samples := [
    ["expression", "x + 1"],
    ["expression", 'round(a.b * 2.5, 2) . " units"'],
    ["expression", '(count >= 10 and name = "abc") or not done'],
    ["expression", "A_Index // 2 + list[i + 1].width * (offset - 3)"],
    ["script", "total := 0`nif count > 3 {`n    total := count * price`n} else {`n    total := 0`n}`nlabel := `"Sum: `" total"]
]
rounds := 2000
lines := ""
sumNoCache := 0
sumCache := 0
for sample in samples {
    kind := sample[1]
    text := sample[2]
    start := QpcMs()
    loop rounds
        Expr.Parse(text, kind, false)
    noCache := (QpcMs() - start) / rounds
    Expr.cache.Clear()
    Expr.Parse(text, kind)
    start := QpcMs()
    loop rounds
        Expr.Parse(text, kind)
    withCache := (QpcMs() - start) / rounds
    sumNoCache += noCache
    sumCache += withCache
    lines .= Format("{1} {2:6.1f} us uncached  {3:6.2f} us cached  {4:6.0f}x  {5} chars  {6}`n"
        , kind, noCache * 1000, withCache * 1000, noCache / withCache, StrLen(text), StrReplace(text, "`n", "|"))
}
lines .= Format("average {1:.1f} us uncached, {2:.2f} us cached ({3} rounds each)`n", sumNoCache / samples.Length * 1000, sumCache / samples.Length * 1000, rounds)

; 2000 different texts: fill the cache up to its limit, then 1000 more (the oldest are removed)
Expr.cache.Clear()
start := QpcMs()
loop 3000
    Expr.Parse("x" A_Index " + y * " A_Index)
lines .= Format("3000 different texts (cache limit {1}): {2:.1f} ms, cache holds {3}`n", Expr.cache.maxEntries, QpcMs() - start, Expr.cache.Count)
FileAppend(lines, resultPath, "UTF-8-RAW")

QpcMs() {
    static freq := 0
    if (!freq)
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)
    DllCall("QueryPerformanceCounter", "Int64*", &t := 0)
    return t * 1000 / freq
}
