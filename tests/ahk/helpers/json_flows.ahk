#Requires AutoHotkey v2.0
#SingleInstance Off
; Helper for tests/test_json_flows.py (WI-0002). Not a unit test: no TestRun, no summary from TestRun.
; A_Args[1] = result file (JSON lines), A_Args[2] = output directory,
; A_Args[3...] = directories with flow files (only *.json directly inside, not recursive).
; For each file: parse the bytes, write with indent 2 into the output directory, parse that text
; again, write it again and compare both texts. One result line per file, then a summary line.
#Include ..\..\..\src\core\Json.ahk

resultPath := A_Args[1]
outDir := A_Args[2]
try FileDelete(resultPath)
DirCreate(outDir)
count := 0
Loop A_Args.Length - 2 {
    dir := A_Args[A_Index + 2]
    Loop Files, dir "\*.json" {
        name := A_LoopFileName
        fullPath := A_LoopFileFullPath
        count++
        record := Map("type", "file", "name", name)
        try {
            value := Json.ParseBytes(FileRead(fullPath, "RAW"))
            text := Json.Stringify(value, 2)
            FileAppend(text, outDir "\" name, "UTF-8-RAW")
            again := Json.Stringify(Json.Parse(text), 2)
            record["status"] := (again == text) ? "ok" : "mismatch"
            record["chars"] := StrLen(text)
        } catch as e {
            record["status"] := "error"
            record["message"] := Type(e) ": " e.Message
        }
        FileAppend(Json.Stringify(record) "`n", resultPath, "UTF-8-RAW")
    }
}
FileAppend(Json.Stringify(Map("type", "summary", "files", count)) "`n", resultPath, "UTF-8-RAW")
