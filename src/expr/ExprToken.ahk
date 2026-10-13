#Requires AutoHotkey v2.0

; One token of the expression language (doc/EXPRESSION-LANGUAGE.md section 16).
;
; type: "NUM" (value is an Integer or Float), "STR" (value is the decoded text), "WORD" (name or keyword),
;       "OP" (operator or punctuation, text is the source text), "NL" (line break, script form only),
;       "ERR" (text that could not be read; the error is already recorded), "EOF".
; pos:  1-based index of the first character in the source. len: length in characters.
; line, col: 1-based position of the first character (columns count UTF-16 code units).
; ws:   true if whitespace, a comment, a line break or the start of the input comes directly before the token.
; kw:   for WORD: the lower case spelling if it is a keyword (and, or, not, if, else, true, false), else "".
; member: true for the "." of a member access and for the name that follows it.
class ExprToken {
    type := ""
    text := ""
    value := ""
    pos := 0
    len := 0
    line := 0
    col := 0
    ws := false
    kw := ""
    member := false

    __New(type, text, pos, len, line, col, ws) {
        this.type := type
        this.text := text
        this.pos := pos
        this.len := len
        this.line := line
        this.col := col
        this.ws := ws
    }

    ; Index of the first character after the token.
    End => this.pos + this.len

    ; True for an operator token with exactly this text.
    IsOp(text) => (this.type == "OP" && this.text == text)
}
