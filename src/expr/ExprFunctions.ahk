#Requires AutoHotkey v2.0

; Table of the functions an expression can call (doc/EXPRESSION-LANGUAGE.md section 7). Names ignore case.
;
; A function is registered with Register(name, fn, minArgs, maxArgs). fn is called as fn(ctx, args*), where ctx
; is the ExprEvaluator (ctx.Log(level, text) writes to the log). maxArgs -1 means any number. A function
; reports a user error by throwing; the evaluator catches it, gives the empty text and records a warning.
; The number of arguments is checked by the evaluator before the call.
class ExprFunctions {
    static _entries := ""

    static Register(name, fn, minArgs, maxArgs) {
        ExprFunctions._Table()[name] := Map("fn", fn, "min", minArgs, "max", maxArgs)
    }

    ; The entry Map (fn, min, max) of a function, or "" if there is none.
    static Find(name) {
        t := ExprFunctions._Table()
        return t.Has(name) ? t[name] : ""
    }

    ; The table; the built-in functions are put in when it is first needed.
    static _Table() {
        if (ExprFunctions._entries != "")
            return ExprFunctions._entries
        t := Map()
        t.CaseSense := "Off"
        ExprFunctions._entries := t
        t["round"] := Map("fn", ExprFunctions._Round.Bind(ExprFunctions), "min", 1, "max", 2)
        t["object"] := Map("fn", ExprFunctions._Object.Bind(ExprFunctions), "min", 0, "max", -1)
        t["print"] := Map("fn", ExprFunctions._Print.Bind(ExprFunctions), "min", 0, "max", -1)
        t["mod"] := Map("fn", ExprFunctions._Mod.Bind(ExprFunctions), "min", 2, "max", 2)
        return t
    }

    ; round(number [, digits]): AutoHotkey Round. A text that is not a number is a TypeError (handled by the caller).
    static _Round(ctx, number, digits := 0) {
        return Round(number, digits)
    }

    ; object([key, value, ...]): a new Map that ignores case in its keys (decision E0028).
    static _Object(ctx, pairs*) {
        if (Mod(pairs.Length, 2) != 0)
            throw ValueError("object() needs pairs of key and value, got " pairs.Length " arguments")
        m := Map()
        m.CaseSense := "Off"
        loop pairs.Length // 2
            m[pairs[2 * A_Index - 1]] := pairs[2 * A_Index]
        return m
    }

    ; print(value, ...): writes the values, separated by a space, to the log (level f1). Gives the empty text.
    static _Print(ctx, values*) {
        text := ""
        for v in values {
            if (IsObject(v))
                str := "<" Type(v) ">"
            else
                str := String(v)
            text .= (A_Index = 1 ? "" : " ") str
        }
        ctx.Log("f1", "print: " text)
        return ""
    }

    ; mod(a, b): remainder with the sign of a, as AutoHotkey Mod. Replaces the operator % (not in the language).
    ; MinInt and -1 would end the whole process in AutoHotkey (division overflow), so it is refused here.
    static _Mod(ctx, a, b) {
        if (IsInteger(a) && IsInteger(b) && Integer(b) = -1)
            return 0
        return Mod(a, b)
    }
}
