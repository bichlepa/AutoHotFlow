#Requires AutoHotkey v2.0
#Include ..\..\core\Errors.ahk
#Include ..\vars\VarJson.ahk

; The copy of the variables of a branch at an unhandled exception (WI-0113, REQ-USE-080 part 2, E0072, PROTOCOL 4.7a).
;
; Take is called only when an error happens (Engine.FlowException); nothing here runs on the hot path. It reads the
; loop variables of the current loop level, the thread variables and the instance variables, and turns every value into
; text at once, so the copy does not follow later changes. The hidden tables are not copied (they keep values from the
; user), nor the global and static variables (not part of the branch) nor the built-in A_ names (computed).
;
; Bounds per error: MAX_VARS variables and MAX_BYTES of names and values together; the rest is counted as omitted. A value
; longer than MAX_VALUE_CHARS is cut. An object is stored as its JSON text before the cut: an object of very many members
; is still converted in full (not bounded in time, a known limit).
class ErrorSnapshot {
    static MAX_VARS := 200
    static MAX_BYTES := 65536
    static MAX_VALUE_CHARS := 1000

    ; Returns Map("vars", Array of Map(scope, name, value), "omitted", n). scope is "loop", "thread" or "instance".
    static Take(instance, thread) {
        out := []
        omitted := 0
        bytes := 0
        sources := [["loop", thread.Loops.Visible], ["thread", thread.Vars], ["instance", instance.Vars]]
        for source in sources {
            scope := source[1]
            for name, value in source[2] {
                if (out.Length >= ErrorSnapshot.MAX_VARS) {   ; full: count only, do not convert the value (bounds the time)
                    omitted += 1
                    continue
                }
                nameText := String(name)
                text := ErrorSnapshot.Text(value)
                size := StrLen(nameText) + StrLen(text)
                if (bytes + size > ErrorSnapshot.MAX_BYTES) {
                    omitted += 1
                    continue
                }
                bytes += size
                out.Push(Map("scope", scope, "name", nameText, "value", text))
            }
        }
        return Map("vars", out, "omitted", omitted)
    }

    ; The text of one value: a text or a number as it is, an object as JSON, cut to MAX_VALUE_CHARS.
    static Text(value) {
        text := IsObject(value) ? VarJson.Stringify(value) : String(value)
        if (StrLen(text) > ErrorSnapshot.MAX_VALUE_CHARS)
            text := SubStr(text, 1, ErrorSnapshot.MAX_VALUE_CHARS) "..."
        return text
    }
}
