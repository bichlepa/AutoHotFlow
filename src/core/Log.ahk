#Requires AutoHotkey v2.0
#Include Errors.ahk

; Log client. Core writes nothing by itself: the role configures a sink (storage process, console, test).
; Levels as in v1: a0..a3 (general), f0..f3 (flow), t0..t3 (trigger). Smaller digit = less detail.
class Log {
    static sink := ""
    static sinkErrors := 0
    static lastSinkError := ""
    static memoryLines := []

    ; sink: function(level, source, text, flowId). Pass "" to disable logging.
    static Configure(sink) {
        this.sink := sink
    }

    ; Calls the sink. A failing sink must not break the caller: the error is counted and kept.
    static Write(level, source, text, flowId := "") {
        if (!RegExMatch(level, "^[aft][0-3]$"))
            throw AhfError("Log.Write: unknown level '" level "'", ErrCode.INTERNAL)
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
