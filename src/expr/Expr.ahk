#Requires AutoHotkey v2.0
#Include ExprParser.ahk
#Include ExprCache.ahk
#Include ExprEvaluator.ahk

; Entry point of the expression library (doc/EXPRESSION-LANGUAGE.md).
;
;   res := Expr.ParseExpression(text)     ; one value, as in a parameter
;   res := Expr.ParseScript(text)         ; several statements
;   if (res["ok"])  ... res["ast"] ...    ; the tree, see section 10 of the document
;   else            MsgText := Expr.FormatErrors(res)
;
; The parse results are cached: the engine evaluates the same parameter texts over and over. The returned
; Map and the tree in it are shared; do not change them. Texts longer than Expr.MAX_CACHED_TEXT are not cached.
class Expr {
    static MAX_CACHED_TEXT := 20000
    static cache := ExprCache(2000)

    ; kind is "expression" or "script".
    static Parse(text, kind := "expression", useCache := true) {
        if (kind != "expression" && kind != "script")
            throw ValueError("Expr.Parse: unknown kind '" kind "'")
        if (!useCache || StrLen(text) > Expr.MAX_CACHED_TEXT)
            return ExprParser.Parse(text, kind)
        key := SubStr(kind, 1, 1) text
        res := Expr.cache.Get(key)
        if (res != "")
            return res
        res := ExprParser.Parse(text, kind)
        Expr.cache.Put(key, res)
        return res
    }

    static ParseExpression(text, useCache := true) => Expr.Parse(text, "expression", useCache)

    static ParseScript(text, useCache := true) => Expr.Parse(text, "script", useCache)

    ; Parses (with the cache) and evaluates. resolver gives access to the variables and logFn(level, text) receives
    ; the log entries, see ExprEvaluator. Returns the result Map: value, errors, warnings, missing. Never throws
    ; because of the text.
    static Evaluate(text, resolver, logFn := "", kind := "expression") {
        return ExprEvaluator(resolver, logFn).Run(Expr.Parse(text, kind), text)
    }

    static EvaluateScript(text, resolver, logFn := "") => Expr.Evaluate(text, resolver, logFn, "script")

    ; Text of all errors of a parse result: "line 1, column 5: message" and the marked line, per error.
    static FormatErrors(res) => ExprDiag.FormatAll(res["errors"])

    ; "OK", "Empty", "StartsWithNumber" or "ForbiddenCharacter" (v1 Var_CheckName with tellWhy).
    static CheckName(name) => ExprNames.Check(name)
}
