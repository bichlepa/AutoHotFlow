#Requires AutoHotkey v2.0
; Unit tests for the detection of deviation classes in v1 expression texts (WI-0045, src/expr/V1ExprDetect.ahk,
; src/expr/MigrationClasses.ahk). The list of classes against the golden data: tests/test_migration_classes.py.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\expr\V1ExprConverter.ahk
#Include ..\..\src\expr\MigrationClasses.ahk

; The classes the converter reports for a text, sorted and joined with "|".
Classes(text, kind := "expression") {
    res := V1ExprConverter.Convert(text, kind)
    names := []
    for cls in res["classes"]
        names.Push(cls)
    loop names.Length - 1 {
        k := A_Index + 1
        item := names[k]
        m := k - 1
        while (m >= 1 && StrCompare(names[m], item) > 0) {
            names[m + 1] := names[m]
            m -= 1
        }
        names[m + 1] := item
    }
    out := ""
    for i, n in names
        out .= (i > 1 ? "|" : "") n
    return out
}

Show(text) => '"' StrReplace(text, "`n", "\n") '"'

Expect(text, expected, kind := "expression") {
    Assert.Equal(Classes(text, kind), expected, "classes of " Show(text))
}

CheckPlainTextsReportNothing() {
    for text in ["", "x", "x + 1", "a.b.c", "o[1]", "a%i%b", "1.5 * 2", "x := 5", "5 - -3", "a < 3", "a = b",
        '"abc" = x', '"a" . b', "a and b", "a || b", "x := y + 1"]
        Expect(text, "")
}

CheckTextComparison() {
    Expect('x < "abc"', "text comparison")
    Expect('"a" >= x', "text comparison")
    ; a text that is a number compares as a number
    Expect('x < "10"', "")
    Expect('"1" < "2"', "")
}

CheckNumberLikeTexts() {
    Expect('"1.0" = "1"', "number-like texts")
    Expect('"007" == "7"', "number-like texts")
    Expect('"a" = "b"', "")
    Expect('x = "1"', "")
}

CheckLogicAsValue() {
    Expect("x := a && b", "operand as result")
    Expect("x := (a or b) . c", "operand as result")
    Expect("f(a && b)", "operand as result|v1 error")
    ; the whole expression and conditions are not decidable or only a truth value
    Expect("a && b", "")
    Expect("if a && b`n  x := 1", "", "script")
    Expect("!(a && b)", "not")
}

CheckNoShortCircuit() {
    Expect("a and (x := 5)", "assignment value|no short circuit")
    Expect("a || (b := 1)", "assignment value|no short circuit")
    Expect("a and b", "")
}

CheckNot() {
    Expect("not a", "not")
    Expect("!a", "not")
    Expect("a and not b", "not")
    Expect("x := not a", "")
}

CheckKeywordsAndBooleans() {
    Expect("true", "true and false")
    Expect("x := false", "true and false")
    Expect("if", "keyword as name")
    Expect("NOT", "keyword as name")
}

CheckAssignments() {
    Expect("(x := 3) + 1", "assignment value")
    Expect("x := y := 3", "assignment value")
    Expect("a.b := 5", "assignment to a path")
    Expect("a[1] := 5", "assignment to a path")
    Expect("A_Index := 5", "assignment refused")
    ; a statement of a script and the whole expression are no nested value
    Expect("x := 5", "")
    Expect("x := 1`ny := 2", "", "script")
}

CheckNamesAndPaths() {
    Expect("A_PtrSize", "built-in value")
    Expect("a_languagename . x", "built-in value")
    Expect("A_Index", "")
    Expect("global_o.a", "path into global or static")
    Expect("static_list[1]", "path into global or static")
    Expect("global_x", "")
    Expect("x := global_o.k", "path into global or static")
}

CheckLiterals() {
    Expect("0x10", "number literal forms")
    Expect("1e3", "number literal forms")
    Expect("12345678901234567890 + 1", "integer overflow")
    Expect("9223372036854775807 + 1", "")
    Expect("9223372036854775808", "integer overflow")
    Expect("7.0 // 2", "integer division with float")
    Expect("7 // 2", "")
    Expect(Chr(34) "a" Chr(96) "nb" Chr(34), "escape sequence")
    ; the backtick before a character v2 does not know is rewritten away: nothing left to mark
    Expect(Chr(34) "a" Chr(96) "xb" Chr(34), "")
}

CheckV1ErrorAndIgnoredText() {
    Expect("round(2.5)", "v1 error")
    Expect("-x", "v1 error")
    Expect("-5", "")
    Expect("2*-3", "v1 ignores text")
    Expect("x //= 2", "v1 ignores text")
    Expect("m[1][2]", "v1 ignores text")
    Expect("m[1].x", "v1 ignores text")
    Expect("a`nb", "v1 ignores text")
    ; a comment or a string does not count as glued operators
    Expect('"*-" . x', "")
    Expect("x `; a*-b", "")
}

CheckUnsupportedAndUnreadable() {
    Expect("1 <> 2", "unsupported syntax")
    Expect("7 % 3", "unsupported syntax")
    Expect("x ^= 2", "unsupported syntax")
    Expect('"a""b"', "unsupported syntax")
    ; a text the new language cannot read and no class explains
    Expect("1 +", "unreadable text")
    Expect("(a", "unreadable text")
}

CheckRewritesAreNotMarked() {
    for text in ['"a"."b"', "x := 1.50", "007", Chr(34) "a" Chr(96) "xb" Chr(34)]
        Assert.Equal(MigrationClasses.IdsOf(V1ExprConverter.Convert(text)["classes"]).Length, 0, text)
    ; and the IDs of the marked ones: ascending, each once
    ids := MigrationClasses.IdsOf(["text comparison", "operand as result", "no short circuit", "v1 error", "backtick"])
    Assert.Equal(ids.Length, 3)
    Assert.Equal(ids[1], "M-0024")
    Assert.Equal(ids[2], "M-0025")
    Assert.Equal(ids[3], "M-0036")
}

CheckUnknownClassHasNoId() {
    Assert.Equal(MigrationClasses.IdOf("no such class"), "")
    Assert.Equal(MigrationClasses.IdsOf(["no such class"]).Length, 0)
    Assert.Equal(MigrationClasses.IdOf("unreadable text"), "M-0050")
}

TestRun.Init()

TestRun.Case("plain texts report no class", CheckPlainTextsReportNothing)
TestRun.Case("text comparison: a text operand that is not a number", CheckTextComparison)
TestRun.Case("number-like texts: = between two number texts", CheckNumberLikeTexts)
TestRun.Case("operand as result only where the value is used", CheckLogicAsValue)
TestRun.Case("no short circuit: an assignment on the right side", CheckNoShortCircuit)
TestRun.Case("not at the start and behind and/or", CheckNot)
TestRun.Case("true, false and keywords as names", CheckKeywordsAndBooleans)
TestRun.Case("assignment classes", CheckAssignments)
TestRun.Case("built-in values and paths into global or static", CheckNamesAndPaths)
TestRun.Case("literal classes: forms, overflow, float division, escapes", CheckLiterals)
TestRun.Case("v1 error and text that v1 ignored", CheckV1ErrorAndIgnoredText)
TestRun.Case("unsupported syntax and unreadable text", CheckUnsupportedAndUnreadable)
TestRun.Case("rewrite classes are not marked, IDs sorted and unique", CheckRewritesAreNotMarked)
TestRun.Case("unknown class has no ID", CheckUnknownClassHasNoId)

TestRun.Finish()
