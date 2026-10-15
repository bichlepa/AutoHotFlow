#Requires AutoHotkey v2.0
; Unit tests for the script form of the expression language (WI-0037, doc/EXPRESSION-LANGUAGE.md section 8).
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\ExprCheck.ahk

S(text) => ExprCheck.Sexp(text, "script")

CheckStatements() {
    Assert.Equal(S("x := 1"), "(script (:= x 1))")
    Assert.Equal(S("a := 1`nb := 2`nc := a + b"), "(script (:= a 1) (:= b 2) (:= c (+ a b)))")
    Assert.Equal(S("a := 1`r`nb := 2"), "(script (:= a 1) (:= b 2))")
    Assert.Equal(S("a := 1`n"), "(script (:= a 1))")
    Assert.Equal(S("`na := 1"), "(script (:= a 1))")
    Assert.Equal(S("a := 1`n`n`nb := 2"), "(script (:= a 1) (:= b 2))")
    Assert.Equal(S("  a := 1`n`tb := 2"), "(script (:= a 1) (:= b 2))")
}

CheckEmptyScripts() {
    Assert.Equal(S(""), "(script)")
    Assert.Equal(S("  `n  "), "(script)")
    Assert.Equal(S("`; nothing"), "(script)")
    Assert.Equal(S("`; one`n`; two`n"), "(script)")
    Assert.Equal(S("{}"), "(script (block))")
}

CheckComments() {
    Assert.Equal(S("x := 1 `; comment`ny := 2"), "(script (:= x 1) (:= y 2))")
    Assert.Equal(S("`; whole line`nx := 1"), "(script (:= x 1))")
    Assert.Equal(S("x := 1`t`; comment"), "(script (:= x 1))")
    Assert.Equal(S('x := "a `; b"'), '(script (:= x "a `; b"))')
    Assert.Equal(S("if 1 `; yes`n x := 1"), "(script (if 1 (:= x 1)))")
}

CheckCalls() {
    Assert.Equal(S('print("hi")'), '(script (call print "hi"))')
    Assert.Equal(S("o.m(1)"), '(script (call (mem o "m") 1))')
    Assert.Equal(S("f()"), "(script (call f))")
    Assert.Equal(S("x := round(2.5)"), "(script (:= x (call round 2.5)))")
}

CheckBlocks() {
    Assert.Equal(S("{`nx := 1`ny := 2`n}"), "(script (block (:= x 1) (:= y 2)))")
    Assert.Equal(S("{ x := 1 }"), "(script (block (:= x 1)))")
    Assert.Equal(S("{`n{`nx := 1`n}`n}"), "(script (block (block (:= x 1))))")
    Assert.Equal(S("{`n`n}"), "(script (block))")
    Assert.Equal(S("a := 1`n{`nb := 2`n}`nc := 3"), "(script (:= a 1) (block (:= b 2)) (:= c 3))")
}

CheckIf() {
    Assert.Equal(S("if 1 = 1`n x := 1"), "(script (if (= 1 1) (:= x 1)))")
    Assert.Equal(S("if (1 = 1)`n x := 1"), "(script (if (= 1 1) (:= x 1)))")
    Assert.Equal(S("if 1 = 1`n x := 1`nelse`n x := 2"), "(script (if (= 1 1) (:= x 1) (:= x 2)))")
    Assert.Equal(S("IF 1`n x := 1`nELSE`n x := 2"), "(script (if 1 (:= x 1) (:= x 2)))")
    Assert.Equal(S("if 1 = 1`n{`n x := 1`n y := 2`n}"), "(script (if (= 1 1) (block (:= x 1) (:= y 2))))")
    Assert.Equal(S("if 1 = 1 { x := 1 }"), "(script (if (= 1 1) (block (:= x 1))))")
    Assert.Equal(S("if 1 = 2 { x := 1 } else { y := 2 }"), "(script (if (= 1 2) (block (:= x 1)) (block (:= y 2))))")
    Assert.Equal(S("if 1 = 2`n{`n x := 1`n}`nelse`n{`n y := 2`n}"), "(script (if (= 1 2) (block (:= x 1)) (block (:= y 2))))")
    Assert.Equal(S("if a`n x := 1`nelse x := 2"), "(script (if a (:= x 1) (:= x 2)))")
    Assert.Equal(S("if a and b`n x := 1"), "(script (if (&& a b) (:= x 1)))")
    Assert.Equal(S("if not a`n x := 1"), "(script (if (! a) (:= x 1)))")
    Assert.Equal(S("if !a`n x := 1"), "(script (if (! a) (:= x 1)))")
    Assert.Equal(S("if (x := 1)`n y := x"), "(script (if (:= x 1) (:= y x)))")
    Assert.Equal(S("if 1`n print(`"a`")"), '(script (if 1 (call print "a")))')
    Assert.Equal(S("a := 1`nif a = 1`n b := 2"), "(script (:= a 1) (if (= a 1) (:= b 2)))")
}

CheckElseIfAndNesting() {
    Assert.Equal(S("if 0`n x := 1`nelse if 1`n x := 2`nelse`n x := 3"), "(script (if 0 (:= x 1) (if 1 (:= x 2) (:= x 3))))")
    Assert.Equal(S("if 1`n if 1`n  x := 1"), "(script (if 1 (if 1 (:= x 1))))")
    ; the else belongs to the nearest if
    Assert.Equal(S("if 1`n if 0`n  x := 1`nelse`n y := 2"), "(script (if 1 (if 0 (:= x 1) (:= y 2))))")
    Assert.Equal(S("if 1`n{`n if 0`n  x := 1`n else`n  x := 2`n}"), "(script (if 1 (block (if 0 (:= x 1) (:= x 2)))))")
    ; after the if, the next statement is not part of it
    Assert.Equal(S("if 1`n x := 1`ny := 2"), "(script (if 1 (:= x 1)) (:= y 2))")
}

CheckContinuation() {
    ; an operator at the end of a line, or an open bracket, continues the statement on the next line
    Assert.Equal(S("x := 1 +`n2"), "(script (:= x (+ 1 2)))")
    Assert.Equal(S("x := (1 +`n 2)"), "(script (:= x (+ 1 2)))")
    Assert.Equal(S("f(1,`n 2)"), "(script (call f 1 2))")
    Assert.Equal(S("x := a and`n b"), "(script (:= x (&& a b)))")
    Assert.Equal(S("x := a[`n1`n]"), "(script (:= x (idx a 1)))")
    Assert.Equal(S("x := `"a`" .`n `"b`""), '(script (:= x (. "a" "b")))')
    Assert.Equal(S("x :=`n 5"), "(script (:= x 5))")
    Assert.Equal(S("if 1 +`n 1 = 2`n x := 1"), "(script (if (= (+ 1 1) 2) (:= x 1)))")
}

CheckNoContinuationOnNextLine() {
    ; an operator at the start of the next line does not continue the previous line (unlike AutoHotkey)
    ExprCheck.ErrorTable([["x := 1`n+ 2", 2, 1, "unary '+'"]], "script")
    res := ExprCheck.Fails("x := 1`n- 2", "script")
    Assert.Equal(res["errors"][1]["line"], 2)
}

CheckPaths() {
    Assert.Equal(S("a%i% := 5"), '(script (:= $("a" i) 5))')
    Assert.Equal(S("a.b := 5"), '(script (:= (mem a "b") 5))')
    Assert.Equal(S("a[i] := 9"), "(script (:= (idx a i) 9))")
    Assert.Equal(S("%n% := 5"), "(script (:= $(n) 5))")
    Assert.Equal(S("b := a`nb.k := 2"), '(script (:= b a) (:= (mem b "k") 2))')
}

CheckKeywordLookalikes() {
    Assert.Equal(S("iffy := 1`nelsewhere := 2`nnotx := 3`nandy := 4`nory := 5"),
        "(script (:= iffy 1) (:= elsewhere 2) (:= notx 3) (:= andy 4) (:= ory 5))")
}

CheckStatementMustDoSomething() {
    ExprCheck.ErrorTable([
        ["1 + 1", 1, 1, "must be an assignment"],
        ["x", 1, 1, "must be an assignment"],
        ['"abc"', 1, 1, "must be an assignment"],
        ["x y", 1, 1, "must be an assignment"],
        ["(x := 1) + 1", 1, 1, "must be an assignment"],
        ["loop 3`n x := 1", 1, 1, "must be an assignment"],
        ["return", 1, 1, "must be an assignment"],
        ["x = 5", 1, 1, "must be an assignment"],
    ], "script")
}

CheckScriptErrors() {
    ExprCheck.ErrorTable([
        ["else`n x := 1", 1, 1, "'else' without a matching 'if'"],
        ["if`n x := 1", 1, 3, "condition is expected"],
        ["if 1", 1, 1, "statement is expected after the condition"],
        ["if 1`n", 1, 1, "statement is expected after the condition"],
        ["if 1`nelse", 2, 1, "'else' without a matching"],
        ["if 1`n x := 1`nelse", 3, 1, "statement is expected after 'else'"],
        ["{`nx := 1", 1, 1, "'{' is not closed"],
        ["}", 1, 1, "no block is open"],
        ["x := 1`n}", 2, 1, "no block is open"],
        ["x := 1 y := 2", 1, 6, "left side of ':='"],
        ["x := 1`ty := 2", 1, 6, "left side of ':='"],
        ["`$x := 1", 1, 1, "unexpected character"],
        ["x ^= 2", 1, 3, "bitwise"],
        ["x++", 1, 2, "increment"],
    ], "script")
}

CheckSeveralErrorsAreCollected() {
    res := ExprCheck.Fails("a := (1`nb := 2`nc := )`nd := 3 +`ne := 5", "script")
    errs := res["errors"]
    Assert.True(errs.Length >= 2, "got " errs.Length)
    ; errors are sorted by position and each one has its own line
    last := 0
    for e in errs {
        Assert.True(e["pos"] > last)
        last := e["pos"]
    }
    ; good lines between bad lines are not reported
    res := ExprCheck.Fails("a := 1`nb := 2 )`nc := 3`nd := ] `ne := 4", "script")
    lines := ""
    for e in res["errors"]
        lines .= e["line"] ","
    Assert.Equal(lines, "2,4,")
}

CheckErrorInIfConditionKeepsTheStructure() {
    ; the faulty condition is reported once; the statements after it are still read
    res := ExprCheck.Fails("if 1 + )`n x := 1`nelse`n y := )", "script")
    Assert.Equal(res["errors"].Length, 2)
    res := ExprCheck.Fails("if ) `n x := 1`nelse`n y := 2", "script")
    Assert.Equal(res["errors"].Length, 1)
}

CheckLineCountsWithCrlf() {
    res := ExprCheck.Fails("a := 1`r`nb := (`r`nc := 3 +", "script")
    Assert.Equal(res["errors"][1]["line"], 3)
    res := ExprCheck.Fails("a := 1`r`nb := )`r`n", "script")
    Assert.Equal(res["errors"][1]["line"], 2)
    Assert.Equal(res["errors"][1]["col"], 6)
    Assert.Equal(res["errors"][1]["lineText"], "b := )")
}

CheckNodePositionsInScripts() {
    res := ExprCheck.Parse("a := 1`nif a`n b := 2", "script")
    ifn := res["ast"]["body"][2]
    Assert.Equal(ifn["type"], "If")
    Assert.Equal(ifn["line"], 2)
    Assert.Equal(ifn["col"], 1)
    Assert.Equal(ifn["pos"], 8)
    Assert.Equal(ifn["end"], 20)
    Assert.Equal(ifn["then"]["line"], 3)
    Assert.Equal(res["ast"]["body"][1]["type"], "ExprStmt")
    Assert.Equal(res["ast"]["body"][1]["expr"]["type"], "Assign")
    Assert.Equal(ifn["else"], "")
}

TestRun.Init()

TestRun.Case("statements, line breaks and indentation", CheckStatements)
TestRun.Case("empty scripts", CheckEmptyScripts)
TestRun.Case("comments", CheckComments)
TestRun.Case("function calls as statements", CheckCalls)
TestRun.Case("blocks", CheckBlocks)
TestRun.Case("if and else", CheckIf)
TestRun.Case("else if and nested ifs", CheckElseIfAndNesting)
TestRun.Case("a statement continues after an operator or in brackets", CheckContinuation)
TestRun.Case("an operator at the start of a line does not continue the line before", CheckNoContinuationOnNextLine)
TestRun.Case("paths and dynamic names as assignment targets", CheckPaths)
TestRun.Case("words that start like keywords are variables", CheckKeywordLookalikes)
TestRun.Case("a statement must be an assignment or a call", CheckStatementMustDoSomething)
TestRun.Case("errors in scripts", CheckScriptErrors)
TestRun.Case("several errors are collected, one per bad line", CheckSeveralErrorsAreCollected)
TestRun.Case("an error in a condition does not hide the rest", CheckErrorInIfConditionKeepsTheStructure)
TestRun.Case("lines are counted with Windows line breaks", CheckLineCountsWithCrlf)
TestRun.Case("positions of statement nodes", CheckNodePositionsInScripts)

TestRun.Finish()
