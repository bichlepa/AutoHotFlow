#Requires AutoHotkey v2.0
#SingleInstance Off
; Evaluator side of the expression oracle (WI-0044, doc/TEST-STRATEGY.md section 8, tools/expr_oracle.py).
;
;   AutoHotkey64.exe eval_harness.ahk <result file> <input file>
;
; <input file>   JSON: {"env": {name: typed value}, "cases": [{"id", "text"}]}. A typed value is ["int", "5"],
;                ["float", "1.5"], ["str", "abc"] or ["map", {key: typed value}] (the numbers are texts, so that
;                the whole range of Integer and Float survives the JSON parser).
; <result file>  one JSON object per line and case: {"id", "type", "text", "errors", "warnings", "missing"}.
;                "type" and "text" describe the value: Type() and String() (an object has the text "").
;                "errors", "warnings": Arrays of messages. "missing": Array of names.
; Every case is evaluated with its own resolver, filled from env. No dialog, no file access except the two files.
#Include ..\..\src\expr\Expr.ahk
#Include ..\..\src\core\Json.ahk
#Include ..\ahk\lib\ExprTestResolver.ahk

Main() {
    if (A_Args.Length < 2) {
        FileAppend("usage: eval_harness.ahk <result file> <input file>`n", "*")
        ExitApp(2)
    }
    input := Json.Parse(FileRead(A_Args[2], "UTF-8"))
    try FileDelete(A_Args[1])
    lines := ""
    for c in input["cases"] {
        try {
            rec := RunCase(c, input["env"])
        } catch as e {
            rec := Map("id", c["id"], "harness_failure", Type(e) ": " e.Message " (line " e.Line ")")
        }
        lines .= Json.Stringify(rec) "`n"
    }
    FileAppend(lines, A_Args[1], "UTF-8-RAW")
    ExitApp(0)
}

; typed value -> AHK value
Decode(v) {
    switch v[1] {
        case "int":
            return Integer(v[2])
        case "float":
            return Float(v[2])
        case "str":
            return v[2]
        case "map":
            m := Map()
            m.CaseSense := "Off"
            for key, item in v[2]
                m[key] := Decode(item)
            return m
    }
    throw ValueError("unknown type " v[1])
}

RunCase(c, env) {
    vars := Map()
    for name, v in env
        vars[name] := Decode(v)
    res := Expr.Evaluate(c["text"], ExprTestResolver(vars))
    value := res["value"]
    rec := Map("id", c["id"], "type", Type(value), "text", IsObject(value) ? "" : String(value))
    errors := []
    for e in res["errors"]
        errors.Push(e["message"])
    warnings := []
    for w in res["warnings"]
        warnings.Push(w["message"])
    missing := []
    for m in res["missing"]
        missing.Push(m["name"])
    rec["errors"] := errors
    rec["warnings"] := warnings
    rec["missing"] := missing
    return rec
}

Main()
