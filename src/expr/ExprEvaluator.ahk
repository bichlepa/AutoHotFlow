#Requires AutoHotkey v2.0
#Include ExprDiag.ahk
#Include ExprNames.ahk
#Include ExprFunctions.ahk
#Include ExprResolveError.ahk

; Evaluator of the expression language (doc/EXPRESSION-LANGUAGE.md). It walks a tree made by the parser.
;
;   ev := ExprEvaluator(resolver, logFn)
;   res := ev.Run(parseResult, text)       ; text is optional, it only makes the error records richer
;   res["value"]     the result: Integer, Float, String or an object (Map); "" for an empty expression
;   res["errors"]    Array of error records (Map: message, line, col, pos, length, and with text lineText, marked)
;   res["warnings"]  Array of records of the same form
;   res["missing"]   Array of Maps (name, line, col, pos) of the variables that were read but do not exist
;
; Resolver (the owner of the variables; the evaluator knows nothing about scopes). path is an Array of the
; evaluated parts: `a.b[i]` gives ["a", "b", <value of i>]; `x%n%` gives ["x1"] for n = 1.
;   resolver.Has(path)         1 if the variable or member exists, else 0
;   resolver.Get(path)         its value (only called after Has gave 1)
;   resolver.Set(path, value)  assigns
; A resolver throws ExprResolveError when the request cannot be met because of the expression (error with
; position, the value is ""). Other exceptions of the resolver are internal errors and leave the evaluator.
;
; logFn(level, text) is called for what the user should see in the log: level "f1" for errors and warnings,
; "f0" for a variable that does not exist (as in v1), and by print(). Pass "" for no logging. A logFn that
; throws is ignored (counted in logFailures).
;
; The evaluator never throws because of what the user wrote. A calculation that fails (TypeError such as
; "" + 1, division by zero, ...) gives the empty text, a warning and an f1 log (decision E0025). An error
; (unknown function, wrong number of arguments, a resolver refusal, ...) gives the empty text for that part;
; the rest of the expression is still evaluated.
class ExprEvaluator {
    static MIN_INT := -9223372036854775807 - 1

    resolver := ""
    logFn := ""
    logFailures := 0
    text := ""
    errors := []
    warnings := []
    missing := []

    __New(resolver, logFn := "") {
        this.resolver := resolver
        this.logFn := logFn
    }

    ; Evaluates a result of Expr.Parse. If the parse failed, its errors are the errors of the result.
    Run(parseResult, text := "") {
        this.text := text
        this.errors := []
        this.warnings := []
        this.missing := []
        value := ""
        if (!parseResult["ok"]) {
            for err in parseResult["errors"]
                this.errors.Push(err)
        } else {
            value := this._Eval(parseResult["ast"])
        }
        res := Map()
        res["value"] := value
        res["errors"] := this.errors
        res["warnings"] := this.warnings
        res["missing"] := this.missing
        return res
    }

    ; Writes to the log through logFn (for the functions, e.g. print).
    Log(level, text) {
        if (this.logFn == "")
            return
        try {
            this.logFn.Call(level, text)
        } catch {
            this.logFailures += 1
        }
    }

    ; ---- tree walk -------------------------------------------------------------------------------------

    _Eval(n) {
        switch n["type"] {
            case "Number", "String":
                return n["value"]
            case "Var":
                return this._Read([n["name"]], n)
            case "Binary":
                return this._Binary(n)
            case "Unary":
                return this._Unary(n)
            case "Index":
                return this._IndexRead(n)
            case "DynVar":
                path := this._Path(n)
                return IsObject(path) ? this._Read(path, n) : ""
            case "Assign":
                return this._Assign(n)
            case "Call":
                return this._Call(n)
            case "ExprStmt":
                return this._Eval(n["expr"])
            case "Empty":
                return ""
            case "Script":
                return this._Body(n["body"], "")
            case "Block":
                return this._Body(n["body"], 0)
            case "If":
                return this._If(n)
        }
        this._Error(n, "internal: unknown node type '" n["type"] "'")
        return ""
    }

    ; The last value of the statements, as in v1; initial is the value of an empty list.
    _Body(body, initial) {
        value := initial
        for stmt in body
            value := this._Eval(stmt)
        return value
    }

    ; v1 gave 0 for an if without else whose condition is false.
    _If(n) {
        if (this._Eval(n["cond"]))
            return this._Eval(n["then"])
        if (n["else"] !== "")
            return this._Eval(n["else"])
        return 0
    }

    ; ---- operators -------------------------------------------------------------------------------------

    _Binary(n) {
        op := n["op"]
        if (op = "&&") {
            left := this._Eval(n["left"])
            return left ? this._Eval(n["right"]) : left
        }
        if (op = "||") {
            left := this._Eval(n["left"])
            return left ? left : this._Eval(n["right"])
        }
        left := this._Eval(n["left"])
        right := this._Eval(n["right"])
        try {
            return ExprEvaluator.Apply(op, left, right)
        } catch Error as e {
            this._Warn(n, "'" op "' failed: " e.Message)
            return ""
        }
    }

    _Unary(n) {
        v := this._Eval(n["operand"])
        try {
            return (n["op"] = "-") ? -v : !v
        } catch Error as e {
            this._Warn(n, "'" n["op"] "' failed: " e.Message)
            return ""
        }
    }

    ; The value of a binary operator other than && and || (they need short-circuit evaluation). Throws the
    ; AutoHotkey error of a failed calculation (TypeError, ZeroDivisionError, ...); the callers catch it.
    static Apply(op, a, b) {
        switch op {
            case "+": return a + b
            case "-": return a - b
            case "*": return a * b
            case "/": return ExprEvaluator.Divide(a, b)
            case "//": return ExprEvaluator.FloorDivide(a, b)
            case ".": return a . b
            case "=": return a = b
            case "==": return a == b
            case "!=": return a != b
            case "!==": return a !== b
            case "<": return a < b
            case ">": return a > b
            case "<=": return a <= b
            case ">=": return a >= b
        }
        throw ValueError("unknown operator '" op "'")
    }

    ; E0029: `/` as in AutoHotkey, but two integers that divide exactly give an Integer (4/2 is 2, not 2.0).
    ; A text that looks like an integer counts as an integer, as in all arithmetic.
    static Divide(a, b) {
        r := a / b
        if (r is Float && IsInteger(a) && IsInteger(b)) {
            ia := Integer(a)
            ib := Integer(b)
            if (ib = -1) {
                ; Mod(MinInt, -1) would end the process; -MinInt does not fit, so that case stays a Float.
                if (ia != ExprEvaluator.MIN_INT)
                    return -ia
            } else if (Mod(ia, ib) = 0) {
                return ia // ib
            }
        }
        return r
    }

    ; `//` as in AutoHotkey (a Float operand is a TypeError). MinInt // -1 ends the whole process in
    ; AutoHotkey (division overflow, cannot be caught), so it is refused here.
    static FloorDivide(a, b) {
        if (IsInteger(a) && IsInteger(b) && Integer(b) = -1 && Integer(a) = ExprEvaluator.MIN_INT)
            throw ValueError("integer overflow")
        return a // b
    }

    ; ---- variables and paths ---------------------------------------------------------------------------

    ; The path (Array of the evaluated parts) of a Var, DynVar or a chain of Index nodes that starts with
    ; one of them. Returns "" if the chain starts with something else (a call result), 0 if an error was
    ; recorded (then the caller gives the empty text).
    _Path(n) {
        switch n["type"] {
            case "Var":
                return [n["name"]]
            case "DynVar":
                name := ""
                for part in n["parts"] {
                    v := this._Eval(part)
                    try {
                        name .= v
                    } catch Error {
                        this._Error(part, "a value that is not text cannot be part of a variable name")
                        return 0
                    }
                }
                if (ExprNames.Check(name) != "OK") {
                    this._Error(n, "'" name "' is not a valid variable name (" ExprNames.Check(name) ")")
                    return 0
                }
                return [name]
            case "Index":
                path := this._Path(n["object"])
                if (!IsObject(path))
                    return path
                path.Push(this._Eval(n["key"]))
                return path
        }
        return ""
    }

    ; The value at a path. A variable that does not exist gives "" and an f0 log, as in v1 (the caller of
    ; the evaluator decides whether that is a problem; the result lists it under "missing").
    _Read(path, n) {
        try {
            if (!this.resolver.Has(path)) {
                name := ExprEvaluator.PathText(path)
                this.missing.Push(this._Record(n, "Retrieving variable '" name "' failed. It does not exist", name))
                this.Log("f0", "Retrieving variable '" name "' failed. It does not exist")
                return ""
            }
            return this.resolver.Get(path)
        } catch ExprResolveError as e {
            this._Error(n, e.Message)
            return ""
        }
    }

    ; Reads a.b: through the resolver if the chain starts with a variable, else a member of a Map value
    ; (e.g. object().x).
    _IndexRead(n) {
        path := this._Path(n)
        if (IsObject(path))
            return this._Read(path, n)
        if (path == 0)
            return ""
        base := this._Eval(n["object"])
        key := this._Eval(n["key"])
        if (!(base is Map)) {
            this._Error(n, "this value has no members")
            return ""
        }
        if (!base.Has(key)) {
            name := String(IsObject(key) ? "<" Type(key) ">" : key)
            this.missing.Push(this._Record(n, "member '" name "' does not exist", name))
            this.Log("f0", "Retrieving member '" name "' failed. It does not exist")
            return ""
        }
        return base[key]
    }

    static PathText(path) {
        str := ""
        for part in path
            str .= (A_Index = 1 ? "" : ".") (IsObject(part) ? "<" Type(part) ">" : part)
        return str
    }

    ; ---- assignment ------------------------------------------------------------------------------------

    _Assign(n) {
        path := this._Path(n["target"])
        if (!IsObject(path)) {
            if (path == "")
                this._Error(n["target"], "only a variable or a member of a variable can be assigned to")
            this._Eval(n["value"])
            return ""
        }
        value := this._Eval(n["value"])
        op := n["op"]
        if (op != ":=") {
            current := this._Read(path, n["target"])
            try {
                value := ExprEvaluator.Apply(SubStr(op, 1, StrLen(op) - 1), current, value)
            } catch Error as e {
                ; As in v1 the failed calculation gives the empty text, and that is what the variable gets.
                this._Warn(n, "'" op "' failed: " e.Message)
                value := ""
            }
        }
        try {
            this.resolver.Set(path, value)
        } catch ExprResolveError as e {
            this._Error(n, e.Message)
            return ""
        }
        return value
    }

    ; ---- function calls --------------------------------------------------------------------------------

    _Call(n) {
        callee := n["callee"]
        argList := []
        for a in n["args"]
            argList.Push(this._Eval(a))
        if (callee["type"] = "Index") {
            this._Error(callee, "methods cannot be called; only the functions of the language can")
            return ""
        }
        if (callee["type"] = "DynVar") {
            path := this._Path(callee)
            if (!IsObject(path))
                return ""
            name := path[1]
        } else {
            name := callee["name"]
        }
        entry := ExprFunctions.Find(name)
        if (entry == "") {
            this._Error(callee, "unknown function '" name "'")
            return ""
        }
        count := argList.Length
        if (count < entry["min"] || (entry["max"] >= 0 && count > entry["max"])) {
            this._Error(n, "function '" name "' takes " ExprEvaluator._Range(entry["min"], entry["max"]) " argument(s), got " count)
            return ""
        }
        try {
            return entry["fn"].Call(this, argList*)
        } catch Error as e {
            this._Warn(n, "'" name "' failed: " e.Message)
            return ""
        }
    }

    static _Range(lo, hi) {
        if (hi < 0)
            return "at least " lo
        return (lo = hi) ? lo : lo " to " hi
    }

    ; ---- errors and warnings ---------------------------------------------------------------------------

    ; A record for a node: message, line, col, pos, length; with the source text also lineText and marked.
    _Record(n, message, name := "") {
        pos := n["pos"]
        length := n["end"] - pos
        if (this.text != "")
            rec := ExprDiag.Make(this.text, message, pos, length, n["line"], n["col"])
        else
            rec := Map("message", message, "line", n["line"], "col", n["col"], "pos", pos, "length", length)
        if (name != "")
            rec["name"] := name
        return rec
    }

    _Error(n, message) {
        this.errors.Push(this._Record(n, message))
        this.Log("f1", "Expression error: " message " (line " n["line"] ", column " n["col"] ")")
    }

    _Warn(n, message) {
        this.warnings.Push(this._Record(n, message))
        this.Log("f1", "Expression warning: " message " (line " n["line"] ", column " n["col"] ")")
    }
}
