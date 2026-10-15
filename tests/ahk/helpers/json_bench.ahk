#Requires AutoHotkey v2.0
#SingleInstance Off
; Benchmark for WI-0002: 10,000 envelopes of about 300 bytes, parsed and written again.
; Not a unit test. A_Args[1] = result file (one JSON line of type "bench").
; Times are measured with A_TickCount (about 15 ms resolution), only recorded, no hard gate.
#Include ..\..\..\src\core\Json.ahk

resultPath := A_Args[1]
filler := ""
loop 200
    filler .= "x"

; Build the input texts first, outside the measurement.
texts := []
loop 10000 {
    envelope := Map("v", 2, "type", "evt.element.state", "id", "engine#" A_Index, "from", "engine",
        "to", "editor:flow1", "seq", A_Index,
        "payload", Map("element", "element0000000001", "state", "running", "note", filler))
    texts.Push(Json.Stringify(envelope))
}

start := A_TickCount
parsed := []
for text in texts
    parsed.Push(Json.Parse(text))
parseMs := A_TickCount - start

start := A_TickCount
written := []
for value in parsed
    written.Push(Json.Stringify(value))
stringifyMs := A_TickCount - start

same := 0
loop texts.Length {
    if (written[A_Index] == texts[A_Index])
        same++
}
FileAppend(Json.Stringify(Map("type", "bench", "messages", texts.Length, "chars_each", StrLen(texts[1]),
    "parse_ms", parseMs, "stringify_ms", stringifyMs, "roundtrip_ok", same)) "`n", resultPath, "UTF-8-RAW")
