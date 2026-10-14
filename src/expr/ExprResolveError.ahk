#Requires AutoHotkey v2.0

; Thrown by a resolver (the object that gives the evaluator access to variables) when the request cannot
; be met because of the user's expression, e.g. a member of a text value, or a variable that is read-only.
; The evaluator catches it, records an error with the position and goes on with the empty text.
; Any other exception from a resolver is an internal error and is not caught.
class ExprResolveError extends Error {
}
