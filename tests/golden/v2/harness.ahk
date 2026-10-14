#Requires AutoHotkey v2.0
#SingleInstance Off
; Harness of the comparison of the new expression language with the golden data of v1 (WI-39,
; doc/TEST-STRATEGY.md section 7, doc/EXPRESSION-LANGUAGE.md section 15).
;
;   AutoHotkey64.exe harness.ahk <result file> <input file> <mode>
;
; <input file>   JSON: an Array of cases {"id", "kind" ("expression" or "script"), "text", "vars" (name -> value)}.
;                A JSON number is a number, a string a text, an array or object a Map (an array gets the keys "1", "2", ...).
; <mode>         "plain": evaluate the text as it is. "convert": run the v1 converter first and evaluate its result.
; <result file>  one JSON object per line and case: {"id", "conv", "outcome", "value", "errors", "warnings", "missing",
;                "log", "vars"}. "value" and the values in "vars" are {"type", "text"} (objects: {"type":"Map","value":{...}}).
; Runs the cases in this process; no dialog, no file access except the three files.
#Include ..\..\ahk\lib\ExprTestResolver.ahk
#Include ..\..\..\src\expr\Expr.ahk
#Include ..\..\..\src\expr\V1ExprConverter.ahk
#Include ..\..\..\src\core\Json.ahk

Main() {
    if (A_Args.Length < 3) {
        FileAppend("usage: harness.ahk <result file> <input file> <mode>`n", "*")
        ExitApp(2)
    }
    outPath := A_Args[1]
    cases := Json.Parse(FileRead(A_Args[2], "UTF-8"))
    convert := (A_Args[3] = "convert")
    try FileDelete(outPath)
    lines := ""
    for c in cases {
        try {
            rec := RunCase(c, convert)
        } catch as e {
            rec := Map("id", c["id"], "outcome", "harness_failure", "detail", Type(e) ": " e.Message)
        }
        lines .= Json.Stringify(rec) "`n"
    }
    FileAppend(lines, outPath, "UTF-8-RAW")
    ExitApp(0)
}

RunCase(c, convert) {
    text := c["text"]
    kind := c["kind"]
    rec := Map("id", c["id"])
    if (convert) {
        conv := V1ExprConverter.Convert(text, kind)
        rec["conv"] := Map("status", conv["status"], "text", conv["text"], "changes", conv["changes"],
            "messages", conv["messages"])
        text := conv["text"]
    }
    vars := Map()
    for name, value in c.Get("vars", Map())
        vars[name] := ToValue(value)
    resolver := ExprTestResolver(vars)
    log := []
    res := Expr.Evaluate(text, resolver, (level, msg) => log.Push(level ": " msg), kind)
    errors := []
    for e in res["errors"]
        errors.Push(e["message"])
    warnings := []
    for w in res["warnings"]
        warnings.Push(w["message"])
    missing := []
    for m in res["missing"]
        missing.Push(m["name"])
    rec["outcome"] := errors.Length ? "error" : "ok"
    rec["errors"] := errors
    rec["warnings"] := warnings
    rec["missing"] := missing
    rec["log"] := log
    if (!errors.Length)
        rec["value"] := Describe(res["value"])
    out := Map()
    for name, value in resolver.vars
        out[name] := Describe(value)
    rec["vars"] := out
    return rec
}

; JSON value to evaluator value: arrays and objects become case-insensitive Maps with text keys.
ToValue(v) {
    if (v is Array) {
        m := ExprTestResolver.NewMap()
        for item in v
            m[String(A_Index)] := ToValue(item)
        return m
    }
    if (v is Map) {
        m := ExprTestResolver.NewMap()
        for key, item in v
            m[key] := ToValue(item)
        return m
    }
    return v
}

Describe(v) {
    if (v is Map) {
        inner := Map()
        for key, item in v
            inner[key] := Describe(item)
        return Map("type", "Map", "value", inner)
    }
    return Map("type", Type(v), "text", String(v))
}

Main()
