#Requires AutoHotkey v2.0

; Detection of the deviation classes that can apply to a v1 expression text (WI-0045, doc/EXPRESSION-LANGUAGE.md
; section 15.1, doc/MIGRATION.md). Used by V1ExprConverter.Convert.
;
;   classes := V1ExprDetect.Classes(text, ast)    ; ast: the tree of the text (or of the text after the syntax
;                                                 ; rewrites), "" if the new language cannot read it
;
; The result is an Array of class names of the golden data (tools/golden_classes.py, MigrationClasses), each once, in
; the order of first appearance. Only classes with the handling "accept" are reported (a place the loader rewrites
; behaves like v1). A class is reported only where the TEXT shows that it applies: a comparison with a text literal, a
; `&&` whose result is used as a value, a literal like `0x10`. Where the result depends on a value that is known only
; at run time (the number format of a variable, an object as a text), nothing is reported: there is no guessing.
;
; What the text decides, per class:
;   text comparison            <, >, <=, >= with a string literal that is not a number
;   number-like texts          = or == between two string literals that both look like numbers
;   operand as result          && || and or in a place where the value is used (an assignment, an argument, an operand
;                              of a calculation), not as a condition and not as the whole expression (the whole
;                              expression of a parameter may be a condition: not decidable)
;   no short circuit           && || with an assignment on the right side
;   not                        not or ! at the start of a statement or behind and/or
;   true and false             the words true and false
;   keyword as name            the whole text is if, else, and, or or not
;   assignment value           an assignment inside an expression (not the statement itself)
;   assignment to a path       a.b := 5, a[1] := 5
;   assignment refused         an assignment to an A_ name
;   built-in value             A_PtrSize, A_LanguageName
;   path into global or static global_x.y, static_x[1] read
;   escape sequence            a string with an escape that v2 knows (`n, `t, ...)
;   number literal forms       0x10, 1e3
;   integer overflow           a decimal integer literal beyond 64 bit
;   integer division with float  // with a float literal
;   v1 error                   a function call, a unary minus in front of anything but a number literal
;   v1 ignores text            glued operators (*-, :=-, //=), a chain of indexes (m[1][2], m[1].x), a second line in
;                              an expression
class V1ExprDetect {
    static V1_OPERATORS := Map(":=", 1, "+=", 1, "-=", 1, ".=", 1, "/=", 1, "*=", 1, "||", 1, "&&", 1, "!", 1, "<", 1
        , ">", 1, "<=", 1, ">=", 1, "=", 1, "==", 1, "!=", 1, ".", 1, "+", 1, "-", 1, "*", 1, "/", 1, "//", 1, "%", 1)
    static OP_CHARS := "-+*/%=&|<>!:."
    static KEYWORDS := Map("if", 1, "else", 1, "and", 1, "or", 1, "not", 1)
    static INT64_MAX := "9223372036854775807"

    ; kind: "expression" or "script". ast "" when the text cannot be read by the new parser.
    static Classes(text, ast, kind := "expression") {
        found := Map()
        order := []
        add := (cls) => V1ExprDetect._Add(found, order, cls)
        t := Trim(text, " `t`r`n")
        if (V1ExprDetect.KEYWORDS.Has(StrLower(t)))
            add("keyword as name")
        if (kind = "expression" && InStr(t, "`n"))
            add("v1 ignores text")
        if (V1ExprDetect._HasGluedOperator(text))
            add("v1 ignores text")
        if (IsObject(ast))
            V1ExprDetect._Walk(ast, text, "top", ast["pos"], add)
        return order
    }

    static _Add(found, order, cls) {
        if (found.Has(cls))
            return
        found[cls] := true
        order.Push(cls)
    }

    ; A run of operator characters that v1 does not know as an operator (outside strings and comments).
    static _HasGluedOperator(text) {
        n := StrLen(text)
        i := 1
        while (i <= n) {
            c := SubStr(text, i, 1)
            if (c = '"') {
                i += 1
                while (i <= n && SubStr(text, i, 1) != '"' && SubStr(text, i, 1) != "`n") {
                    i += (SubStr(text, i, 1) = "``") ? 2 : 1
                }
                i += 1
            } else if (c = ";" && (i = 1 || InStr(" `t`r`n", SubStr(text, i - 1, 1)))) {
                j := InStr(text, "`n", , i)
                i := j ? j : n + 1
            } else if (InStr(V1ExprDetect.OP_CHARS, c)) {
                j := i
                while (j <= n && InStr(V1ExprDetect.OP_CHARS, SubStr(text, j, 1)))
                    j += 1
                if (!V1ExprDetect.V1_OPERATORS.Has(SubStr(text, i, j - i)))
                    return true
                i := j
            } else {
                i += 1
            }
        }
        return false
    }

    ; ctx: "top" (the whole expression or a statement: the use of its value is unknown), "cond" (only the truth value
    ; counts) or "value" (the value is used). stmtPos: position of the first character of the statement.
    static _Walk(node, text, ctx, stmtPos, add) {
        switch node["type"] {
            case "Script", "Block":
                for stmt in node["body"]
                    V1ExprDetect._Walk(stmt, text, "top", stmt["pos"], add)
            case "If":
                V1ExprDetect._Walk(node["cond"], text, "cond", node["cond"]["pos"], add)
                V1ExprDetect._Walk(node["then"], text, "top", node["then"]["pos"], add)
                if (node["else"] != "")
                    V1ExprDetect._Walk(node["else"], text, "top", node["else"]["pos"], add)
            case "ExprStmt":
                V1ExprDetect._Walk(node["expr"], text, "top", node["expr"]["pos"], add)
            case "Number":
                V1ExprDetect._Number(node, add)
            case "String":
                if (RegExMatch(SubStr(text, node["pos"], node["end"] - node["pos"]), "``[nrtbvaf`"'``;%,:{}]"))
                    add("escape sequence")
            case "Var":
                V1ExprDetect._Name(node["name"], add)
            case "DynVar":
                for part in node["parts"]
                    V1ExprDetect._Walk(part, text, "value", stmtPos, add)
            case "Unary":
                if (node["op"] = "!") {
                    if (node["pos"] = stmtPos)
                        add("not")
                    V1ExprDetect._Walk(node["operand"], text, "cond", stmtPos, add)
                } else {
                    if (node["operand"]["type"] != "Number")
                        add("v1 error")
                    V1ExprDetect._Walk(node["operand"], text, "value", stmtPos, add)
                }
            case "Binary":
                V1ExprDetect._Binary(node, text, ctx, stmtPos, add)
            case "Assign":
                V1ExprDetect._Assign(node, text, ctx, stmtPos, add)
            case "Index":
                if (V1ExprDetect._ScopeBase(node))
                    add("path into global or static")
                obj := node["object"]
                if (obj["type"] = "Index" && obj["dot"] = 0)
                    add("v1 ignores text")
                V1ExprDetect._Walk(obj, text, "value", stmtPos, add)
                V1ExprDetect._Walk(node["key"], text, "value", stmtPos, add)
            case "Call":
                add("v1 error")
                V1ExprDetect._Walk(node["callee"], text, "value", stmtPos, add)
                for arg in node["args"]
                    V1ExprDetect._Walk(arg, text, "value", stmtPos, add)
        }
    }

    static _Number(node, add) {
        lit := node["text"]
        if (StrLower(lit) = "true" || StrLower(lit) = "false") {
            add("true and false")
        } else if (RegExMatch(lit, "i)^(0x[0-9a-f]+|\d*\.?\d+e[+-]?\d+)$")) {
            add("number literal forms")
        } else if (RegExMatch(lit, "^\d+$") && (StrLen(lit) > 19 || (StrLen(lit) = 19 && StrCompare(lit, V1ExprDetect.INT64_MAX) > 0))) {
            add("integer overflow")
        }
    }

    static _Name(name, add) {
        low := StrLower(name)
        if (low = "a_ptrsize" || low = "a_languagename")
            add("built-in value")
    }

    ; True if the base of an index chain is a variable named global_... or static_...
    static _ScopeBase(node) {
        base := node
        while (base["type"] = "Index")
            base := base["object"]
        return base["type"] = "Var" && RegExMatch(base["name"], "i)^(global|static)_\w")
    }

    static _Binary(node, text, ctx, stmtPos, add) {
        op := node["op"]
        left := node["left"]
        right := node["right"]
        switch op {
            case "<", ">", "<=", ">=":
                for side in [left, right] {
                    if (side["type"] = "String" && !IsNumber(side["value"]))
                        add("text comparison")
                }
            case "=", "==":
                if (left["type"] = "String" && right["type"] = "String" && IsNumber(left["value"])
                    && IsNumber(right["value"]))
                    add("number-like texts")
            case "&&", "||":
                if (ctx = "value")
                    add("operand as result")
                if (V1ExprDetect._HasAssign(right))
                    add("no short circuit")
                ; both sides keep the use of the value of this node
                V1ExprDetect._WalkLogicSide(left, text, ctx, stmtPos, add, false)
                V1ExprDetect._WalkLogicSide(right, text, ctx, stmtPos, add, true)
                return
            case "//":
                if (V1ExprDetect._IsFloatLiteral(left) || V1ExprDetect._IsFloatLiteral(right))
                    add("integer division with float")
        }
        V1ExprDetect._Walk(left, text, "value", stmtPos, add)
        V1ExprDetect._Walk(right, text, "value", stmtPos, add)
    }

    ; A side of && or ||: it keeps the use of the parent. A `not` behind and/or is a place of class "not".
    static _WalkLogicSide(side, text, ctx, stmtPos, add, isRight) {
        if (isRight && side["type"] = "Unary" && side["op"] = "!")
            add("not")
        V1ExprDetect._Walk(side, text, side["type"] = "Assign" ? "value" : ctx, stmtPos, add)
    }

    static _IsFloatLiteral(node) {
        return node["type"] = "Number" && RegExMatch(node["text"], "^\d*\.\d+$")
    }

    ; True if an assignment is somewhere below the node.
    static _HasAssign(node) {
        if (!IsObject(node) || !(node is Map))
            return false
        switch node["type"] {
            case "Assign":
                return true
            case "Unary":
                return V1ExprDetect._HasAssign(node["operand"])
            case "Binary":
                return V1ExprDetect._HasAssign(node["left"]) || V1ExprDetect._HasAssign(node["right"])
            case "Index":
                return V1ExprDetect._HasAssign(node["object"]) || V1ExprDetect._HasAssign(node["key"])
            case "Call":
                for arg in node["args"] {
                    if (V1ExprDetect._HasAssign(arg))
                        return true
                }
            case "DynVar":
                for part in node["parts"] {
                    if (V1ExprDetect._HasAssign(part))
                        return true
                }
        }
        return false
    }

    static _Assign(node, text, ctx, stmtPos, add) {
        if (ctx != "top")
            add("assignment value")
        target := node["target"]
        if (target["type"] = "Var" && RegExMatch(target["name"], "i)^a_"))
            add("assignment refused")
        else if (target["type"] = "Index")
            add("assignment to a path")
        ; the target itself is written, not read; only its parts (an index expression) are evaluated
        if (target["type"] = "Index")
            V1ExprDetect._Walk(target["key"], text, "value", stmtPos, add)
        else if (target["type"] = "DynVar")
            V1ExprDetect._Walk(target, text, "value", stmtPos, add)
        V1ExprDetect._Walk(node["value"], text, "value", stmtPos, add)
    }
}
