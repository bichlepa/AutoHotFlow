#Requires AutoHotkey v2.0
#Include Errors.ahk
#Include Json.ahk
#Include Log.ahk
#Include Time.ahk

; Debug.Dump(value, title := "") replaces the v1 function d() (v1/Source_Common/Debug/Debug.ahk, WI-28,
; doc/PROTOCOL.md 4.9). It turns any value into readable JSON and sends it as evt.debug.dump to the topic
; "debug", where the debug window shows it.
;
;   Debug.Dump(myMap, "state of the loop")
;
; Rules (it is called from anywhere, also from elements and from error handlers):
;   - It never blocks: one non-blocking send through the peer of the running role, no wait, no answer.
;   - It never throws: whatever goes wrong (no role, no connection, a value that cannot be written) is counted
;     in `failed` and the call returns false.
;   - It does nothing without a running role with a ready connection. Nobody subscribed: the hub drops the event.
;   - At most MAX_PER_SECOND calls per second and process are sent, the rest is counted in `dropped`.
;   - The value is converted by Render: depth at most MAX_DEPTH, at most MAX_ITEMS entries per Map or Array,
;     cycles and objects that are not data (functions, COM, class instances) become "<Type>" or "<cycle>",
;     text over MAX_CHARS is cut (`truncated`).
;
; Counters for tests and the snapshot: Debug.sent, Debug.dropped, Debug.failed.
class Debug {
    static MAX_PER_SECOND := 100
    static MAX_DEPTH := 8
    static MAX_ITEMS := 200
    static MAX_CHARS := 60000
    static TOPIC := "topic:debug"

    static sent := 0
    static dropped := 0
    static failed := 0
    static _windowStart := 0
    static _windowCount := 0

    ; Returns true when the event went out, false otherwise. Never throws.
    static Dump(value, title := "") {
        try {
            return Debug._Send(value, title)
        } catch {
            ; Counted instead of reported: this runs in the middle of other code and must not add failures to it.
            Debug.failed += 1
            return false
        }
    }

    ; The text that Dump sends: Map("json", text, "cut", 0/1). Exposed for the tests and the debug window.
    static Render(value) {
        seen := Map()
        text := Json.Stringify(Debug._Plain(value, 1, seen), 2)
        if (StrLen(text) > Debug.MAX_CHARS)
            return Map("json", SubStr(text, 1, Debug.MAX_CHARS) "`n... (cut)", "cut", 1)
        return Map("json", text, "cut", 0)
    }

    static _Send(value, title) {
        owner := Role.Current
        if (!IsObject(owner) || !IsObject(owner.peer) || owner.peer.status != "ready")
            return false
        now := Time.NowMs()
        if (now - Debug._windowStart >= 1000) {
            Debug._windowStart := now
            Debug._windowCount := 0
        }
        if (Debug._windowCount >= Debug.MAX_PER_SECOND) {
            Debug.dropped += 1
            return false
        }
        Debug._windowCount += 1
        rendered := Debug.Render(value)
        id := owner.peer.Send(Debug.TOPIC, "evt.debug.dump", Map("title", String(title)
            , "ts", FormatTime(A_NowUTC, "yyyy-MM-dd HH:mm:ss"), "json", rendered["json"]
            , "truncated", Json.Bool(rendered["cut"])))
        if (id = "")
            return false
        Debug.sent += 1
        return true
    }

    ; value as data the JSON writer accepts: Map, Array, String, Integer, Float, Json.True/False/Null. level counts from 1.
    static _Plain(value, level, seen) {
        if (value == Json.Null || value == Json.True || value == Json.False)
            return value
        if (!IsObject(value)) {
            t := Type(value)
            return (t = "Integer" || t = "Float" || t = "String") ? value : String(value)
        }
        if (seen.Has(ObjPtr(value)))
            return "<cycle>"
        isMap := value is Map
        isArray := value is Array
        isPlain := (Type(value) = "Object")
        if (!isMap && !isArray && !isPlain)
            return "<" Type(value) ">"
        if (level > Debug.MAX_DEPTH)
            return "<" Type(value) ", too deep>"
        seen[ObjPtr(value)] := true
        out := isArray ? [] : Map()
        n := 0
        if (isArray) {
            for item in value {
                if (++n > Debug.MAX_ITEMS) {
                    out.Push("... (" (value.Length - Debug.MAX_ITEMS) " more)")
                    break
                }
                out.Push(Debug._Plain(item, level + 1, seen))
            }
        } else if (isMap) {
            for key, item in value {
                if (++n > Debug.MAX_ITEMS) {
                    out["..."] := (value.Count - Debug.MAX_ITEMS) " more"
                    break
                }
                out[String(key)] := Debug._Plain(item, level + 1, seen)
            }
        } else {
            for key, item in value.OwnProps() {
                if (++n > Debug.MAX_ITEMS) {
                    out["..."] := "more"
                    break
                }
                out[String(key)] := Debug._Plain(item, level + 1, seen)
            }
        }
        seen.Delete(ObjPtr(value))
        return out
    }
}
