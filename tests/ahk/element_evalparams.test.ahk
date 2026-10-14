#Requires AutoHotkey v2.0
; Parameter evaluation and the variable functions of ctx (WI-42, doc/ELEMENT-API-V2.md section 3 and 3.1): the rules
; of v1 x_AutoEvaluateParameters per content type, the flow option strictTypes (E34), the f1 entries of the evaluator.
; The test element Action_TestExprParams (src/elements/skeleton) evaluates its parameters with ctx.EvalParams and
; leaves the result in global_evalresult; it runs in an Executor with the stand-in owner (no processes).
#Include helpers\ExecutorKit.ahk
#Include ..\..\src\elements\skeleton\Action_TestExprParams.ahk

; Calls a ctx function inside a running element: Probe.onRun of Test_Count is the hook. Returns what fn returned, or
; the ElementError as "error: <message>".
class CtxProbe {
    static result := ""
}

; Global variables of every case.
SetGlobals(owner) {
    g := owner.vars.Global
    g["global_n"] := 5
    g["global_f"] := 2.5
    g["global_t"] := "text"
    g["global_s5"] := " 5 "
    g["global_neg"] := -3
    o := Map()
    o.CaseSense := "Off"
    o["k"] := "v"
    o[1] := 2
    g["global_obj"] := o
}

; The flow "e": trigger t0, then element a1 of class cls with the parameters pars (a Map). formatVersion 2, so the
; texts are not converted from v1 syntax on load; strictTypes as given.
EvalFlow(pars, strict := false, cls := "Action_TestExprParams", settings := "") {
    el := Map("ID", "a1", "type", "action", "class", cls, "pars", pars, "name", "a")
    tr := Map("ID", "t0", "type", "trigger", "class", "trigger_Manual", "pars", Map())
    fs := Map("ExecutionPolicy", "parallel", "strictTypes", strict ? Json.True : Json.False)
    if (settings is Map) {
        for k, v in settings
            fs[k] := v
    }
    conn := Map("ID", "c1", "from", "t0", "to", "a1", "type", "Connection", "ConnectionType", "normal")
    root := Map("name", "e", "formatVersion", 2, "flowSettings", fs, "allElements", Map("t0", tr, "a1", el)
        , "allConnections", Map("c1", conn))
    return Json.Stringify(root)
}

; Runs the element once and returns Map: result ("normal" or "exception"), message, values (Map id -> Map type,
; value; empty after an exception), owner.
Eval(pars, strict := false, cls := "Action_TestExprParams", settings := "") {
    Probe.Reset()
    Log.memoryLines := []
    owner := EngineOwner()
    owner.flows.Load("e", EvalFlow(pars, strict, cls, settings))
    SetGlobals(owner)
    owner.executor.StartFlow(owner.flows.Get("e"))
    owner.Drive()
    return Outcome(owner)
}

Outcome(owner) {
    out := Map("result", "", "message", "", "values", Map(), "owner", owner)
    for ev in owner.events {
        if (ev["type"] != "evt.element.state" || ev["payload"]["elementId"] != "a1")
            continue
        state := ev["payload"]["state"]
        if (state = "exception") {
            out["result"] := "exception"
            out["message"] := ev["payload"].Get("message", "")
        } else if (state = "finished") {
            out["result"] := "normal"
        }
    }
    text := owner.vars.Global.Get("global_evalresult", "")
    if (text != "")
        out["values"] := Json.Parse(text)
    return out
}

P(pairs*) {
    m := Map()
    loop pairs.Length // 2
        m[pairs[2 * A_Index - 1]] := pairs[2 * A_Index]
    return m
}

; The value and the AutoHotkey type of one evaluated parameter.
Val(r, id) {
    v := r["values"]
    if (!v.Has(id))
        throw AssertFailed("parameter '" id "' is not in the result (" r["result"] ": " r["message"] ")")
    return v[id]["value"]
}
TypeOf(r, id) => r["values"][id]["type"]

; The element ended with an exception whose message starts with text.
Fails(r, text) {
    Assert.Equal(r["result"], "exception", "result")
    Assert.Equal(SubStr(r["message"], 1, StrLen(text)), text, "message: " r["message"])
}

Ok(r) {
    Assert.Equal(r["result"], "normal", "result (" r["message"] ")")
}

HasLogLine(level, parts*) {
    for line in Log.memoryLines {
        if (line["level"] != level)
            continue
        all := true
        for part in parts {
            if (!InStr(line["source"] " " line["text"] " " line["flowId"], part))
                all := false
        }
        if (all)
            return true
    }
    return false
}

; ---- content types ---------------------------------------------------------------------------------------------

CheckString() {
    r := Eval(P("Text", "a %global_t% b %global_n%", "Json", "%global_obj%"))
    Ok(r)
    Assert.Equal(Val(r, "Text"), "a text b 5")
    Assert.Equal(TypeOf(r, "Text"), "String")
    ; contentConvertObjects: the JSON text of the object; without it an object is the empty text
    Assert.True(InStr(Val(r, "Json"), '"k": "v"'), Val(r, "Json"))
    r := Eval(P("Text", "[%global_obj%]"))
    Assert.Equal(Val(r, "Text"), "[]")
}

CheckStringWarnIfEmpty() {
    Fails(Eval(P("Needed", "%global_missing%")), "String 'Needed' is empty")
    Ok(Eval(P("Text", "")))                      ; without WarnIfEmpty an empty text is fine
}

CheckExpression() {
    r := Eval(P("Expr", "global_n * 2", "Num", "global_n / 2", "Int", "global_n + 1"))
    Ok(r)
    Assert.Equal(Val(r, "Expr"), 10)
    Assert.Equal(TypeOf(r, "Expr"), "Integer")
    Assert.Equal(Val(r, "Num"), 2.5)
    Assert.Equal(TypeOf(r, "Num"), "Float")
    Assert.Equal(Val(r, "Int"), 6)
    ; an object as the result of an expression
    r := Eval(P("Expr", "global_obj"))
    Assert.Equal(TypeOf(r, "Expr"), "Map")
}

CheckExpressionError() {
    r := Eval(P("Expr", "1 +"))
    Fails(r, "An error occured while parsing expression '1 +'`n`nline 1, column")
}

CheckExpressionWarnIfEmpty() {
    Fails(Eval(P("NeededExpr", '""')), "Result of expression '`"`"' is empty")
    Ok(Eval(P("Expr", '""')))
}

CheckNumber() {
    Fails(Eval(P("Num", '"abc"')), "Result of expression '`"abc`"' is not a number")
    Ok(Eval(P("Num", "global_s5")))              ; a text with spaces around a number is a number (v1 too)
    Ok(Eval(P("Num", '""')))                     ; empty without WarnIfEmpty: no check (v1)
    Fails(Eval(P("PosNum", "global_neg")), "Result of expression 'global_neg' is not a positive number or zero")
    r := Eval(P("PosNum", "0"))
    Ok(r)
    Assert.Equal(Val(r, "PosNum"), 0)
}

CheckInteger() {
    Fails(Eval(P("Int", "global_f")), "Result of expression 'global_f' is not an integer")
    Fails(Eval(P("Int", "1.5 * 2")), "Result of expression '1.5 * 2' is not an integer")   ; 3.0 is a Float
    Ok(Eval(P("Int", "4 / 2")))                  ; E29: an exact division of integers is an Integer
    Ok(Eval(P("Int", '"0x10"')))
    Fails(Eval(P("PosInt", "0")), "Result of expression '0' is not a positive number")
    Fails(Eval(P("PosInt", "global_f")), "Result of expression 'global_f' is not an integer")
    Fails(Eval(P("PosIntOrZero", "global_neg")), "Result of expression 'global_neg' is not a positive number or zero")
    r := Eval(P("PosInt", "3", "PosIntOrZero", "0"))
    Ok(r)
    Assert.Equal(Val(r, "PosInt"), 3)
}

CheckTheLastFailingCheckGivesTheMessage() {
    ; v1 runs the checks one after the other: -1.5 is not an integer and not >= 1; the last message counts
    Fails(Eval(P("PosInt", "-1.5")), "Result of expression '-1.5' is not a positive number")
    ; a text that is not a number compares alphabetically in v1: "abc" >= 1 is true, "-abc" >= 1 is false
    Fails(Eval(P("PosInt", '"abc"')), "Result of expression '`"abc`"' is not an integer")
    Fails(Eval(P("PosInt", '"-abc"')), "Result of expression '`"-abc`"' is not a positive number")
}

CheckVariableName() {
    r := Eval(P("VarName", "my%global_t%", "NeededVar", "x_1"))
    Ok(r)
    Assert.Equal(Val(r, "VarName"), "mytext")
    Fails(Eval(P("VarName", "1abc")), "Variable name '1abc' is not valid.")
    Fails(Eval(P("VarName", "a.b")), "Variable name 'a.b' is not valid.")
    Ok(Eval(P("VarName", "")))                   ; empty without WarnIfEmpty is not checked
    Fails(Eval(P("NeededVar", "")), "Variable name '' is not valid.")
}

CheckRawString() {
    r := Eval(P("Raw", "%global_t% 1 + 1", "Script", "x := 1", "Condition", "a = 1"))
    Ok(r)
    Assert.Equal(Val(r, "Raw"), "%global_t% 1 + 1")
    Assert.Equal(Val(r, "Script"), "x := 1")     ; no content type: unchanged
    Assert.Equal(Val(r, "Condition"), "a = 1")
    Fails(Eval(P("NeededRaw", "")), "Parameter 'NeededRaw' is empty")
    ; a number in the flow file stays a number
    r := Eval(P("Raw", 7))
    Assert.Equal(TypeOf(r, "Raw"), "Integer")
}

CheckFileAndFolder() {
    wd := A_MyDocuments "\AutoHotFlow"
    r := Eval(P("File", "sub\%global_t%.txt", "Folder", "C:\abs\dir", "NeededFile", "\\srv\share\f"))
    Ok(r)
    Assert.Equal(Val(r, "File"), wd "\sub\text.txt")
    Assert.Equal(Val(r, "Folder"), "C:\abs\dir")
    Assert.Equal(Val(r, "NeededFile"), "\\srv\share\f")
    ; empty: relative, as in v1
    r := Eval(P("File", ""))
    Assert.Equal(Val(r, "File"), wd "\")
    Fails(Eval(P("NeededFile", "%global_missing%")), "String 'NeededFile' is empty")
    ; the working directory of the flow
    r := Eval(P("File", "f.txt"), false, , P("DefaultWorkingDir", 0, "WorkingDir", "D:\work"))
    Assert.Equal(Val(r, "File"), "D:\work\f.txt")
}

CheckSelectableContent() {
    r := Eval(P("Either", "global_n + 1", "EitherType", "expression"))
    Assert.Equal(Val(r, "Either"), 6)
    r := Eval(P("Either", "global_n + 1", "EitherType", "String"))
    Assert.Equal(Val(r, "Either"), "global_n + 1")
    r := Eval(P("Either", "%global_n%"))         ; no choice stored: contentDefault (string)
    Assert.Equal(Val(r, "Either"), "5")
}

CheckLabelsAndButtonsAreSkippedMissingParametersGetTheDefault() {
    r := Eval(P())
    Ok(r)
    Assert.True(!r["values"].Has("Pick"), "a button is not evaluated")
    Assert.Equal(Val(r, "Expr"), 1)              ; default "1", an expression
    Assert.Equal(Val(r, "PosIntOrZero"), 0)
    Assert.Equal(Val(r, "Needed"), "x")
    Assert.Equal(Val(r, "Raw"), "")
}

CheckSkipListAndMore() {
    ; a skipped parameter is not evaluated: not in the result, and its error does not count
    r := Eval(P("Expr", "1 +", "Num", "2", "Skip", "Expr, Text"))
    Ok(r)
    Assert.True(!r["values"].Has("Expr") && !r["values"].Has("Text"))
    Assert.Equal(Val(r, "Num"), 2)
    ; EvalMoreParams evaluates a skipped one afterwards
    r := Eval(P("Expr", "global_n", "Skip", "Expr", "More", "Expr"))
    Ok(r)
    Assert.Equal(Val(r, "Expr"), 5)
    Fails(Eval(P("Expr", "1 +", "Skip", "Expr", "More", "Expr")), "An error occured while parsing expression '1 +'")
    ; an assignment in a skipped parameter does not run (inline)
    r := Eval(P("Expr", "global_side := 1", "Skip", "Expr"))
    Assert.True(!r["owner"].vars.Global.Has("global_side"))
}

CheckTheFirstErrorStops() {
    ; Expr comes before Num in Parameters(): its error is reported, Num is not evaluated (its assignment does not run)
    r := Eval(P("Expr", "1 +", "Num", "global_after := 1"))
    Fails(r, "An error occured while parsing expression '1 +'")
    Assert.True(!r["owner"].vars.Global.Has("global_after"))
}

; ---- strict mode (E34) ------------------------------------------------------------------------------------------

CheckTypeErrorInCompatibilityMode() {
    r := Eval(P("Expr", "global_t + 1", "Num", "global_missing < 3"))
    Ok(r)
    Assert.Equal(Val(r, "Expr"), "")             ; E25: the empty text and a warning
    Assert.Equal(Val(r, "Num"), "")              ; F-105: false in v2, without the counter set
    ; the f1 warning names the flow, the element and the parameter
    Assert.True(HasLogLine("f1", "element a1", "parameter 'Expr'", "Expression warning", "e"), "f1 warning of Expr")
    Assert.True(HasLogLine("f1", "element a1", "parameter 'Num'", "Expression warning"), "f1 warning of Num")
    ; the missing variable as in v1 (f0), also with the parameter
    Assert.True(HasLogLine("f0", "element a1", "parameter 'Num'", "Retrieving variable 'global_missing' failed"))
}

CheckTypeErrorInStrictMode() {
    Fails(Eval(P("Expr", "global_t + 1"), true), "An error occured while parsing expression 'global_t + 1'")
    r := Eval(P("Num", "global_missing < 3"), true)
    Fails(r, "An error occured while parsing expression 'global_missing < 3'")
    Assert.True(InStr(r["message"], "'<' failed"), r["message"])
    ; what is no type error is the same in both modes
    r := Eval(P("Expr", "global_n * 2", "Text", "%global_missing%"), true)
    Ok(r)
    Assert.Equal(Val(r, "Expr"), 10)
    Assert.Equal(Val(r, "Text"), "")
}

; ---- variable functions of ctx ----------------------------------------------------------------------------------

; Runs fn(ctx) inside an inline element (Test_Count of ExecutorKit) and returns its value, or "error: <message>".
InElement(fn, strict := false) {
    Probe.Reset()
    Log.memoryLines := []
    owner := EngineOwner()
    owner.flows.Load("e", EvalFlow(Map(), strict, "Test_Count"))
    SetGlobals(owner)
    CtxProbe.result := "<not run>"
    Probe.onRun := (ctx) => CtxProbe.result := CallSafe(fn, ctx)
    owner.executor.StartFlow(owner.flows.Get("e"))
    owner.Drive()
    return CtxProbe.result
}

CallSafe(fn, ctx) {
    try {
        return fn(ctx)
    } catch ElementError as e {
        return "error: " e.Message
    }
}

CheckReplaceAndEvaluate() {
    Assert.Equal(InElement((ctx) => ctx.ReplaceVariables("n=%global_n% o=%global_obj%")), "n=5 o=")
    Assert.True(InStr(InElement((ctx) => ctx.ReplaceVariables("%global_obj%", true)), '"k": "v"'))
    Assert.Equal(InElement((ctx) => ctx.EvaluateExpression("global_n + global_f")), 7.5)
    Assert.Equal(InElement((ctx) => ctx.EvaluateScript("a := 2`nb := a * global_n")), 10)
    msg := InElement((ctx) => ctx.EvaluateExpression("1 +"))
    Assert.Equal(SubStr(msg, 1, 22), "error: line 1, column ", msg)
    ; a type error: the empty text in compatibility mode, an error in strict mode
    Assert.Equal(InElement((ctx) => ctx.EvaluateExpression("global_t * 2")), "")
    msg := InElement((ctx) => ctx.EvaluateExpression("global_t * 2"), true)
    Assert.True(InStr(msg, "error: ") = 1 && InStr(msg, "'*' failed"), msg)
}

CheckVarFunctions() {
    Assert.Equal(InElement((ctx) => ctx.GetVarType("global_obj")), "object")
    Assert.Equal(InElement((ctx) => ctx.GetVarType("global_n")), "normal")
    Assert.Equal(InElement((ctx) => ctx.GetVarType("nothing")), "")
    Assert.Equal(InElement((ctx) => ctx.GetVarLocation("global_n")), "global")
    Assert.Equal(InElement((ctx) => ctx.GetVarLocation("A_Now")), "builtin")
    Assert.Equal(InElement((ctx) => ctx.VarLocation("global_n")), "global")
    Assert.Equal(InElement((ctx) => ctx.CheckVarName("ok_1")), 1)
    Assert.Equal(InElement((ctx) => ctx.CheckVarName("1a")), 0)
    Assert.Equal(InElement((ctx) => ctx.CheckVarName("")), 0)
    Assert.Equal(InElement((ctx) => ctx.CheckVarName("a b")), 0)
}

ExportImport(ctx) {
    ctx.SetVar("x", 1)
    ctx.SetVar("y", "two")
    m := ctx.ExportInstanceVars()
    m["x"] := 99                                 ; a copy: the variable does not change
    ctx.ImportInstanceVars(Map("z", 3, "A_odd", "a", "bad name", 4))
    return ctx.GetVar("x") "|" m["y"] "|" ctx.GetVar("z") "|" ctx.GetVarLocation("A_odd") "|" ctx.GetVarLocation("bad name")
}

CheckExportAndImportInstanceVars() {
    ; x keeps 1; z is set; an A_ name is set as an instance variable as in v1 (but A_ names are looked up in the loop,
    ; thread and built-in variables, so it cannot be found); a name with a space is skipped
    Assert.Equal(InElement(ExportImport), "1|two|3||")
}

TestRun.Init()

TestRun.Case("String: %var% substitution, contentConvertObjects", CheckString)
TestRun.Case("String: WarnIfEmpty", CheckStringWarnIfEmpty)
TestRun.Case("Expression: value and type of the result", CheckExpression)
TestRun.Case("Expression: a syntax error ends the element with the v1 text", CheckExpressionError)
TestRun.Case("Expression: WarnIfEmpty", CheckExpressionWarnIfEmpty)
TestRun.Case("number and positiveNumber", CheckNumber)
TestRun.Case("integer, positiveInteger, positiveIntegerOrZero", CheckInteger)
TestRun.Case("the checks run one after the other as in v1; texts compare alphabetically", CheckTheLastFailingCheckGivesTheMessage)
TestRun.Case("VariableName: substitution and name check", CheckVariableName)
TestRun.Case("RawString and no content type: unchanged; WarnIfEmpty", CheckRawString)
TestRun.Case("file and folder: substitution and full path in the working directory", CheckFileAndFolder)
TestRun.Case("content type selected by the user (contentID)", CheckSelectableContent)
TestRun.Case("labels and buttons are skipped, missing parameters get the default", CheckLabelsAndButtonsAreSkippedMissingParametersGetTheDefault)
TestRun.Case("skip list and EvalMoreParams", CheckSkipListAndMore)
TestRun.Case("the first error ends the evaluation", CheckTheFirstErrorStops)
TestRun.Case("compatibility mode: a type error is the empty text and an f1 warning with flow, element, parameter", CheckTypeErrorInCompatibilityMode)
TestRun.Case("strict mode: a type error ends the element with exception", CheckTypeErrorInStrictMode)
TestRun.Case("ctx.ReplaceVariables, EvaluateExpression, EvaluateScript", CheckReplaceAndEvaluate)
TestRun.Case("ctx.GetVarType, GetVarLocation, CheckVarName", CheckVarFunctions)
TestRun.Case("ctx.ExportInstanceVars and ImportInstanceVars", CheckExportAndImportInstanceVars)

TestRun.Finish()
