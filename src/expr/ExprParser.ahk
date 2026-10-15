#Requires AutoHotkey v2.0
#Include ExprTokenizer.ahk
#Include ExprNode.ahk
#Include ExprAbort.ahk

; Recursive descent parser of the expression language (doc/EXPRESSION-LANGUAGE.md).
;
;   result := ExprParser.Parse(text, "expression")   ; or "script"
;
; The result is a Map: ok (1 or 0), kind, ast (the root node, "" if there are errors), errors (Array of
; error Maps, see ExprDiag; empty if ok). Bad input never throws. Several errors are collected: the
; tokenizer reports all unreadable text, the script form goes on with the next line after a syntax error,
; the expression form reports the first syntax error.
;
; Precedence from low to high (grammar in doc/EXPRESSION-LANGUAGE.md section 6):
;   assignment (right) < || or < && and < not < = == != !== < < > <= >= < concatenation < + - < * / // <
;   unary - ! < postfix (call, [index], .member)
class ExprParser {
    static MAX_NEST := 50
    static MAX_ERRORS := 50

    ; Operators the tokenizer reads but the language does not have: the message for each.
    static UNSUPPORTED := Map(
        "%", "the modulo operator '%' is not supported",
        "%=", "the operator '%=' is not supported",
        "**", "the power operator '**' is not supported",
        "**=", "the operator '**=' is not supported",
        "?", "the conditional operator '?:' is not supported",
        ":", "the conditional operator '?:' is not supported",
        "??", "the operator '??' is not supported",
        "++", "the increment operator '++' is not supported; write x += 1",
        "--", "the decrement operator '--' is not supported; write x -= 1",
        "<<", "bitwise operators are not supported", ">>", "bitwise operators are not supported",
        ">>>", "bitwise operators are not supported", "<<=", "bitwise operators are not supported",
        ">>=", "bitwise operators are not supported", "&", "bitwise operators are not supported",
        "|", "bitwise operators are not supported", "^", "bitwise operators are not supported",
        "~", "bitwise operators are not supported", "&=", "bitwise operators are not supported",
        "|=", "bitwise operators are not supported", "^=", "bitwise operators are not supported",
        "~=", "the regular expression match '~=' is not supported",
        "=>", "functions written with '=>' are not supported",
        "<>", "'<>' is not valid; write '!=' for not equal"
    )

    static ASSIGN_OPS := Map(":=", 1, "+=", 1, "-=", 1, "*=", 1, "/=", 1, "//=", 1, ".=", 1)

    text := ""
    script := false
    toks := []
    i := 1
    depth := 0      ; open ( [ and call parentheses: line breaks are whitespace inside
    pct := 0        ; 1 directly inside %...%: a "%" closes there
    nest := 0       ; recursion guard
    last := ""      ; the token consumed last
    errors := []

    __New(text, script) {
        this.text := text
        this.script := script
    }

    ; Parses text. kind is "expression" (one value) or "script" (statements).
    static Parse(text, kind := "expression") {
        script := (kind = "script")
        parser := ExprParser(text, script)
        return parser.Run()
    }

    Run() {
        tk := ExprTokenizer(this.text, this.script).Run()
        this.toks := tk.tokens
        this.errors := []
        this.i := 1
        this.depth := 0
        this.pct := 0
        this.nest := 0
        tree := ""
        if (this.script)
            tree := this._Script()
        else
            tree := this._Expression()
        all := tk.errors.Clone()
        for err in this.errors {
            dup := false
            for e2 in all {
                if (e2["pos"] = err["pos"]) {
                    dup := true
                    break
                }
            }
            if (!dup)
                all.Push(err)
        }
        ; insertion sort by position (few entries)
        loop all.Length - 1 {
            k := A_Index + 1
            cur := all[k]
            j := k - 1
            while (j >= 1 && all[j]["pos"] > cur["pos"]) {
                all[j + 1] := all[j]
                j -= 1
            }
            all[j + 1] := cur
        }
        res := Map()
        res["kind"] := this.script ? "script" : "expression"
        res["errors"] := all
        res["ok"] := (all.Length = 0) ? 1 : 0
        res["ast"] := (all.Length = 0) ? tree : ""
        return res
    }

    ; ---------------------------------------------------------------- token access

    ; Current token. Inside brackets line breaks are skipped.
    _Cur() {
        t := this.toks[this.i]
        if (this.depth > 0 && t.type == "NL") {
            while (this.toks[this.i].type == "NL")
                this.i += 1
            t := this.toks[this.i]
        }
        return t
    }

    ; Consumes and returns the current token (the EOF token stays).
    _Next() {
        t := this._Cur()
        if (t.type != "EOF")
            this.i += 1
        this.last := t
        return t
    }

    ; The token behind the current one.
    _After() {
        this._Cur()
        j := this.i
        if (this.toks[j].type != "EOF")
            j += 1
        if (this.depth > 0) {
            while (this.toks[j].type == "NL")
                j += 1
        }
        return this.toks[j]
    }

    ; Skips line breaks (script form), used where an operand is required.
    _SkipNl() {
        while (this.toks[this.i].type == "NL")
            this.i += 1
    }

    ; ---------------------------------------------------------------- errors

    _AddError(message, pos, length, line, col) {
        if (this.errors.Length >= ExprParser.MAX_ERRORS)
            return
        this.errors.Push(ExprDiag.Make(this.text, message, pos, length, line, col))
    }

    _FailTok(message, tok) {
        len := (tok.type == "EOF" || tok.type == "NL") ? 0 : tok.len
        this._AddError(message, tok.pos, len, tok.line, tok.col)
        throw ExprAbort(message)
    }

    _FailNode(message, node) {
        this._AddError(message, node["pos"], node["end"] - node["pos"], node["line"], node["col"])
        throw ExprAbort(message)
    }

    ; The token cannot continue the input here. expecting says what would be valid.
    _Unexpected(tok, expecting := "") {
        if (tok.type == "ERR")
            throw ExprAbort("")
        msg := ""
        if (tok.type == "EOF")
            msg := "unexpected end of the input"
        else if (tok.type == "NL")
            msg := "unexpected end of the line"
        else if (tok.type == "OP" && ExprParser.UNSUPPORTED.Has(tok.text))
            msg := ExprParser.UNSUPPORTED[tok.text]
        else
            msg := "unexpected '" tok.text "'"
        if (expecting != "" && !(tok.type == "OP" && ExprParser.UNSUPPORTED.Has(tok.text)))
            msg .= "; " expecting
        this._FailTok(msg, tok)
    }

    _Enter(tok) {
        this.nest += 1
        if (this.nest > ExprParser.MAX_NEST)
            this._FailTok("nested too deeply (at most " ExprParser.MAX_NEST " levels)", tok)
    }

    _Leave() {
        this.nest -= 1
    }

    ; The tree may not get higher than ExprNode.MAX_DEPTH.
    _Check(node) {
        if (node["depth"] > ExprNode.MAX_DEPTH)
            this._FailNode("the expression is too long or too deeply built (the tree may be " ExprNode.MAX_DEPTH " levels high at most)", node)
        return node
    }

    ; ---------------------------------------------------------------- entry points

    _Expression() {
        first := this._Cur()
        if (first.type == "EOF")
            return ExprNode.EmptyNode(first)
        try {
            parsed := this._ParseAssign()
            tok := this._Cur()
            if (tok.type != "EOF")
                this._Unexpected(tok)
            return parsed
        } catch ExprAbort {
            return ""
        }
    }

    _Script() {
        first := this.toks[1]
        body := this._StatementList(false)
        return ExprNode.ScriptNode(first, StrLen(this.text) + 1, body)
    }

    ; Statements up to the end of the input, or (inBlock) up to the "}" that closes the block, which is not consumed.
    _StatementList(inBlock) {
        body := []
        loop {
            this._SkipNl()
            tok := this.toks[this.i]
            if (tok.type == "EOF")
                break
            if (inBlock && tok.IsOp("}"))
                break
            nest0 := this.nest
            try {
                stmt := this._Statement()
                body.Push(stmt)
            } catch ExprAbort {
                this._Recover(nest0)
            }
        }
        return body
    }

    ; After a syntax error: skip the rest of the line and reset the nesting state.
    _Recover(nest0) {
        this.depth := 0
        this.pct := 0
        this.nest := nest0
        while (true) {
            t := this.toks[this.i]
            if (t.type == "NL" || t.type == "EOF")
                break
            this.i += 1
        }
    }

    ; ---------------------------------------------------------------- statements

    _Statement() {
        tok := this._Cur()
        if (tok.IsOp("{"))
            return this._Block()
        if (tok.IsOp("}"))
            this._FailTok("unexpected '}': no block is open", tok)
        if (tok.type == "WORD" && tok.kw == "if")
            return this._If()
        if (tok.type == "WORD" && tok.kw == "else")
            this._FailTok("'else' without a matching 'if'", tok)
        parsed := this._ParseAssign()
        t := this._Cur()
        if (t.type != "NL" && t.type != "EOF" && !t.IsOp("}"))
            this._Unexpected(t)
        if (parsed["type"] != "Assign" && parsed["type"] != "Call")
            this._FailNode("a line must be an assignment (x := 1) or a function call (f(x))", parsed)
        return ExprNode.ExprStmtNode(parsed)
    }

    _Block() {
        open := this._Next()
        this._Enter(open)
        body := this._StatementList(true)
        tok := this.toks[this.i]
        if (!tok.IsOp("}")) {
            this._AddError("'{' is not closed", open.pos, 1, open.line, open.col)
            throw ExprAbort("")
        }
        this.i += 1
        this.last := tok
        this._Leave()
        return ExprNode.BlockNode(open, tok.End, body)
    }

    _If() {
        ifTok := this._Next()
        this._Enter(ifTok)
        t := this._Cur()
        cond := ""
        if (t.type == "NL" || t.type == "EOF")
            this._FailTok("a condition is expected after 'if'", t)
        nest0 := this.nest
        try {
            cond := this._ParseAssign()
        } catch ExprAbort {
            this._Recover(nest0)
            cond := ExprNode.EmptyNode(ifTok)
        }
        this._SkipNl()
        if (this.toks[this.i].type == "EOF")
            this._FailTok("a statement is expected after the condition of 'if'", ifTok)
        thenStmt := this._Statement()
        elseStmt := ""
        j := this.i
        this._SkipNl()
        if (this.toks[this.i].type == "WORD" && this.toks[this.i].kw == "else") {
            elseTok := this._Next()
            this._SkipNl()
            if (this.toks[this.i].type == "EOF")
                this._FailTok("a statement is expected after 'else'", elseTok)
            elseStmt := this._Statement()
        } else
            this.i := j
        this._Leave()
        endPos := (elseStmt == "") ? thenStmt["end"] : elseStmt["end"]
        return ExprNode.IfNode(ifTok, endPos, cond, thenStmt, elseStmt)
    }

    ; ---------------------------------------------------------------- expressions

    _ParseAssign() {
        left := this._ParseOr()
        tok := this._Cur()
        if (tok.type == "OP" && ExprParser.ASSIGN_OPS.Has(tok.text)) {
            lt := left["type"]
            if (lt != "Var" && lt != "DynVar" && lt != "Index")
                this._FailNode("the left side of '" tok.text "' must be a variable or a path (a.b, a[i])", left)
            this._Next()
            this._SkipNl()
            this._Enter(tok)
            right := this._ParseAssign()
            this._Leave()
            return this._Check(ExprNode.AssignNode(tok.text, left, right))
        }
        return left
    }

    _ParseOr() {
        left := this._ParseAnd()
        loop {
            tok := this._Cur()
            if (!(tok.IsOp("||") || (tok.type == "WORD" && tok.kw == "or")))
                break
            this._Next()
            this._SkipNl()
            right := this._ParseAnd()
            left := this._Check(ExprNode.BinaryNode("||", left, right))
        }
        return left
    }

    _ParseAnd() {
        left := this._ParseNot()
        loop {
            tok := this._Cur()
            if (!(tok.IsOp("&&") || (tok.type == "WORD" && tok.kw == "and")))
                break
            this._Next()
            this._SkipNl()
            right := this._ParseNot()
            left := this._Check(ExprNode.BinaryNode("&&", left, right))
        }
        return left
    }

    _ParseNot() {
        tok := this._Cur()
        if (tok.type == "WORD" && tok.kw == "not") {
            this._Next()
            this._SkipNl()
            this._Enter(tok)
            operand := this._ParseNot()
            this._Leave()
            return this._Check(ExprNode.UnaryNode(tok, "!", operand))
        }
        return this._ParseEquality()
    }

    _ParseEquality() {
        left := this._ParseRelational()
        loop {
            tok := this._Cur()
            if (tok.type != "OP")
                break
            op := tok.text
            if (!(op == "=" || op == "==" || op == "!=" || op == "!=="))
                break
            this._Next()
            this._SkipNl()
            right := this._ParseRelational()
            left := this._Check(ExprNode.BinaryNode(op, left, right))
        }
        return left
    }

    _ParseRelational() {
        left := this._ParseConcat()
        loop {
            tok := this._Cur()
            if (tok.type != "OP")
                break
            op := tok.text
            if (!(op == "<" || op == ">" || op == "<=" || op == ">="))
                break
            this._Next()
            this._SkipNl()
            right := this._ParseConcat()
            left := this._Check(ExprNode.BinaryNode(op, left, right))
        }
        return left
    }

    ; Concatenation: " . " and, with nothing between, two operands behind each other.
    _ParseConcat() {
        left := this._ParseAdd()
        loop {
            tok := this._Cur()
            if (tok.IsOp(".") && !tok.member) {
                nx := this._After()
                if (!(tok.ws && (nx.ws || nx.type == "NL")))
                    this._FailTok("the concatenation operator '.' needs a space before and after it", tok)
                this._Next()
                this._SkipNl()
            } else if (!this._StartsOperand(tok))
                break
            right := this._ParseAdd()
            left := this._Check(ExprNode.BinaryNode(".", left, right))
        }
        return left
    }

    ; True if tok can start the second operand of an implicit concatenation.
    _StartsOperand(tok) {
        switch tok.type {
            case "STR", "NUM":
                return true
            case "WORD":
                return (tok.kw == "" || tok.kw == "true" || tok.kw == "false")
            case "OP":
                if (tok.text == "(")
                    return tok.ws
                if (tok.text == "%") {
                    if (this.pct > 0)
                        return false
                    ; " % " with space on both sides looks like a modulo operator: report that
                    return !(tok.ws && this._After().ws)
                }
        }
        return false
    }

    _ParseAdd() {
        left := this._ParseMul()
        loop {
            tok := this._Cur()
            if (!(tok.IsOp("+") || tok.IsOp("-")))
                break
            this._Next()
            this._SkipNl()
            right := this._ParseMul()
            left := this._Check(ExprNode.BinaryNode(tok.text, left, right))
        }
        return left
    }

    _ParseMul() {
        left := this._ParseUnary()
        loop {
            tok := this._Cur()
            if (!(tok.IsOp("*") || tok.IsOp("/") || tok.IsOp("//")))
                break
            this._Next()
            this._SkipNl()
            right := this._ParseUnary()
            left := this._Check(ExprNode.BinaryNode(tok.text, left, right))
        }
        return left
    }

    _ParseUnary() {
        tok := this._Cur()
        if (tok.IsOp("-") || tok.IsOp("!")) {
            this._Next()
            this._SkipNl()
            this._Enter(tok)
            operand := this._ParseUnary()
            this._Leave()
            return this._Check(ExprNode.UnaryNode(tok, tok.text, operand))
        }
        if (tok.IsOp("+"))
            this._FailTok("the unary '+' is not supported", tok)
        return this._ParsePostfix()
    }

    _ParsePostfix() {
        node := this._ParsePrimary()
        loop {
            tok := this._Cur()
            if (tok.type != "OP")
                break
            if (tok.text == "(" && !tok.ws) {
                t := node["type"]
                if (t != "Var" && t != "DynVar" && t != "Index")
                    this._FailTok("only a function or a method can be called", tok)
                node := this._Call(node)
            } else if (tok.text == "[" && !tok.ws)
                node := this._Bracket(node)
            else if (tok.text == "." && tok.member)
                node := this._Member(node)
            else
                break
        }
        return node
    }

    _Call(callee) {
        open := this._Next()
        saved := this.pct
        this.pct := 0
        this.depth += 1
        this._Enter(open)
        this._NotAtEnd(open)
        argList := []
        tok := this._Cur()
        if (!tok.IsOp(")")) {
            loop {
                tok := this._Cur()
                if (tok.IsOp(",") || tok.IsOp(")"))
                    this._FailTok("an argument is expected", tok)
                argList.Push(this._ParseAssign())
                tok := this._Cur()
                if (tok.IsOp(","))
                    this._Next()
                else
                    break
            }
        }
        close := this._Close(")", open)
        this._Leave()
        this.depth -= 1
        this.pct := saved
        return this._Check(ExprNode.CallNode(callee, argList, close.End))
    }

    _Bracket(obj) {
        open := this._Next()
        saved := this.pct
        this.pct := 0
        this.depth += 1
        this._Enter(open)
        this._NotAtEnd(open)
        if (this._Cur().IsOp("]"))
            this._FailTok("an expression is expected between '[' and ']'", this._Cur())
        key := this._ParseAssign()
        close := this._Close("]", open)
        this._Leave()
        this.depth -= 1
        this.pct := saved
        return this._Check(ExprNode.IndexNode(obj, key, 0, close.End))
    }

    _Member(obj) {
        this._Next()
        nt := this._Cur()
        if (!(nt.type == "WORD" || nt.IsOp("%")))
            this._Unexpected(nt, "a name is expected after '.'")
        key := this._NameParts(true)
        return this._Check(ExprNode.IndexNode(obj, key, 1, this.last.End))
    }

    ; Reports the opening bracket as not closed if the input ends right behind it.
    _NotAtEnd(openTok) {
        if (this._Cur().type == "EOF") {
            this._AddError("'" openTok.text "' is not closed", openTok.pos, 1, openTok.line, openTok.col)
            throw ExprAbort("")
        }
    }

    ; Consumes the closing bracket text, or reports the unclosed opening bracket.
    _Close(text, openTok) {
        tok := this._Cur()
        if (tok.IsOp(text))
            return this._Next()
        if (tok.type == "EOF") {
            this._AddError("'" openTok.text "' is not closed", openTok.pos, 1, openTok.line, openTok.col)
            throw ExprAbort("")
        }
        this._Unexpected(tok, "expected '" text "'")
    }

    _ParsePrimary() {
        tok := this._Cur()
        switch tok.type {
            case "NUM":
                this._Next()
                return ExprNode.NumberNode(tok, tok.value)
            case "STR":
                this._Next()
                return ExprNode.StringNode(tok, tok.value)
            case "WORD":
                if (tok.kw == "true" || tok.kw == "false") {
                    this._Next()
                    return ExprNode.NumberNode(tok, (tok.kw == "true") ? 1 : 0)
                }
                if (tok.kw == "if" || tok.kw == "else")
                    this._FailTok("'" tok.text "' is only valid at the start of a line of a script", tok)
                if (tok.kw != "")
                    this._Unexpected(tok, "an operand is expected")
                return this._NameParts(false)
            case "OP":
                if (tok.text == "(")
                    return this._Paren()
                if (tok.text == "%" && this.pct = 0)
                    return this._NameParts(false)
        }
        this._Unexpected(tok, "an operand is expected")
    }

    _Paren() {
        open := this._Next()
        saved := this.pct
        this.pct := 0
        this.depth += 1
        this._Enter(open)
        this._NotAtEnd(open)
        if (this._Cur().IsOp(")"))
            this._FailTok("an expression is expected between '(' and ')'", this._Cur())
        parsed := this._ParseAssign()
        close := this._Close(")", open)
        ; the span of the node includes the parentheses
        parsed["pos"] := open.pos
        parsed["line"] := open.line
        parsed["col"] := open.col
        parsed["end"] := close.End
        this._Leave()
        this.depth -= 1
        this.pct := saved
        return parsed
    }

    ; A name made of words and %expression% parts that touch each other (a, a%i%, %n%, ro%x%nd, a%i+1%b).
    ; asKey = false: returns Var or DynVar. asKey = true (name after a "."): returns the expression for the key:
    ; a String (or Number for digits), the expression inside a lone %...%, or a concatenation of the parts.
    _NameParts(asKey) {
        parts := []
        first := this._Cur()
        allStatic := true
        lastEnd := first.End
        loop {
            tok := this._Cur()
            if (parts.Length > 0 && tok.ws)
                break
            if (tok.type == "WORD") {
                if (parts.Length > 0 && tok.member)
                    break
                this._Next()
                parts.Push(ExprNode.StringNode(tok, tok.text))
                lastEnd := tok.End
            } else if (tok.type == "NUM" && parts.Length > 0 && RegExMatch(tok.text, "^[0-9]+$")) {
                this._Next()
                parts.Push(ExprNode.StringNode(tok, tok.text))
                lastEnd := tok.End
            } else if (tok.IsOp("%")) {
                if (this.pct > 0)
                    break
                open := this._Next()
                allStatic := false
                this.pct := 1
                this._Enter(open)
                if (this._Cur().IsOp("%"))
                    this._FailTok("an expression is expected between the '%' signs", this._Cur())
                parsed := this._ParseAssign()
                this._Leave()
                this.pct := 0
                cl := this._Cur()
                if (!cl.IsOp("%")) {
                    if (cl.type == "EOF" || cl.type == "NL") {
                        this._AddError("'%' is not closed (the modulo operator '%' is not supported)", open.pos, 1, open.line, open.col)
                        throw ExprAbort("")
                    }
                    this._Unexpected(cl, "expected '%'")
                }
                this._Next()
                parts.Push(parsed)
                lastEnd := cl.End
            } else
                break
        }
        if (asKey) {
            if (allStatic) {
                tok := first
                if (RegExMatch(tok.text, "^(?:0|[1-9][0-9]*)$") && StrLen(tok.text) <= 18)
                    return ExprNode.NumberNode(tok, Integer(tok.text))
                return parts[1]
            }
            key := parts[1]
            loop parts.Length - 1
                key := this._Check(ExprNode.BinaryNode(".", key, parts[A_Index + 1]))
            return key
        }
        if (allStatic)
            return ExprNode.VarNode(first)
        return this._Check(ExprNode.DynVarNode(first, lastEnd, parts))
    }
}
