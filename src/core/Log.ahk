#Requires AutoHotkey v2.0
#Include Errors.ahk

; Log client. Core writes nothing by itself: the role configures a sink (storage process, console, test).
; Levels as in v1: a0..a3 (general), f0..f3 (flow), t0..t3 (trigger). Smaller digit = less detail.
;
; Two things happen to every entry (WI-23):
;   - It is kept in a ring of the last RING_MAX entries (all levels, whatever the sink), for the crash report.
;   - It goes to the sink only if its digit is not above Log.level (default of a role: DEFAULT_LEVEL = 2, option
;     --log-level=<0..3>). Level 3 therefore stays in the ring only, unless the level is raised.
class Log {
    static sink := ""
    static sinkErrors := 0
    static lastSinkError := ""
    static memoryLines := []
    static RING_MAX := 500
    static DEFAULT_LEVEL := 2
    static ring := []
    ; Highest level digit that reaches the sink. The library default lets everything pass (unit tests, tools);
    ; Role.Start and the supervisor set DEFAULT_LEVEL or the value of --log-level.
    static level := 3

    ; sink: function(level, source, text, flowId). Pass "" to disable logging.
    static Configure(sink) {
        this.sink := sink
    }

    static SetLevel(digit) {
        this.level := digit
    }

    ; "--log-level" text or number -> Integer 0..3. Throws AhfError (bad_args) for anything else.
    static ParseLevel(raw) {
        if (!IsInteger(raw) || Integer(raw) < 0 || Integer(raw) > 3)
            throw AhfError("--log-level must be 0, 1, 2 or 3 (got '" raw "')", ErrCode.BAD_ARGS)
        return Integer(raw)
    }

    ; The last entries of the ring (oldest first); count 0 = all. Each one is a Map: ts (UTC, yyyyMMddHHmmss),
    ; level, source, text, flowId.
    static Recent(count := 0) {
        list := []
        start := (count > 0 && count < this.ring.Length) ? this.ring.Length - count + 1 : 1
        loop this.ring.Length - start + 1
            list.Push(this.ring[start + A_Index - 1].Clone())
        return list
    }

    ; Calls the sink. A failing sink must not break the caller: the error is counted and kept.
    static Write(level, source, text, flowId := "") {
        if (!RegExMatch(level, "^[aft][0-3]$"))
            throw AhfError("Log.Write: unknown level '" level "'", ErrCode.INTERNAL)
        this.ring.Push(Map("ts", A_NowUTC, "level", level, "source", source, "text", text, "flowId", flowId))
        if (this.ring.Length > Log.RING_MAX)
            this.ring.RemoveAt(1)
        if (Integer(SubStr(level, 2)) > this.level)
            return
        ; Copy the sink into a local first: calling this.sink(...) passes the owner object
        ; (Log) as an extra first argument, which shifts every parameter of the sink.
        sink := this.sink
        if (!IsObject(sink))
            return
        try {
            sink(level, source, text, flowId)
        } catch as e {
            ; Logging must never stop the caller. The failure stays visible in sinkErrors.
            this.sinkErrors += 1
            this.lastSinkError := Type(e) ": " e.Message
        }
    }

    ; Sink for tests: keeps the lines in memoryLines as Maps. Declared as a function property (not a static method): a method passed as a sink
    ; would receive its first argument as `this`, so the parameters would shift.
    static Memory := (level, source, text, flowId := "") => Log.memoryLines.Push(
        Map("level", level, "source", source, "text", text, "flowId", flowId))
}
