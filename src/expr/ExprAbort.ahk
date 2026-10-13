#Requires AutoHotkey v2.0

; Thrown inside ExprParser to leave a syntax error behind; the parser catches it itself, so it never
; reaches the caller. The error is already recorded when this is thrown.
class ExprAbort extends Error {
}
