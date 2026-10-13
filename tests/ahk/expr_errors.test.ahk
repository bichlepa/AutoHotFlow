#Requires AutoHotkey v2.0
; Unit tests for error records, collecting errors, empty and very long input, limits and robustness
; of the expression parser (WI-37, doc/AUSDRUECKE.md sections 10 and 11).
#Include lib\ExprCheck.ahk

Repeat(s, n) {
    out := ""
    loop n
        out .= s
    return out
}

CheckErrorRecord() {
    res := ExprCheck.Fails("x := 1 + * 2")
    Assert.Equal(res["ok"], 0)
    Assert.Equal(res["kind"], "expression")
    Assert.Equal(res["ast"], "")
    Assert.Equal(res["errors"].Length, 1)
    e := res["errors"][1]
    Assert.Equal(e["message"], "unexpected '*'; an operand is expected")
    Assert.Equal(e["line"], 1)
    Assert.Equal(e["col"], 10)
    Assert.Equal(e["pos"], 10)
    Assert.Equal(e["length"], 1)
    Assert.Equal(e["lineText"], "x := 1 + * 2")
    Assert.Equal(e["marked"], "x := 1 + -> * <- 2")
}

CheckMarkedLineAtTheEnd() {
    e := ExprCheck.Fails("1 +")["errors"][1]
    Assert.Equal(e["length"], 0)
    Assert.Equal(e["marked"], "1 +->  <-")
    Assert.Equal(e["col"], 4)
    e := ExprCheck.Fails("(1 + 2")["errors"][1]
    Assert.Equal(e["marked"], "-> ( <-1 + 2")
}

CheckFormat() {
    res := ExprCheck.Fails("a := 1`nb := )", "script")
    Assert.Equal(Expr.FormatErrors(res), "line 2, column 6: unexpected ')'; an operand is expected`nb := -> ) <-")
    res := ExprCheck.Fails("$ @", "expression")
    Assert.Equal(Expr.FormatErrors(res), "line 1, column 1: unexpected character '$'`n-> $ <- @`nline 1, column 3: unexpected character '@'`n$ -> @ <-")
}

CheckLongLineIsCutInMarkedText() {
    long := Repeat("a + ", 200) ")"
    e := ExprCheck.Fails(long)["errors"][1]
    Assert.True(StrLen(e["marked"]) < 400, "marked line should be cut, length " StrLen(e["marked"]))
    Assert.True(InStr(e["marked"], "-> ) <-"))
    Assert.Equal(e["lineText"], long)
}

CheckColumnsCountCodeUnits() {
    ; a tab is one column, an emoji (outside the BMP) is two
    e := ExprCheck.Fails("`tx := )")["errors"][1]
    Assert.Equal(e["col"], 7)
    e := ExprCheck.Fails("😀 + )")["errors"][1]
    Assert.Equal(e["col"], 6)
    Assert.Equal(e["pos"], 6)
    e := ExprCheck.Fails("`"ä😀`" + )")["errors"][1]
    Assert.Equal(e["col"], 9)
}

CheckLineText() {
    res := ExprCheck.Fails("a := 1`r`nb := 2 )`r`nc := 3", "script")
    e := res["errors"][1]
    Assert.Equal(e["line"], 2)
    Assert.Equal(e["lineText"], "b := 2 )")
    Assert.Equal(e["marked"], "b := 2 -> ) <-")
    ; in the expression form a line break is whitespace, but lines are still counted
    e := ExprCheck.Fails("1 +`n2 +`n)")["errors"][1]
    Assert.Equal(e["line"], 3)
    Assert.Equal(e["col"], 1)
}

CheckSeveralErrorsInExpression() {
    ; the tokenizer reports all unreadable text
    res := ExprCheck.Fails("`$a + @b + #c")
    Assert.Equal(res["errors"].Length, 3)
    Assert.Equal(res["errors"][1]["col"], 1)
    Assert.Equal(res["errors"][2]["col"], 6)
    Assert.Equal(res["errors"][3]["col"], 11)
    ; a tokenizer error and a syntax error together, sorted by position
    res := ExprCheck.Fails("1 + ) + `$")
    Assert.Equal(res["errors"].Length, 2)
    Assert.Equal(res["errors"][1]["col"], 5)
    Assert.Equal(res["errors"][2]["col"], 9)
    ; two bad strings
    res := ExprCheck.Fails('"a``xb" + "c``yd"')
    Assert.Equal(res["errors"].Length, 2)
}

CheckErrorsAreNotRepeated() {
    ; an unreadable token is reported once, not again as a syntax error
    for text in ["`$", "1 + `$", "(`$)", "f(`$, 1)", "`$ + `$", '"abc', '1 + "abc', "12abc + 1"] {
        res := ExprCheck.Fails(text)
        positions := Map()
        for e in res["errors"] {
            Assert.True(!positions.Has(e["pos"]), "position " e["pos"] " reported twice for " text)
            positions[e["pos"]] := 1
        }
    }
}

CheckErrorLimit() {
    text := Repeat("`$ ", 200)
    res := ExprCheck.Fails(text)
    Assert.Equal(res["errors"].Length, 50)
    script := Repeat("x := )`n", 200)
    res := ExprCheck.Fails(script, "script")
    Assert.Equal(res["errors"].Length, 50)
}

CheckEmptyInput() {
    for text in ["", " ", "`t", "`n", "`r`n", "  `n  `n", "`; comment", "`; a`n`; b"] {
        res := ExprCheck.Parse(text)
        Assert.Equal(res["ok"], 1, "expression " ExprCheck.Show(text))
        Assert.Equal(res["ast"]["type"], "Empty")
        Assert.Equal(res["errors"].Length, 0)
        res := ExprCheck.Parse(text, "script")
        Assert.Equal(res["ok"], 1, "script " ExprCheck.Show(text))
        Assert.Equal(res["ast"]["type"], "Script")
        Assert.Equal(res["ast"]["body"].Length, 0)
    }
}

CheckVeryLongString() {
    s := Repeat("0123456789", 100000)    ; one million characters
    res := ExprCheck.Parse('"' s '"')
    Assert.Equal(res["ok"], 1)
    Assert.Equal(StrLen(res["ast"]["value"]), 1000000)
    res := ExprCheck.Parse('"' s)
    Assert.Equal(res["ok"], 0)
    Assert.Equal(res["errors"].Length, 1)
    Assert.True(StrLen(res["errors"][1]["marked"]) < 400)
}

CheckVeryLongName() {
    name := Repeat("n", 100000)
    res := ExprCheck.Parse(name " + 1")
    Assert.Equal(res["ok"], 1)
    Assert.Equal(StrLen(res["ast"]["left"]["name"]), 100000)
}

CheckLongWhitespaceAndComment() {
    res := ExprCheck.Parse(Repeat(" ", 200000) "1" Repeat(" ", 200000) "`; " Repeat("x", 100000))
    Assert.Equal(res["ok"], 1)
    Assert.Equal(res["ast"]["value"], 1)
}

CheckManyTerms() {
    ; a long chain is a tree as high as the chain is long; the height is limited, because AutoHotkey ends the
    ; whole process when the call stack of the evaluator overflows
    ok := ExprCheck.Parse(Repeat("1 + ", 150) "1")
    Assert.Equal(ok["ok"], 1)
    Assert.Equal(ok["ast"]["depth"], 151)
    tooMany := ExprCheck.Parse(Repeat("1 + ", 250) "1")
    Assert.Equal(tooMany["ok"], 0)
    Assert.Equal(tooMany["errors"].Length, 1)
    Assert.True(InStr(tooMany["errors"][1]["message"], "too long or too deeply built"))
    huge := ExprCheck.Parse(Repeat("1 + ", 50000) "1")
    Assert.Equal(huge["ok"], 0)
    Assert.Equal(huge["errors"].Length, 1)
}

CheckManyStatements() {
    ; statements are a list, not a tree: thousands of lines are fine
    res := ExprCheck.Parse(Repeat("x := 1`n", 5000), "script")
    Assert.Equal(res["ok"], 1)
    Assert.Equal(res["ast"]["body"].Length, 5000)
    res := ExprCheck.Parse(Repeat("f(1)`n", 3000) "x := )", "script")
    Assert.Equal(res["ok"], 0)
    Assert.Equal(res["errors"][1]["line"], 3001)
}

CheckManyArguments() {
    res := ExprCheck.Parse("f(" Repeat("1, ", 5000) "1)")
    Assert.Equal(res["ok"], 1)
    Assert.Equal(res["ast"]["args"].Length, 5001)
}

CheckNestingLimit() {
    ; parentheses, brackets, unary operators and blocks nest up to 50 levels; deeper input is an error, not a crash
    ok := ExprCheck.Parse(Repeat("(", 49) "1" Repeat(")", 49))
    Assert.Equal(ok["ok"], 1)
    for text in [Repeat("(", 60) "1" Repeat(")", 60), Repeat("(", 5000) "1", Repeat("!", 60) "1", Repeat("-", 5000) "1",
        Repeat("a[", 60) "1" Repeat("]", 60), Repeat("f(", 60) "1" Repeat(")", 60), Repeat("not ", 60) "1",
        Repeat("x := ", 60) "1", Repeat("%", 60), Repeat("%(", 60)] {
        res := ExprCheck.Parse(text)
        Assert.Equal(res["ok"], 0, "input " ExprCheck.Show(text))
        Assert.True(res["errors"].Length >= 1)
    }
    deep := Repeat("(", 60) "1" Repeat(")", 60)
    Assert.True(InStr(ExprCheck.Parse(deep)["errors"][1]["message"], "nested too deeply"))
    blocks := Repeat("{`n", 60) "x := 1`n" Repeat("}`n", 60)
    res := ExprCheck.Parse(blocks, "script")
    Assert.Equal(res["ok"], 0)
    ifs := Repeat("if 1`n", 60) "x := 1"
    res := ExprCheck.Parse(ifs, "script")
    Assert.Equal(res["ok"], 0)
    ok := ExprCheck.Parse(Repeat("if 1`n", 20) "x := 1", "script")
    Assert.Equal(ok["ok"], 1)
}

; Deterministic pseudo random numbers (a linear congruential generator), so a failure can be repeated.
NextRand(&state) {
    state := Mod(state * 1103515245 + 12345, 2147483648)
    return state
}

CheckNeverThrows() {
    pieces := ["1", "2.5", "0x1F", "x", "abc", "a.b", "a[", "]", "(", ")", "{", "}", "%", " ", " ", "`n", "`t", ",", "+", "-", "*", "/", "//",
        "=", "==", "!=", "!==", "<", ">", "<=", ">=", ":=", "+=", ".=", "!", " not ", " and ", " or ", "&&", "||", " if ", " else ",
        '"', "'", "``", '"s"', "'t'", ";", " `; ", ".", " . ", "?", ":", "&", "|", "^", "~", "`$", "@", "#", "\", "😀", "ä", "true", "f(", "12abc"]
    state := 12345
    count := 0
    loop 3000 {
        n := 1 + Mod(NextRand(&state), 12)
        text := ""
        loop n
            text .= pieces[1 + Mod(NextRand(&state), pieces.Length)]
        for kind in ["expression", "script"] {
            res := ExprCheck.Parse(text, kind)
            count += 1
            if (res["ok"]) {
                Assert.Equal(res["errors"].Length, 0, ExprCheck.Show(text))
                Assert.True(IsObject(res["ast"]), ExprCheck.Show(text))
            } else {
                Assert.Equal(res["ast"], "", ExprCheck.Show(text))
                Assert.True(res["errors"].Length >= 1, ExprCheck.Show(text))
                for e in res["errors"] {
                    Assert.True(e["pos"] >= 1 && e["pos"] <= StrLen(text) + 1, "pos in " ExprCheck.Show(text))
                    Assert.True(e["line"] >= 1 && e["col"] >= 1, ExprCheck.Show(text))
                    Assert.True(e["length"] >= 0 && e["message"] != "", ExprCheck.Show(text))
                    Assert.True(InStr(e["marked"], "-> ") && InStr(e["marked"], " <-"), ExprCheck.Show(text))
                }
            }
        }
    }
    Assert.Equal(count, 6000)
}

CheckSameInputSameResult() {
    ; the parser keeps no state between calls
    a := ExprDump.Sexp(ExprCheck.Parse("a + b * f(1, 2)")["ast"])
    ExprCheck.Parse("(((")
    ExprCheck.Parse("x := ", "script")
    b := ExprDump.Sexp(ExprCheck.Parse("a + b * f(1, 2)")["ast"])
    Assert.Equal(a, b)
}

CheckUnknownKindIsAnInternalError() {
    Assert.Throws(() => Expr.Parse("1", "formula"), ValueError)
}

TestRun.Init()

TestRun.Case("an error record has message, position, length and the marked line", CheckErrorRecord)
TestRun.Case("the marker at the end of the input", CheckMarkedLineAtTheEnd)
TestRun.Case("errors as text", CheckFormat)
TestRun.Case("a very long line is cut around the marker", CheckLongLineIsCutInMarkedText)
TestRun.Case("columns count UTF-16 code units", CheckColumnsCountCodeUnits)
TestRun.Case("line text with Windows line breaks", CheckLineText)
TestRun.Case("several errors in one expression are collected", CheckSeveralErrorsInExpression)
TestRun.Case("an error is not reported twice", CheckErrorsAreNotRepeated)
TestRun.Case("at most 50 errors are collected", CheckErrorLimit)
TestRun.Case("empty input is not an error", CheckEmptyInput)
TestRun.Case("a string of one million characters", CheckVeryLongString)
TestRun.Case("a name of 100000 characters", CheckVeryLongName)
TestRun.Case("long whitespace and comments", CheckLongWhitespaceAndComment)
TestRun.Case("a long chain of operators is limited by the height of the tree", CheckManyTerms)
TestRun.Case("thousands of statements", CheckManyStatements)
TestRun.Case("thousands of arguments", CheckManyArguments)
TestRun.Case("nesting is limited and ends in an error, not in a crash", CheckNestingLimit)
TestRun.Case("random input never throws and always gives consistent results", CheckNeverThrows)
TestRun.Case("the parser keeps no state between calls", CheckSameInputSameResult)
TestRun.Case("an unknown kind is an internal error", CheckUnknownKindIsAnInternalError)

TestRun.Finish()
