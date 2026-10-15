#Requires AutoHotkey v2.0
#Include Assert.ahk
#Include ExprDump.ahk
#Include ..\..\..\src\expr\Expr.ahk

; Test helpers for the expression language (tests/ahk/expr_*.test.ahk).
class ExprCheck {
    ; Parses without the cache. Returns the result Map.
    static Parse(text, kind := "expression") => Expr.Parse(text, kind, false)

    ; Parses text, requires success and returns the tree as an S-expression text (see ExprDump).
    static Sexp(text, kind := "expression") {
        res := ExprCheck.Parse(text, kind)
        if (!res["ok"])
            throw AssertFailed("input " ExprCheck.Show(text) " should parse but failed: " StrReplace(Expr.FormatErrors(res), "`n", " | "))
        return ExprDump.Sexp(res["ast"])
    }

    ; rows: Array of [text, expected S-expression]. Every row is checked; the first mismatch names its input.
    static Table(rows, kind := "expression") {
        for row in rows {
            actual := ExprCheck.Sexp(row[1], kind)
            if (actual !== row[2])
                throw AssertFailed("input " ExprCheck.Show(row[1]) ": expected " row[2] " but got " actual)
        }
    }

    ; Parses text, requires failure and returns the result.
    static Fails(text, kind := "expression") {
        res := ExprCheck.Parse(text, kind)
        if (res["ok"])
            throw AssertFailed("input " ExprCheck.Show(text) " should fail but gave " ExprDump.Sexp(res["ast"]))
        if (res["ast"] !== "" || res["errors"].Length = 0)
            throw AssertFailed("input " ExprCheck.Show(text) ": a failed result needs ast = empty text and at least one error")
        return res
    }

    ; rows: Array of [text, line, col, part of the message]. The first error of every input is checked.
    static ErrorTable(rows, kind := "expression") {
        for row in rows {
            res := ExprCheck.Fails(row[1], kind)
            err := res["errors"][1]
            if (err["line"] != row[2] || err["col"] != row[3])
                throw AssertFailed("input " ExprCheck.Show(row[1]) ": expected line " row[2] " column " row[3] " but got line " err["line"] " column " err["col"] " (" err["message"] ")")
            if (!InStr(err["message"], row[4]))
                throw AssertFailed("input " ExprCheck.Show(row[1]) ": message '" err["message"] "' does not contain '" row[4] "'")
        }
    }

    static Show(text) {
        shown := StrReplace(StrReplace(StrReplace(text, "`r", "\r"), "`n", "\n"), "`t", "\t")
        return '<' (StrLen(shown) > 80 ? SubStr(shown, 1, 77) "..." : shown) '>'
    }
}
