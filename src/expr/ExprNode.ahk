#Requires AutoHotkey v2.0
#Include ExprToken.ahk

; Construction of AST nodes (doc/AUSDRUECKE.md section 9 describes every node type).
; A node is a Map. All nodes have these fields:
;   type   node type, see below
;   pos    1-based index of the first character in the source text
;   end    index of the first character after the node (end - pos is the length)
;   line, col  1-based position of the first character
;   depth  height of the tree below and including this node (a leaf has 1)
; "Absent" child nodes are the empty string "". Nodes are never changed after parsing and may be shared
; (the parse cache returns the same tree again).
class ExprNode {
    ; A tree may not be higher than this (the evaluator recurses along the tree and AutoHotkey ends the
    ; process, not just the call, when the call stack is full).
    static MAX_DEPTH := 200

    ; Common fields. startRef is an ExprToken or a node, endPos the index after the last character.
    static Make(type, startRef, endPos, depth := 1) {
        n := Map()
        n["type"] := type
        if (startRef is ExprToken) {
            n["pos"] := startRef.pos
            n["line"] := startRef.line
            n["col"] := startRef.col
        } else {
            n["pos"] := startRef["pos"]
            n["line"] := startRef["line"]
            n["col"] := startRef["col"]
        }
        n["end"] := endPos
        n["depth"] := depth
        return n
    }

    ; Number: value (Integer or Float), text (source spelling, "true"/"false" for the keywords).
    static NumberNode(tok, value) {
        n := ExprNode.Make("Number", tok, tok.End)
        n["value"] := value
        n["text"] := tok.text
        return n
    }

    ; String: value (decoded text). Also used for the literal parts of a dynamic name.
    static StringNode(tok, value) {
        n := ExprNode.Make("String", tok, tok.End)
        n["value"] := value
        return n
    }

    ; Var: name (spelling as written; the lookup ignores case).
    static VarNode(tok) {
        n := ExprNode.Make("Var", tok, tok.End)
        n["name"] := tok.text
        return n
    }

    ; DynVar: parts (Array of nodes; the values of the parts are joined as text and the result is the name).
    static DynVarNode(startTok, endPos, parts) {
        n := ExprNode.Make("DynVar", startTok, endPos, 1 + ExprNode.MaxDepth(parts))
        n["parts"] := parts
        return n
    }

    ; Unary: op ("-" or "!"), operand.
    static UnaryNode(opTok, op, operand) {
        n := ExprNode.Make("Unary", opTok, operand["end"], 1 + operand["depth"])
        n["op"] := op
        n["operand"] := operand
        return n
    }

    ; Binary: op, left, right.
    static BinaryNode(op, left, right) {
        n := ExprNode.Make("Binary", left, right["end"], 1 + Max(left["depth"], right["depth"]))
        n["op"] := op
        n["left"] := left
        n["right"] := right
        return n
    }

    ; Assign: op, target (Var, DynVar or Index), value.
    static AssignNode(op, target, value) {
        n := ExprNode.Make("Assign", target, value["end"], 1 + Max(target["depth"], value["depth"]))
        n["op"] := op
        n["target"] := target
        n["value"] := value
        return n
    }

    ; Index: object, key (an expression), dot (1 if written as obj.name, obj.123 or obj.%e%, else 0).
    static IndexNode(object, key, dot, endPos) {
        n := ExprNode.Make("Index", object, endPos, 1 + Max(object["depth"], key["depth"]))
        n["object"] := object
        n["key"] := key
        n["dot"] := dot
        return n
    }

    ; Call: callee (Var, DynVar or Index), args (Array of expressions).
    static CallNode(callee, args, endPos) {
        n := ExprNode.Make("Call", callee, endPos, 1 + Max(callee["depth"], ExprNode.MaxDepth(args)))
        n["callee"] := callee
        n["args"] := args
        return n
    }

    ; Empty: the whole input of the expression form has no content.
    static EmptyNode(tok) {
        n := ExprNode.Make("Empty", tok, tok.pos)
        return n
    }

    ; Script: body (Array of statements).
    static ScriptNode(startTok, endPos, body) {
        n := ExprNode.Make("Script", startTok, endPos, 1 + ExprNode.MaxDepth(body))
        n["body"] := body
        return n
    }

    ; Block: body (Array of statements).
    static BlockNode(startTok, endPos, body) {
        n := ExprNode.Make("Block", startTok, endPos, 1 + ExprNode.MaxDepth(body))
        n["body"] := body
        return n
    }

    ; If: cond (expression), then (statement), else (statement, or "" if there is no else).
    static IfNode(startTok, endPos, cond, thenStmt, elseStmt) {
        d := Max(cond["depth"], thenStmt["depth"], elseStmt == "" ? 0 : elseStmt["depth"])
        n := ExprNode.Make("If", startTok, endPos, 1 + d)
        n["cond"] := cond
        n["then"] := thenStmt
        n["else"] := elseStmt
        return n
    }

    ; ExprStmt: expr (an Assign or a Call).
    static ExprStmtNode(expr) {
        n := ExprNode.Make("ExprStmt", expr, expr["end"], 1 + expr["depth"])
        n["expr"] := expr
        return n
    }

    ; Largest depth in an Array of nodes (0 for an empty array).
    static MaxDepth(nodes) {
        d := 0
        for n in nodes {
            if (n["depth"] > d)
                d := n["depth"]
        }
        return d
    }
}
