#Requires AutoHotkey v2.0
#SingleInstance Off
; Harness of the comparison of v2 with the golden data of v1 (WI-0039, WI-0040, doc/TEST-STRATEGY.md section 7,
; doc/EXPRESSION-LANGUAGE.md sections 15 and 18).
;
;   AutoHotkey64.exe harness.ahk <result file> <input file> <mode>
;
; <input file>   JSON: an Array of cases {"id", "kind", "text", "vars", "common", "location", "value", "convertObjects"}.
;                kind: "expression", "script", "replace", "checkname", "destination", "varget", "varset".
;                vars: scope ("instance", "thread", "loop", "global", "static") -> name -> value. A JSON number is a
;                number, a string a text, an array or object an object (VarValues.Import: a Map, a list has the keys 1..n).
;                common: the place without instance and thread (the editor and the manager; v1 *_Common).
; <mode>         "plain": evaluate the text as it is. "convert": run the v1 converter first (expression and script).
; <result file>  one JSON object per line and case: {"id", "conv", "outcome", "value", "errors", "warnings", "missing",
;                "log", "vars"}. "value" and the values in "vars" are {"type", "text"} (objects: {"type":"Map","value":{...}});
;                "vars" is scope -> name -> value.
; Runs the cases in this process with the variable model of the engine (src/engine/vars); no dialog, no file access
; except the three files.
#Include ..\..\..\src\expr\Expr.ahk
#Include ..\..\..\src\expr\V1ExprConverter.ahk
#Include ..\..\..\src\core\Json.ahk
#Include ..\..\..\src\engine\core\Instance.ahk
#Include ..\..\..\src\engine\vars\VarAccess.ahk

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
            rec := Map("id", c["id"], "outcome", "harness_failure", "detail", Type(e) ": " e.Message " (line " e.Line ")")
        }
        lines .= Json.Stringify(rec) "`n"
    }
    FileAppend(lines, outPath, "UTF-8-RAW")
    ExitApp(0)
}

; The stand-ins of the v1 harness for the values that depend on the application (tests/golden/v1/harness.ahk).
GoldenEnv() => Map("flowId", "flow1", "elementId", "element1", "flowName", "GoldenFlow", "elementName", "GoldenElement"
    , "workingDir", "<flow working dir>", "ahfVersion", "golden")

RunCase(c, convert) {
    text := c["text"]
    kind := c["kind"]
    rec := Map("id", c["id"])
    if (convert && (kind = "expression" || kind = "script")) {
        conv := V1ExprConverter.Convert(text, kind)
        again := V1ExprConverter.Convert(conv["text"], kind)
        rec["conv"] := Map("status", conv["status"], "text", conv["text"], "changes", conv["changes"],
            "messages", conv["messages"], "idempotent", (again["text"] == conv["text"]) ? 1 : 0)
        text := conv["text"]
    }
    store := EngineVars()
    inst := Instance("inst1", "flow1")
    thread := ThreadState("thr1", "inst1", "element1")
    tables := Map("instance", inst.Vars, "thread", thread.Vars, "loop", thread.Loops.Visible, "global", store.Global
        , "static", store.Static("flow1"))
    vars := c.Get("vars", Map())
    if (vars is Map) {
        for scope, entries in vars {
            for name, value in entries
                tables[scope][name] := VarValues.Import(value)
        }
    }
    common := c.Get("common", 0) ? true : false
    log := []
    logFn := (level, msg) => log.Push(level ": " msg)
    access := common ? VarAccess(store, "", "", GoldenEnv(), logFn) : VarAccess(store, inst, thread, GoldenEnv(), logFn)
    errors := []
    warnings := []
    missing := []
    location := String(c.Get("location", ""))
    switch kind {
        case "expression", "script":
            res := Expr.Evaluate(text, access, logFn, kind)
            for e in res["errors"]
                errors.Push(e["message"])
            for w in res["warnings"]
                warnings.Push(w["message"])
            for m in res["missing"]
                missing.Push(m["name"])
            value := res["value"]
        case "replace":
            value := access.Replace(text, c.Get("convertObjects", 0) ? true : false, missing)
        case "checkname":
            value := VarNames.Check(text)
        case "destination":
            value := VarNames.Destination(text, location, common)
        case "varget":
            if (!access.HasVar(text))
                missing.Push(text)
            value := access.GetVar(text)
        case "varset":
            access.SetVar(text, c.Get("value", ""), location)
            value := ""
        default:
            throw ValueError("unknown kind " kind)
    }
    rec["outcome"] := errors.Length ? "error" : "ok"
    rec["errors"] := errors
    rec["warnings"] := warnings
    rec["missing"] := missing
    rec["log"] := log
    if (!errors.Length)
        rec["value"] := Describe(value)
    out := Map()
    for scope, table in tables {
        entries := Map()
        for name, v in table
            entries[name] := Describe(v)
        out[scope] := entries
    }
    rec["vars"] := out
    return rec
}

Describe(v) {
    if (v is Map) {
        inner := Map()
        for key, item in v
            inner[String(key)] := Describe(item)
        return Map("type", "Map", "value", inner)
    }
    return Map("type", Type(v), "text", String(v))
}

Main()
