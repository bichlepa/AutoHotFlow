#Requires AutoHotkey v2.0

; Error records of the parser (doc/AUSDRUECKE.md section 10). An error is a Map:
;   message   text for the user (English, not translated)
;   line, col 1-based position of the error
;   pos       1-based index of the first character in the source text
;   length    number of characters marked (0 at the end of the input)
;   lineText  the source line without its line break
;   marked    the line with the marked part, in the form of v1 "wholelinehighlighted":
;             <before> -> <marked part> <- <after>
class ExprDiag {
    ; Longest line shown in "marked"; longer lines are cut around the marker.
    static MAX_SHOWN := 160

    static Make(text, message, pos, length, line, col) {
        lineStart := pos - col + 1
        lineEnd := InStr(text, "`n", true, pos)
        if (lineEnd = 0)
            lineEnd := StrLen(text) + 1
        lineText := SubStr(text, lineStart, lineEnd - lineStart)
        if (SubStr(lineText, -1) == "`r")
            lineText := SubStr(lineText, 1, StrLen(lineText) - 1)
        err := Map()
        err["message"] := message
        err["line"] := line
        err["col"] := col
        err["pos"] := pos
        err["length"] := length
        err["lineText"] := lineText
        err["marked"] := ExprDiag.Mark(lineText, col, length)
        return err
    }

    ; The line with the part [col, col + length) between "-> " and " <-".
    static Mark(lineText, col, length) {
        before := SubStr(lineText, 1, col - 1)
        part := SubStr(lineText, col, length)
        after := SubStr(lineText, col + length)
        limit := ExprDiag.MAX_SHOWN
        if (StrLen(before) > limit)
            before := "..." SubStr(before, -limit + 3)
        if (StrLen(after) > limit)
            after := SubStr(after, 1, limit - 3) "..."
        if (StrLen(part) > limit)
            part := SubStr(part, 1, limit - 3) "..."
        return before "-> " part " <-" after
    }

    ; One line of text for a list of errors: "line 2, column 5: message" and the marked line below.
    static Format(err) {
        return "line " err["line"] ", column " err["col"] ": " err["message"] "`n" err["marked"]
    }

    ; All errors of a parse result, one block each.
    static FormatAll(errors) {
        out := ""
        for err in errors
            out .= (A_Index = 1 ? "" : "`n") ExprDiag.Format(err)
        return out
    }
}
