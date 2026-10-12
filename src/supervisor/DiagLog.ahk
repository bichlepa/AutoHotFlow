#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Log.ahk
#Include ..\core\Role.ahk

; Log sink of the supervisor and collector of the unhandled errors of the roles (WI-23, doc/ARCHITECTURE.md 6.2).
; The supervisor is not a Role and has no peer, so it cannot use Role's log queue. Every entry goes
;   1. to the console (stderr), as before, and
;   2. as evt.log.append straight through the hub to "storage" (sender "supervisor"), while storage is
;      connected; otherwise into a queue (at most Role.LOG_QUEUE_MAX entries, the oldest are dropped
;      and counted) that Flush() empties when storage says sys.hello.
; A failure while sending must not log again (the flag `busy`): the entry stays on the console only.
;
;   diag := DiagLog(hub)
;   Log.Configure(diag.SinkFn)       ; function property: a method would receive its object as first argument
;   diag.Flush()                     ; storage is connected
;   diag.AddError("engine", payload) ; evt.diag.error of a role: logged and kept in a ring of ERROR_RING_MAX
;   diag.Errors()                    ; copies of the ring (for the crash report, WI-28)
class DiagLog {
    static ERROR_RING_MAX := 50
    static STORAGE := "storage"

    __New(hub) {
        this.hub := hub
        this.queue := []
        this.dropped := 0
        this.busy := false
        this._errors := []
        this.SinkFn := (level, source, text, flowId := "") => this.Sink(level, source, text, flowId)
    }

    Sink(level, source, text, flowId := "") {
        Role.Console(level, source, text)
        if (this.busy)
            return
        this.busy := true
        try {
            entry := Map("ts", FormatTime(A_NowUTC, "yyyy-MM-dd HH:mm:ss"), "level", level, "source", source, "text", text)
            if (flowId != "")
                entry["flowId"] := flowId
            if (!this.queue.Length && this._Send(entry))
                return
            this._Queue(entry)
        } finally {
            this.busy := false
        }
    }

    ; Delivers the queued entries to storage, in order. Stops at the first entry that is refused.
    Flush() {
        if (this.busy)
            return
        this.busy := true
        try {
            while (this.queue.Length) {
                if (!this._Send(this.queue[1]))
                    break
                this.queue.RemoveAt(1)
            }
        } finally {
            this.busy := false
        }
    }

    ; Counters for the tests and the report: entries waiting and entries dropped from the queue.
    Stats() => Map("queued", this.queue.Length, "dropped", this.dropped)

    ; evt.diag.error of a role: kept in the ring and logged. payload is the Map of PROTOCOL 4.1c. doLog false: the caller has logged it already.
    AddError(from, payload, doLog := true) {
        if (Type(payload) != "Map")
            payload := Map("message", String(payload))
        rec := Map("from", from, "ts", FormatTime(A_NowUTC, "yyyy-MM-dd HH:mm:ss"))
        for key in ["name", "errorType", "message", "file", "line", "stack", "mode"]
            rec[key] := payload.Has(key) ? payload[key] : ""
        this._errors.Push(rec)
        while (this._errors.Length > DiagLog.ERROR_RING_MAX)
            this._errors.RemoveAt(1)
        if (!doLog)
            return
        Log.Write("a0", "diag", "unhandled " rec["errorType"] " in " from ": " rec["message"]
            . " (" rec["file"] ", line " rec["line"] ", " rec["mode"] ")")
    }

    Errors() {
        list := []
        for rec in this._errors
            list.Push(rec.Clone())
        return list
    }

    _Send(entry) {
        if (!this.hub.HasLink(DiagLog.STORAGE))
            return false
        return this.hub.Send(DiagLog.STORAGE, "evt.log.append", entry)
    }

    _Queue(entry) {
        this.queue.Push(entry)
        while (this.queue.Length > Role.LOG_QUEUE_MAX) {
            this.queue.RemoveAt(1)
            this.dropped += 1
        }
    }
}
