#Requires AutoHotkey v2.0
#Include ExprToken.ahk
#Include ExprNames.ahk
#Include ExprDiag.ahk

; Tokenizer of the expression language (doc/EXPRESSION-LANGUAGE.md sections 2 to 5 and 16).
;
; Usage: tk := ExprTokenizer(text, script), tk.Run(), then tk.tokens (Array of ExprToken, the last one is
; always the EOF token) and tk.errors (Array of error Maps, see ExprDiag). Nothing is thrown for bad
; input: text that cannot be read becomes an "ERR" token plus an entry in tk.errors, and scanning goes on.
;
; script = false (expression form): line breaks are whitespace.
; script = true  (script form): line breaks are "NL" tokens (several in a row become one).
;
; The scan uses one RegExMatch per token part, not one call per character (doc/HOW-TO.md, performance).
class ExprTokenizer {
    static MAX_ERRORS := 50

    static WS_RX := "A)[ \t\r\x0B\x0C]+"
    static WORD_RX := "A)[A-Za-z0-9_\x{80}-\x{10FFFF}]+"
    static NUM_RX := "A)(?:0[xX][0-9A-Fa-f]+|[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|\.[0-9]+(?:[eE][+-]?[0-9]+)?)"
    static OP_RX := "A)(?:!==|//=|\*\*=|<<=|>>=|>>>|:=|\+=|-=|\*=|/=|\.=|%=|\^=|\|=|&=|==|!=|<=|>=|<>|&&|\|\||\+\+|--|\*\*|<<|>>|//|\?\?|~=|=>|[-+*/<>=!.,()\[\]{}%:?&|^~])"
    ; Strings: the run up to the next quote, escape character or line break.
    static DQ_RX := 'A)[^"\r\n``]*'
    static SQ_RX := "A)[^'\r\n``]*"

    text := ""
    script := false
    tokens := []
    errors := []

    ; State of the scan.
    _pos := 1
    _line := 1
    _lineStart := 1
    _ws := true

    __New(text, script := false) {
        this.text := text
        this.script := script
    }

    Run() {
        text := this.text
        n := StrLen(text)
        this.tokens := []
        this.errors := []
        this._pos := 1
        this._line := 1
        this._lineStart := 1
        this._ws := true
        while (this._pos <= n) {
            pos := this._pos
            if (RegExMatch(text, ExprTokenizer.WS_RX, &m, pos)) {
                this._pos := pos += m.Len
                this._ws := true
                if (pos > n)
                    break
            }
            c := SubStr(text, pos, 1)
            if (c == "`n") {
                if (this.script && !(this.tokens.Length > 0 && this.tokens[-1].type == "NL"))
                    this._Add("NL", "`n", pos, 1)
                this._line += 1
                this._lineStart := pos + 1
                this._pos := pos + 1
                this._ws := true
                continue
            }
            if (c == ";") {
                if (!this._ws)
                    this._Error("a comment must be preceded by a space or tab", pos, 1)
                else {
                    e := InStr(text, "`n", true, pos)
                    this._pos := (e = 0) ? n + 1 : e
                    continue
                }
                this._pos := pos + 1
                this.tokens.Push(this._Make("ERR", ";", pos, 1))
                this._ws := false
                continue
            }
            if (c == '"' || c == "'") {
                this._String(c)
                continue
            }
            code := Ord(c)
            if (code >= 0x30 && code <= 0x39) {
                this._Number()
                continue
            }
            if (c == "." && this._ScanDot())
                continue
            if (c == "." && RegExMatch(text, "A)\.[0-9]", , pos)) {
                this._Number()
                continue
            }
            if (ExprNames.IsWordChar(c)) {
                RegExMatch(text, ExprTokenizer.WORD_RX, &m, pos)
                w := m[0]
                tok := this._Add("WORD", w, pos, m.Len)
                tok.kw := ExprNames.Keyword(w)
                continue
            }
            if (RegExMatch(text, ExprTokenizer.OP_RX, &m, pos)) {
                this._Add("OP", m[0], pos, m.Len)
                continue
            }
            ; Anything else cannot be part of the language.
            len := 1
            if (code >= 0xD800 && code <= 0xDBFF)
                len := 2
            ch := SubStr(text, pos, len)
            if (c == "``")
                this._Error("the escape character `` is only valid inside a string", pos, 1)
            else
                this._Error("unexpected character '" ch "'", pos, len)
            this._pos := pos + len
            this.tokens.Push(this._Make("ERR", ch, pos, len))
            this._ws := false
        }
        eof := this._Make("EOF", "", n + 1, 0)
        eof.ws := true
        this.tokens.Push(eof)
        return this
    }

    ; Token at the current position with the line and column of the scan.
    _Make(type, text, pos, len) {
        return ExprToken(type, text, pos, len, this._line, pos - this._lineStart + 1, this._ws)
    }

    ; Makes a token, stores it, moves the scan behind it.
    _Add(type, text, pos, len) {
        tok := this._Make(type, text, pos, len)
        this.tokens.Push(tok)
        this._pos := pos + len
        this._ws := false
        return tok
    }

    _Error(message, pos, length) {
        if (this.errors.Length >= ExprTokenizer.MAX_ERRORS)
            return
        this.errors.Push(ExprDiag.Make(this.text, message, pos, length, this._line, pos - this._lineStart + 1))
    }

    ; An ERR token for text that was reported as an error, and the scan moves behind it.
    _Bad(message, pos, len) {
        this._Error(message, pos, len)
        tok := this._Add("ERR", SubStr(this.text, pos, len), pos, len)
        return tok
    }

    ; "." directly behind a value and directly in front of a name or "%" is the member operator; then the
    ; name is scanned here as a plain word, so that it can be a number (a.1) or a keyword (a.and).
    ; Returns true if the dot was handled.
    _ScanDot() {
        pos := this._pos
        text := this.text
        if (this._ws || this.tokens.Length = 0)
            return false
        prev := this.tokens[-1]
        isValue := (prev.type == "WORD") || (prev.type == "OP" && (prev.text == ")" || prev.text == "]" || prev.text == "%"))
        if (!isValue)
            return false
        nx := SubStr(text, pos + 1, 1)
        if (nx == "%") {
            dot := this._Add("OP", ".", pos, 1)
            dot.member := true
            return true
        }
        if (nx == "" || !ExprNames.IsWordChar(nx))
            return false
        dot := this._Add("OP", ".", pos, 1)
        dot.member := true
        RegExMatch(text, ExprTokenizer.WORD_RX, &m, pos + 1)
        name := this._Add("WORD", m[0], pos + 1, m.Len)
        name.member := true
        return true
    }

    _Number() {
        pos := this._pos
        text := this.text
        RegExMatch(text, ExprTokenizer.NUM_RX, &m, pos)
        s := m[0]
        after := SubStr(text, pos + m.Len, 1)
        bad := (after != "" && ExprNames.IsWordChar(after))
        if (!bad && after == "." && RegExMatch(text, "A)\.[0-9]", , pos + m.Len))
            bad := true
        if (bad) {
            ; swallow the whole word so that only one error is reported
            RegExMatch(text, "A)[A-Za-z0-9_.\x{80}-\x{10FFFF}]+", &w, pos)
            this._Bad("invalid number or name '" w[0] "'", pos, w.Len)
            return
        }
        value := ""
        if (SubStr(s, 1, 2) = "0x") {
            digits := LTrim(SubStr(s, 3), "0")
            if (StrLen(digits) > 16 || (StrLen(digits) = 16 && RegExMatch(digits, "^[89A-Fa-f]"))) {
                this._Bad("hexadecimal number '" s "' is too large (63 bits at most)", pos, m.Len)
                return
            }
            value := Integer(s)
        } else if (RegExMatch(s, "^[0-9]+$")) {
            digits := LTrim(s, "0")
            if (StrLen(digits) > 19 || (StrLen(digits) = 19 && StrCompare(digits, "9223372036854775807") > 0))
                value := Float(s)
            else
                value := (digits = "") ? 0 : Integer(digits)
        } else
            value := Float(s)
        tok := this._Add("NUM", s, pos, m.Len)
        tok.value := value
    }

    _String(q) {
        text := this.text
        start := this._pos
        n := StrLen(text)
        i := start + 1
        out := ""
        rx := (q == '"') ? ExprTokenizer.DQ_RX : ExprTokenizer.SQ_RX
        closed := false
        badEscape := false
        loop {
            RegExMatch(text, rx, &m, i)
            out .= m[0]
            i += m.Len
            ch := SubStr(text, i, 1)
            if (ch == q) {
                i += 1
                closed := true
                break
            }
            if (ch == "``") {
                nx := SubStr(text, i + 1, 1)
                if (nx == "" || nx == "`n" || nx == "`r") {
                    i += 1
                    break
                }
                ; a character outside the BMP is two code units: do not cut it in half
                if (Ord(nx) >= 0xD800 && Ord(nx) <= 0xDBFF)
                    nx := SubStr(text, i + 1, 2)
                dec := ExprTokenizer.Escape(nx)
                if (dec == "") {
                    this._Error("unknown escape sequence ``" nx, i, 1 + StrLen(nx))
                    badEscape := true
                } else
                    out .= dec
                i += 1 + StrLen(nx)
                continue
            }
            break
        }
        len := i - start
        if (!closed) {
            this._Bad("the string is not closed", start, len)
            return
        }
        if (badEscape) {
            tok := this._Add("ERR", SubStr(text, start, len), start, len)
            return
        }
        ; Two strings directly behind each other: v1 wrote a quote inside a string as "".
        prev := (this.tokens.Length > 0) ? this.tokens[-1] : ""
        if (prev != "" && prev.type == "STR" && !this._ws && prev.End = start) {
            this._Error("two string literals directly behind each other; write a quote inside a string as ``" q, start, len)
            tok := this._Add("ERR", SubStr(text, start, len), start, len)
            return
        }
        tok := this._Add("STR", SubStr(text, start, len), start, len)
        tok.value := out
    }

    ; Escape sequences: the character after the escape character and the character it stands for.
    ; A Map compares keys case-sensitively, so `N is not `n.
    static ESC := Map("n", "`n", "r", "`r", "t", "`t", "b", Chr(8), "v", Chr(11), "a", Chr(7), "f", Chr(12),
        '"', '"', "'", "'", "``", "``", ";", ";", "%", "%", ",", ",", ":", ":", "{", "{", "}", "}")

    ; The character that stands for the escape sequence `nx, or "" if there is none.
    static Escape(nx) => ExprTokenizer.ESC.Get(nx, "")
}
