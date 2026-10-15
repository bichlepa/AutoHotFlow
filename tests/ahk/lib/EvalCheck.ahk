#Requires AutoHotkey v2.0
#Include Assert.ahk
#Include ExprTestResolver.ahk
#Include ..\..\..\src\expr\Expr.ahk

; Test helpers for the evaluator (tests/ahk/expr_eval*.test.ahk).
class EvalCheck {
    ; Evaluates text with a resolver holding vars (a Map or ""), collects the log entries.
    ; Returns the result Map with the extra fields "log" (Array of "level: text") and "resolver".
    static Run(text, vars := "", kind := "expression") {
        resolver := ExprTestResolver(vars)
        logLines := []
        res := Expr.Evaluate(text, resolver, (level, msg) => logLines.Push(level ": " msg), kind)
        res["log"] := logLines
        res["resolver"] := resolver
        return res
    }

    static Value(text, vars := "", kind := "expression") => EvalCheck.Run(text, vars, kind)["value"]

    ; rows: Array of [text, expected value]. Type and value are compared (2 is not 2.0), no warnings or errors allowed.
    static Table(rows, vars := "", kind := "expression") {
        for row in rows {
            res := EvalCheck.Run(row[1], vars, kind)
            EvalCheck.NoProblems(res, row[1])
            if (Type(res["value"]) != Type(row[2]) || !(res["value"] == row[2]))
                throw AssertFailed("input " EvalCheck.Show(row[1]) ": expected " Assert.Show(row[2]) " but got " Assert.Show(res["value"]))
        }
    }

    ; rows: Array of [text, expected text form of the value]. For floats: the text form is what the user sees.
    static TextTable(rows, vars := "", kind := "expression") {
        for row in rows {
            res := EvalCheck.Run(row[1], vars, kind)
            EvalCheck.NoProblems(res, row[1])
            if (String(res["value"]) !== row[2])
                throw AssertFailed("input " EvalCheck.Show(row[1]) ": expected text " EvalCheck.Show(row[2]) " but got " EvalCheck.Show(String(res["value"])))
        }
    }

    ; The input gives "", exactly one warning (whose message contains part) and an f1 log entry.
    static Warns(text, part := "", vars := "", kind := "expression") {
        res := EvalCheck.Run(text, vars, kind)
        if (res["errors"].Length != 0)
            throw AssertFailed("input " EvalCheck.Show(text) ": unexpected errors " EvalCheck.Messages(res["errors"]))
        if (res["warnings"].Length != 1)
            throw AssertFailed("input " EvalCheck.Show(text) ": expected one warning, got " res["warnings"].Length " " EvalCheck.Messages(res["warnings"]))
        if (res["value"] !== "")
            throw AssertFailed("input " EvalCheck.Show(text) ": expected the empty text but got " Assert.Show(res["value"]))
        if (!InStr(res["warnings"][1]["message"], part))
            throw AssertFailed("input " EvalCheck.Show(text) ": warning '" res["warnings"][1]["message"] "' lacks '" part "'")
        EvalCheck.HasLog(res, "f1: Expression warning")
        return res
    }

    ; The input gives exactly one error whose message contains part, at line/col, and an f1 log entry.
    static Fails(text, part, line := 0, col := 0, vars := "", kind := "expression") {
        res := EvalCheck.Run(text, vars, kind)
        if (res["errors"].Length != 1)
            throw AssertFailed("input " EvalCheck.Show(text) ": expected one error, got " res["errors"].Length " " EvalCheck.Messages(res["errors"]))
        err := res["errors"][1]
        if (!InStr(err["message"], part))
            throw AssertFailed("input " EvalCheck.Show(text) ": error '" err["message"] "' lacks '" part "'")
        if (line && (err["line"] != line || err["col"] != col))
            throw AssertFailed("input " EvalCheck.Show(text) ": error at " err["line"] ":" err["col"] ", expected " line ":" col)
        EvalCheck.HasLog(res, "f1: Expression error")
        return res
    }

    static NoProblems(res, text) {
        if (res["errors"].Length || res["warnings"].Length)
            throw AssertFailed("input " EvalCheck.Show(text) ": unexpected problems " EvalCheck.Messages(res["errors"]) EvalCheck.Messages(res["warnings"]))
    }

    static HasLog(res, prefix) {
        for entry in res["log"] {
            if (InStr(entry, prefix) = 1)
                return
        }
        throw AssertFailed("no log entry starting with '" prefix "' in " EvalCheck.Messages(res["log"]))
    }

    static Messages(list) {
        s := "["
        for item in list
            s .= (A_Index = 1 ? "" : " | ") (item is Map ? item["message"] : item)
        return s "]"
    }

    static Show(text) => '"' StrReplace(StrReplace(text, "`r", "``r"), "`n", "``n") '"'
}
