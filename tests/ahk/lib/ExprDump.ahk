#Requires AutoHotkey v2.0

; Test helper: AST of the expression language as a short text (S-expression), for compact assertions.
;   Number  -> source text         String -> "text" with \n \t \r \ \" escaped     Var -> name
;   DynVar  -> $(part part ...)    Unary  -> (neg x) or (! x)       Binary -> (op left right)
;   Assign  -> (:= target value)   Index  -> (idx obj key) for [] and (mem obj key) for a dot
;   Call    -> (call callee arg ...)   Empty -> (empty)
;   Script  -> (script stmt ...)   Block -> (block stmt ...)   If -> (if cond then) or (if cond then else)
;   ExprStmt is shown as its expression.
class ExprDump {
    static Sexp(n) {
        switch n["type"] {
            case "Number":
                return n["text"]
            case "String":
                return '"' ExprDump.Esc(n["value"]) '"'
            case "Var":
                return n["name"]
            case "DynVar":
                return "$(" ExprDump.List(n["parts"]) ")"
            case "Unary":
                return "(" (n["op"] == "-" ? "neg" : n["op"]) " " ExprDump.Sexp(n["operand"]) ")"
            case "Binary":
                return "(" n["op"] " " ExprDump.Sexp(n["left"]) " " ExprDump.Sexp(n["right"]) ")"
            case "Assign":
                return "(" n["op"] " " ExprDump.Sexp(n["target"]) " " ExprDump.Sexp(n["value"]) ")"
            case "Index":
                return "(" (n["dot"] ? "mem" : "idx") " " ExprDump.Sexp(n["object"]) " " ExprDump.Sexp(n["key"]) ")"
            case "Call":
                a := ExprDump.List(n["args"])
                return "(call " ExprDump.Sexp(n["callee"]) (a = "" ? "" : " " a) ")"
            case "Empty":
                return "(empty)"
            case "ExprStmt":
                return ExprDump.Sexp(n["expr"])
            case "Script":
                return "(script" (n["body"].Length ? " " ExprDump.List(n["body"]) : "") ")"
            case "Block":
                return "(block" (n["body"].Length ? " " ExprDump.List(n["body"]) : "") ")"
            case "If":
                return "(if " ExprDump.Sexp(n["cond"]) " " ExprDump.Sexp(n["then"]) (n["else"] == "" ? "" : " " ExprDump.Sexp(n["else"])) ")"
        }
        return "<?" n["type"] ">"
    }

    static List(nodes) {
        s := ""
        for n in nodes
            s .= (A_Index = 1 ? "" : " ") ExprDump.Sexp(n)
        return s
    }

    static Esc(s) {
        s := StrReplace(s, "\", "\\")
        s := StrReplace(s, '"', '\"')
        s := StrReplace(s, "`n", "\n")
        s := StrReplace(s, "`r", "\r")
        s := StrReplace(s, "`t", "\t")
        return s
    }
}
