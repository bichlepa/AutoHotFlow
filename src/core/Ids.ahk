#Requires AutoHotkey v2.0
#Include Errors.ahk

; Process-local ids for messages, flows and instances (doc/PROTOCOL.md section 2).
; A counter per process, starting at 1. A_TickCount and random values are not used.
class Ids {
    static processName := ""
    static counter := 0

    ; Call once at process start. Resets the counter.
    static Configure(processName) {
        if (processName = "")
            throw AhfError("Ids.Configure: processName is empty", ErrCode.INTERNAL)
        this.processName := processName
        this.counter := 0
    }

    ; Returns "<processName>#<n>", or "<prefix><n>" if a prefix is given.
    static Next(prefix := "") {
        if (this.processName = "")
            throw AhfError("Ids.Next: Ids.Configure was not called", ErrCode.INTERNAL)
        prev := Critical("On")  ; reason: incrementing and reading the counter is one step (an interrupting timer or message handler would get the same id)
        n := ++this.counter
        Critical(prev)
        head := (prefix = "") ? this.processName "#" : prefix
        return head n
    }
}
