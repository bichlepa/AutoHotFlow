#Requires AutoHotkey v2.0
#Include Errors.ahk
#Include Log.ahk
#Include ProcInfo.ahk

; Builds the parts of a diagnostic snapshot that every process has in the same form (doc/PROTOCOL.md 4.9,
; WI-0028): the general part (Role.Snapshot and the supervisor use it), the log part and the errors part.
; A snapshot holds names, ids, counters and states, never the content of variables or flows.
;
;   snap := Snapshot.General(name, role)               ; Map: schema, name, role, pid, startedAt, ... handles
;   snap["log"] := Snapshot.LogPart(queued, dropped)
;   snap["errors"] := Snapshot.ErrorsPart(count, list) ; list: Maps with ts, errorType, message, file, line, stack, mode
class Snapshot {
    static SCHEMA := 1
    static LOG_ENTRIES := 100
    static ERROR_ENTRIES := 20
    static TEXT_MAX := 500

    static General(name, role) {
        snap := ProcInfo.General()
        snap["schema"] := Snapshot.SCHEMA
        snap["name"] := name
        snap["role"] := role
        return snap
    }

    ; The log of this process: counters of the sink queue, of Log, and the newest entries of the ring.
    static LogPart(queued, dropped) {
        recent := []
        for entry in Log.Recent(Snapshot.LOG_ENTRIES) {
            recent.Push(Map("ts", Snapshot.Stamp(entry["ts"]), "level", entry["level"], "source", entry["source"]
                , "text", Snapshot.Cut(entry["text"])))
        }
        return Map("queued", queued, "dropped", dropped, "sinkErrors", Log.sinkErrors
            , "lastSinkError", Snapshot.Cut(Log.lastSinkError), "level", Log.level, "recent", recent
            , "levels", [Log.LevelFor("a0"), Log.LevelFor("f0"), Log.LevelFor("t0")])
    }

    ; count: all unhandled errors so far; list: the newest ones (Maps). Only the newest ERROR_ENTRIES are kept.
    static ErrorsPart(count, list) {
        recent := []
        start := Max(1, list.Length - Snapshot.ERROR_ENTRIES + 1)
        loop list.Length - start + 1 {
            e := list[start + A_Index - 1]
            line := e.Get("line", 0)
            recent.Push(Map("ts", e.Get("ts", ""), "errorType", String(e.Get("errorType", "")), "message", Snapshot.Cut(String(e.Get("message", "")))
                , "file", String(e.Get("file", "")), "line", IsInteger(line) ? Integer(line) : 0
                , "stack", String(e.Get("stack", "")), "mode", String(e.Get("mode", ""))))
        }
        return Map("count", count, "recent", recent)
    }

    ; "20261012153045" (A_NowUTC) -> "2026-10-12 15:30:45"
    static Stamp(raw) {
        return (StrLen(raw) = 14) ? FormatTime(raw, "yyyy-MM-dd HH:mm:ss") : String(raw)
    }

    static Cut(text) {
        text := String(text)
        return (StrLen(text) > Snapshot.TEXT_MAX) ? SubStr(text, 1, Snapshot.TEXT_MAX) "..." : text
    }

    ; The snapshot part for one answer that failed: used where a role part cannot be built.
    static InfoError(e) => Map("error", Type(e) ": " e.Message)
}
