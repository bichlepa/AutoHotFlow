#Requires AutoHotkey v2.0
; Unit tests for variables, assignment, functions, the script form, the result object and robustness of the
; evaluator (WI-0038, doc/EXPRESSION-LANGUAGE.md sections 4, 7, 8 and 14).
#Include lib\EvalCheck.ahk
#Include ..\..\src\core\Json.ahk

ThrowBroken(*) {
    throw Error("broken on purpose")
}

class BrokenResolver {
    Has(path) => ThrowBroken()
    Get(path) => 1
    Set(path, value) => 1
}

NewObject(pairs*) {
    m := ExprTestResolver.NewMap()
    loop pairs.Length // 2
        m[pairs[2 * A_Index - 1]] := pairs[2 * A_Index]
    return m
}

CheckVariableRead() {
    vars := Map("x", 5, "name", "Bob", "f", 1.5)
    EvalCheck.Table([
        ["x", 5],
        ["X + 1", 6],
        ['name . "!"', "Bob!"],
        ["f * 2", 3.0],
        ["x * x", 25],
    ], vars)
    ; the resolver is asked with Has and then Get, with the path as an Array
    res := EvalCheck.Run("x", vars)
    Assert.Equal(res["resolver"].calls.Length, 2)
    Assert.Equal(res["resolver"].calls[1], "has x")
    Assert.Equal(res["resolver"].calls[2], "get x")
}

CheckMissingVariable() {
    ; as in v1: the empty text and a log entry; the caller decides whether it matters (listed under "missing")
    res := EvalCheck.Run("y")
    Assert.Equal(res["value"], "")
    Assert.Equal(res["errors"].Length, 0)
    Assert.Equal(res["warnings"].Length, 0)
    Assert.Equal(res["missing"].Length, 1)
    Assert.Equal(res["missing"][1]["name"], "y")
    Assert.Equal(res["missing"][1]["line"], 1)
    Assert.Equal(res["missing"][1]["col"], 1)
    Assert.Equal(res["log"].Length, 1)
    Assert.Equal(res["log"][1], "f0: Retrieving variable 'y' failed. It does not exist")
    ; used in a calculation the empty text is a TypeError as for any empty text (E0025)
    res := EvalCheck.Run("y + 1")
    Assert.Equal(res["value"], "")
    Assert.Equal(res["missing"].Length, 1)
    Assert.Equal(res["warnings"].Length, 1)
    ; as a text it is simply empty
    Assert.Equal(EvalCheck.Value('"a" y "b"'), "ab")
    ; every read is reported
    res := EvalCheck.Run("y . z . y")
    Assert.Equal(res["missing"].Length, 3)
}

CheckPaths() {
    vars := Map("o", NewObject("b", 3, "list", NewObject("1", "first", "2", "second"), "k", "b"), "k", "b", "i", 2)
    EvalCheck.Table([
        ["o.b", 3],
        ["O.B", 3],
        ['o["b"]', 3],
        ["o.list.1", "first"],
        ["o.list[1]", "first"],
        ["o.list[i]", "second"],
        ["o.%k%", 3],
        ["o[k]", 3],
        ["o.list[i - 1]", "first"],
    ], vars)
    res := EvalCheck.Run("o.b", vars)
    Assert.Equal(res["resolver"].calls[1], "has o.b")
    ; a member that does not exist is a missing variable named by its dotted path
    res := EvalCheck.Run("o.nothing", vars)
    Assert.Equal(res["value"], "")
    Assert.Equal(res["missing"][1]["name"], "o.nothing")
    Assert.Equal(res["log"][1], "f0: Retrieving variable 'o.nothing' failed. It does not exist")
    ; a member of a value that is not an object does not exist either
    res := EvalCheck.Run("k.x", vars)
    Assert.Equal(res["value"], "")
    Assert.Equal(res["missing"].Length, 1)
}

CheckDynamicNames() {
    vars := Map("n", 2, "a2", 10, "name", "n", "a3", 30, "bad", "1x", "a1b", "mid")
    EvalCheck.Table([
        ["a%n%", 10],
        ["%name%", 2],
        ["a%n + 1%", 30],
        ["A%N%", 10],
        ["a1%name%", ""],
    ], vars)
    EvalCheck.Table([["a1%'b'%", "mid"]], vars)
    EvalCheck.Fails("%bad%", "not a valid variable name", 1, 1, vars)
    EvalCheck.Fails("x := %bad%", "not a valid variable name", 1, 6, vars)
    ; assignment to a dynamic name
    res := EvalCheck.Run("a%n% := 7", vars)
    Assert.Equal(res["resolver"].vars["a2"], 7)
}

CheckAssignment() {
    res := EvalCheck.Run("x := 5")
    Assert.Equal(res["value"], 5)
    Assert.Equal(res["resolver"].vars["x"], 5)
    res := EvalCheck.Run("x := y := 3")
    Assert.Equal(res["resolver"].vars["x"], 3)
    Assert.Equal(res["resolver"].vars["y"], 3)
    Assert.Equal(EvalCheck.Value("(x := 3) + 1"), 4)
    res := EvalCheck.Run('s := "a" 1 + 1')
    Assert.Equal(res["resolver"].vars["s"], "a2")
    ; the value of the right side is evaluated once and a failed right side is "" (warning)
    res := EvalCheck.Run('x := "" + 1')
    Assert.Equal(res["warnings"].Length, 1)
    Assert.Equal(res["resolver"].vars["x"], "")
}

CheckCompoundAssignment() {
    vars := Map("x", 8, "t", "ab")
    res := EvalCheck.Run("x += 2", vars)
    Assert.Equal(res["value"], 10)
    Assert.Equal(res["resolver"].vars["x"], 10)
    res := EvalCheck.Run("x -= 2", vars)
    Assert.Equal(res["resolver"].vars["x"], 6)
    res := EvalCheck.Run("x *= 2", vars)
    Assert.Equal(res["resolver"].vars["x"], 16)
    ; E0029 applies to /=
    res := EvalCheck.Run("x /= 2", vars)
    Assert.Equal(res["resolver"].vars["x"], 4)
    res := EvalCheck.Run("x /= 3", vars)
    Assert.True(res["resolver"].vars["x"] is Float)
    res := EvalCheck.Run("x //= 3", vars)
    Assert.Equal(res["resolver"].vars["x"], 2)
    res := EvalCheck.Run('t .= "cd"', vars)
    Assert.Equal(res["resolver"].vars["t"], "abcd")
    Assert.Equal(res["value"], "abcd")
    ; a calculation that fails gives "" and the variable gets "" (as in v1); 8 += "" is a TypeError in AutoHotkey v2
    res := EvalCheck.Run('t += 1', vars)
    Assert.Equal(res["warnings"].Length, 1)
    Assert.Equal(res["value"], "")
    Assert.Equal(res["resolver"].vars["t"], "")
    ; += on a variable that does not exist: reading it is a missing variable, then "" + 1 is a TypeError
    res := EvalCheck.Run("n += 1")
    Assert.Equal(res["missing"].Length, 1)
    Assert.Equal(res["warnings"].Length, 1)
    ; .= on a variable that does not exist works (an empty text can be joined)
    res := EvalCheck.Run('n .= "a"')
    Assert.Equal(res["missing"].Length, 1)
    Assert.Equal(res["warnings"].Length, 0)
    Assert.Equal(res["resolver"].vars["n"], "a")
}

CheckAssignToPaths() {
    vars := Map("o", NewObject("b", 3))
    res := EvalCheck.Run("o.b := 4", vars)
    Assert.Equal(res["resolver"].vars["o"]["b"], 4)
    res := EvalCheck.Run("o.c := 5", vars)
    Assert.Equal(res["resolver"].vars["o"]["c"], 5)
    res := EvalCheck.Run('o["d"] := 6', vars)
    Assert.Equal(res["resolver"].vars["o"]["d"], 6)
    res := EvalCheck.Run("o.b += 10", vars)
    Assert.Equal(res["resolver"].vars["o"]["b"], 14)
    res := EvalCheck.Run("p.q := 1")
    Assert.Equal(res["resolver"].vars["p"]["q"], 1)
    Assert.Equal(res["resolver"].calls[1], "set p.q")
}

CheckResolverRefusal() {
    ; ExprResolveError from the resolver is an error with position, the value is ""
    res := EvalCheck.Fails("ro_x := 1", "read-only", 1, 1)
    Assert.Equal(res["value"], "")
    res := EvalCheck.Fails("1 + (ro_x := 1)", "read-only", 1, 5)
    ; setting a member of a text
    vars := Map("t", "text")
    EvalCheck.Fails("t.x := 1", "no members", 1, 1, vars)
}

CheckOtherResolverErrorsAreInternal() {
    ; only ExprResolveError is a user error; anything else leaves the evaluator
    Assert.Throws(() => Expr.Evaluate("x", BrokenResolver()), Error)
}

CheckAssignTargets() {
    EvalCheck.Fails("object().x := 1", "only a variable", 1, 1)
}

CheckMembersOfValues() {
    EvalCheck.Table([['object("a", 1).a', 1], ['object("a", 1).A', 1]])
    res := EvalCheck.Run("object().a")
    Assert.Equal(res["value"], "")
    Assert.Equal(res["missing"].Length, 1)
    EvalCheck.Fails("round(1.5).x", "no members", 1, 1)
}

CheckRound() {
    EvalCheck.Table([
        ["round(2.5)", 3],
        ["round(-2.5)", -3],
        ["round(2.4)", 2],
        ["ROUND(2.5)", 3],
        ["round( 2.5 )", 3],
        ["round(3)", 3],
        ["round(1234, -2)", 1200],
        ["round(1+1.6)", 3],
        ["round(round(2.5))", 3],
        ["round(2.5) + 1", 4],
        ['round("2.5")', 3],
    ])
    EvalCheck.TextTable([
        ["round(2.567, 2)", "2.57"],
        ["round(1/3, 2)", "0.33"],
        ['round("2.567", 1)', "2.6"],
    ])
    EvalCheck.Warns('round("abc")', "'round' failed")
    EvalCheck.Warns('round("")', "'round' failed")
}

CheckObjectAndPrint() {
    res := EvalCheck.Run("o := object()")
    o := res["value"]
    Assert.True(o is Map)
    Assert.Equal(o.CaseSense, "Off")
    res := EvalCheck.Run('o := object("Key", 1, "b", 2)')
    Assert.Equal(res["value"]["key"], 1)
    Assert.Equal(res["value"].Count, 2)
    ; the object is a value of the variable and its members are reached through the resolver
    res := EvalCheck.Run("o := object(`"Key`", 5)`nx := o.KEY", "", "script")
    Assert.Equal(res["value"], 5)
    EvalCheck.Warns('object("a")', "'object' failed")
    ; print goes to the log, the value is empty
    res := EvalCheck.Run('print("a", 1, 2.5)')
    Assert.Equal(res["value"], "")
    Assert.Equal(res["log"].Length, 1)
    Assert.Equal(res["log"][1], "f1: print: a 1 2.5")
    res := EvalCheck.Run("print()")
    Assert.Equal(res["log"][1], "f1: print: ")
    res := EvalCheck.Run('print(object())')
    Assert.Equal(res["log"][1], "f1: print: <Map>")
}

CheckMod() {
    EvalCheck.Table([["mod(7, 3)", 1], ["mod(-7, 3)", -1], ["mod(7, -3)", 1], ["mod(6.5, 2)", 0.5]])
}

CheckFunctionErrors() {
    EvalCheck.Fails("foo(1)", "unknown function 'foo'", 1, 1)
    EvalCheck.Fails("1 + foo(1)", "unknown function 'foo'", 1, 5)
    EvalCheck.Fails("round()", "function 'round' takes 1 to 2 argument(s), got 0", 1, 1)
    EvalCheck.Fails("round(1, 2, 3)", "got 3", 1, 1)
    EvalCheck.Fails("mod(1)", "takes 2 argument(s), got 1", 1, 1)
    EvalCheck.Fails("o.method(1)", "methods cannot be called", 1, 1)
    EvalCheck.Fails("x := 1`nfoo()", "unknown function", 2, 1, "", "script")
    ; the error does not stop the rest of the expression
    res := EvalCheck.Run('"a" . foo() . "b"')
    Assert.Equal(res["value"], "ab")
    Assert.Equal(res["errors"].Length, 1)
}

CheckDynamicFunctionName() {
    EvalCheck.Table([["%f%(2.5)", 3]], Map("f", "round"))
    EvalCheck.Fails("%f%(2.5)", "unknown function 'nofunc'", 1, 1, Map("f", "nofunc"))
}

CheckFunctionTableIsExtensible() {
    ExprFunctions.Register("double_test", (ctx, x) => x * 2, 1, 1)
    ExprFunctions.Register("join_test", (ctx, parts*) => parts.Length, 0, -1)
    EvalCheck.Table([["double_test(4)", 8], ["DOUBLE_TEST(4)", 8], ["join_test()", 0], ["join_test(1, 2, 3)", 3]])
    EvalCheck.Warns('double_test("x")', "'double_test' failed")
    EvalCheck.Fails("double_test()", "got 0", 1, 1)
}

CheckScriptForm() {
    res := EvalCheck.Run("a := 1`nb := 2`nc := a + b", "", "script")
    Assert.Equal(res["value"], 3)
    Assert.Equal(res["resolver"].vars["c"], 3)
    Assert.Equal(EvalCheck.Value("", "", "script"), "")
    Assert.Equal(EvalCheck.Value("; only a comment`n`n", "", "script"), "")
    Assert.Equal(EvalCheck.Value("a := 1`r`nb := 2`r`n", "", "script"), 2)
    ; a call as a statement
    res := EvalCheck.Run('print("hi")', "", "script")
    Assert.Equal(res["value"], "")
    Assert.Equal(res["log"][1], "f1: print: hi")
}

CheckIfElse() {
    src := "x := 5`nif x > 3 {`n  y := 1`n} else {`n  y := 2`n}"
    res := EvalCheck.Run(src, "", "script")
    Assert.Equal(res["resolver"].vars["y"], 1)
    Assert.Equal(res["value"], 1)
    res := EvalCheck.Run("x := 1`nif x > 3 {`n  y := 1`n} else {`n  y := 2`n}", "", "script")
    Assert.Equal(res["resolver"].vars["y"], 2)
    ; else if chain
    chain := "if x = 1 {`n r := `"one`"`n} else if x = 2 {`n r := `"two`"`n} else {`n r := `"many`"`n}"
    Assert.Equal(EvalCheck.Value(chain, Map("x", 2), "script"), "two")
    Assert.Equal(EvalCheck.Value(chain, Map("x", 1), "script"), "one")
    Assert.Equal(EvalCheck.Value(chain, Map("x", 9), "script"), "many")
    ; without else and a false condition the value is 0, as in v1
    res := EvalCheck.Run("if 0 {`n x := 1`n}", "", "script")
    Assert.Equal(res["value"], 0)
    Assert.Equal(res["resolver"].vars.Has("x"), false)
    ; a statement instead of a block
    Assert.Equal(EvalCheck.Value("if 1`n x := 7", "", "script"), 7)
    ; the condition is the value of the operand (E0031) and uses the truth rules of AutoHotkey
    Assert.Equal(EvalCheck.Value('if "" || "a" {`n x := 1`n} else {`n x := 2`n}', "", "script"), 1)
    Assert.Equal(EvalCheck.Value('if "0" {`n x := 1`n} else {`n x := 2`n}', "", "script"), 2)
    Assert.Equal(EvalCheck.Value('if "abc" {`n x := 1`n} else {`n x := 2`n}', "", "script"), 1)
    ; a condition with an error is false
    res := EvalCheck.Run('if "a" < "b" {`n x := 1`n} else {`n x := 2`n}', "", "script")
    Assert.Equal(res["value"], 2)
    Assert.Equal(res["warnings"].Length, 1)
    ; nested
    nested := "if 1 {`n if 0 {`n  x := 1`n } else {`n  x := 2`n }`n}"
    Assert.Equal(EvalCheck.Value(nested, "", "script"), 2)
}

CheckBlocks() {
    Assert.Equal(EvalCheck.Value("{ x := 1 }", "", "script"), 1)
    Assert.Equal(EvalCheck.Value("{`n a := 1`n b := 2`n}", "", "script"), 2)
    Assert.Equal(EvalCheck.Value("{ }", "", "script"), 0)
    Assert.Equal(EvalCheck.Value("{ { x := 3 } }", "", "script"), 3)
}

CheckResultObject() {
    res := EvalCheck.Run("1 + 1")
    for key in ["value", "errors", "warnings", "missing"]
        Assert.True(res.Has(key), key)
    Assert.Equal(res["errors"].Length, 0)
    ; a syntax error: the parse errors are the errors, the value is "", nothing is evaluated
    res := EvalCheck.Run("x := 1 +")
    Assert.Equal(res["value"], "")
    Assert.True(res["errors"].Length >= 1)
    Assert.Equal(res["errors"][1]["line"], 1)
    Assert.True(res["errors"][1]["col"] > 0)
    Assert.True(res["errors"][1]["message"] != "")
    Assert.Equal(res["resolver"].calls.Length, 0)
    res := EvalCheck.Run("x := 1`ny := (", "", "script")
    Assert.Equal(res["value"], "")
    Assert.Equal(res["resolver"].calls.Length, 0)
    ; an empty expression is the empty text
    Assert.Equal(EvalCheck.Value(""), "")
    Assert.Equal(EvalCheck.Value("  " Chr(59) " comment"), "")
    ; error records with the source text have the marked line
    res := EvalCheck.Fails("1 + foo(2)", "unknown function", 1, 5)
    Assert.Equal(res["errors"][1]["marked"], "1 + -> foo <-(2)")
    Assert.Equal(res["errors"][1]["lineText"], "1 + foo(2)")
}

CheckNoLogFunction() {
    ; no logFn: nothing is logged and nothing fails
    res := Expr.Evaluate('("" + 1) . y', ExprTestResolver())
    Assert.Equal(res["warnings"].Length, 1)
    Assert.Equal(res["missing"].Length, 1)
    ; a logFn that throws does not break the evaluation
    res := Expr.Evaluate('"" + 1', ExprTestResolver(), ThrowBroken)
    Assert.Equal(res["warnings"].Length, 1)
}

CheckEvaluationIsRepeatable() {
    ; the parse cache hands out the same tree; evaluating does not change it
    resolver := ExprTestResolver(Map("x", 1))
    first := Expr.Evaluate("x := x + 1", resolver)
    second := Expr.Evaluate("x := x + 1", resolver)
    third := Expr.Evaluate("x := x + 1", resolver)
    Assert.Equal(first["value"], 2)
    Assert.Equal(second["value"], 3)
    Assert.Equal(third["value"], 4)
}

CheckDeepTrees() {
    ; the evaluator walks the tree recursively: trees at the limit of the parser must not harm it
    text := "1"
    loop 190
        text .= " + 1"
    Assert.Equal(EvalCheck.Value(text), 191)
    text := ""
    loop 45
        text .= "("
    text .= "7"
    loop 45
        text .= ")"
    Assert.Equal(EvalCheck.Value(text), 7)
    text := ""
    loop 45
        text .= "- "
    text .= "7"
    Assert.Equal(EvalCheck.Value(text), -7)
    text := ""
    loop 45
        text .= "{`n"
    text .= "x := 4`n"
    loop 45
        text .= "}`n"
    Assert.Equal(EvalCheck.Value(text, "", "script"), 4)
    text := ""
    loop 45
        text .= "if 1`n"
    text .= "x := 5"
    Assert.Equal(EvalCheck.Value(text, "", "script"), 5)
    ; beyond the limit the parser reports an error and the evaluator evaluates nothing
    text := "1"
    loop 400
        text .= " + 1"
    res := EvalCheck.Run(text)
    Assert.True(res["errors"].Length >= 1)
    Assert.Equal(res["value"], "")
}

; Every text of the golden cases (including the ones that fail in v1) and random garbage: no exception.
CheckNeverThrowsOnGoldenTexts() {
    count := 0
    vars := Map("x", 1, "a", 2, "b", "text", "o", NewObject("k", 1))
    loop files, A_ScriptDir "\..\golden\cases\*.json" {
        ; one case per line; the "vars" of some cases repeat a key, which the strict Json parser refuses,
        ; so only the kind and the text are cut out of the line
        for line in StrSplit(FileRead(A_LoopFileFullPath, "UTF-8"), "`n", "`r") {
            if (!RegExMatch(line, '^\{"id": "([^"]*)", "kind": "([^"]*)", "text": ("(?:[^"\\]|\\.)*")', &m))
                continue
            kind := m[2]
            if (kind != "expression" && kind != "script" && kind != "replace")
                continue
            c := Map("id", m[1], "text", Json.Parse(m[3]))
            for form in (kind = "script" ? ["script"] : ["expression", "script"]) {
                try {
                    Expr.Evaluate(c["text"], ExprTestResolver(vars), (l, t) => 0, form)
                } catch as e {
                    throw AssertFailed("case " c["id"] " (" form ") threw " Type(e) ": " e.Message)
                }
                count += 1
            }
        }
    }
    Assert.True(count > 2000, "evaluated only " count " texts")
}

CheckNeverThrowsOnRandomTexts() {
    pieces := ["x", "y", "a.b", "o.k", "1", "0", "2.5", '"s"', '""', '"a"', "+", "-", "*", "/", "//", "<", ">", "<=", ">=", "=", "==", "!=",
        "!", ".", " ", " ", "(", ")", "[", "]", ":=", "+=", ".=", "/=", "&&", "||", "and", "or", "not", "round(", "object(", "print(",
        "mod(", ",", "%", "x%a%", "`n", "{", "}", "if ", "else ", "0x10", "1e3", "-9223372036854775808", "9223372036854775807"]
    seed := 12345
    resolver := ExprTestResolver(Map("x", 1, "a", 2, "o", NewObject("k", 1)))
    loop 3000 {
        text := ""
        seed := Mod(seed * 1103515245 + 12345, 2147483648)
        len := 1 + Mod(seed >> 8, 14)
        loop len {
            seed := Mod(seed * 1103515245 + 12345, 2147483648)
            text .= pieces[1 + Mod(seed >> 8, pieces.Length)]
        }
        for form in ["expression", "script"] {
            try {
                Expr.Evaluate(text, resolver, "", form)
            } catch as e {
                throw AssertFailed("text " EvalCheck.Show(text) " (" form ") threw " Type(e) ": " e.Message)
            }
        }
    }
}

TestRun.Init()

TestRun.Case("reading variables", CheckVariableRead)
TestRun.Case("a variable that does not exist gives the empty text and an f0 log", CheckMissingVariable)
TestRun.Case("paths with dots and brackets", CheckPaths)
TestRun.Case("dynamic variable names", CheckDynamicNames)
TestRun.Case("assignment", CheckAssignment)
TestRun.Case("compound assignment", CheckCompoundAssignment)
TestRun.Case("assignment to paths", CheckAssignToPaths)
TestRun.Case("a resolver refusal is an error with position", CheckResolverRefusal)
TestRun.Case("other resolver exceptions are internal errors", CheckOtherResolverErrorsAreInternal)
TestRun.Case("only variables can be assigned to", CheckAssignTargets)
TestRun.Case("members of values that are not variables", CheckMembersOfValues)
TestRun.Case("function round", CheckRound)
TestRun.Case("functions object and print", CheckObjectAndPrint)
TestRun.Case("function mod", CheckMod)
TestRun.Case("errors in function calls", CheckFunctionErrors)
TestRun.Case("function named by a dynamic name", CheckDynamicFunctionName)
TestRun.Case("the function table is extensible", CheckFunctionTableIsExtensible)
TestRun.Case("script form: statements in order and the last value", CheckScriptForm)
TestRun.Case("script form: if and else", CheckIfElse)
TestRun.Case("script form: blocks", CheckBlocks)
TestRun.Case("result object and syntax errors", CheckResultObject)
TestRun.Case("logging is optional and a failing log function is ignored", CheckNoLogFunction)
TestRun.Case("evaluating the same cached tree again", CheckEvaluationIsRepeatable)
TestRun.Case("deep trees at the limit of the parser", CheckDeepTrees)
TestRun.Case("no exception for any text of the golden cases", CheckNeverThrowsOnGoldenTexts)
TestRun.Case("no exception for random texts", CheckNeverThrowsOnRandomTexts)

TestRun.Finish()
