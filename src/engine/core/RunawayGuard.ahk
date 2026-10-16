#Requires AutoHotkey v2.0

; Guard against runaway flows (WI-0066, REQ-EXE-170, decision E0062). Pure state, no messages: the Executor counts
; every element execution here and asks whether a limit is exceeded; the Engine acts on the answer.
;
; Three limits per flow, read from flowSettings of the flow file (PROTOCOL 4.2, "Runaway guard"):
;   maxExecutionsPerMinute  element executions in a sliding window of 60 s (the start of a trigger counts too)
;   maxWaitingInstances     instances queued by policy wait
;   maxParallelInstances    running instances
; A missing key or "default" means the built-in default, 0 means no limit. The defaults were set from the throughput
; of the engine (MS-0036): a loop over 10,000 members with up to four body elements passes, a runaway loop is caught
; after about 8 to 11 s. They are constants until the global setting comes with S0004.
;
; Window: 60 buckets of one second per flow. Counting costs an increment; the buckets that are older than the window
; are cleared once per second of change, not per element. The total is kept, so a count is O(1).
class RunawayGuard {
    static DEFAULT_PER_MINUTE := 50000
    static DEFAULT_WAITING := 100
    static DEFAULT_PARALLEL := 100
    static WINDOW_S := 60
    ; A refused start is logged at most once per this time and flow (PROTOCOL 4.2).
    static REFUSED_LOG_MS := 10000

    __New() {
        this._flows := Map()    ; flowId -> Map of the window state (see _Window)
    }

    ; The limit of a flow for one key (flowSettings), as an integer; 0 means no limit. def: FlowDefinition (its Raw).
    ; A value that is neither "default" nor a whole number counts as the default.
    static LimitOf(def, key, defaultValue) {
        settings := def.Raw.Get("flowSettings", "")
        if (!(settings is Map) || !settings.Has(key))
            return defaultValue
        value := settings[key]
        if (value = "default")
            return defaultValue
        if (IsInteger(value) && Integer(value) >= 0)
            return Integer(value)
        return defaultValue
    }

    ; Counts one element execution of the flow. Returns the number of executions in the window, this one included.
    ; nowMs: the time in milliseconds (A_TickCount when left out; tests give their own).
    Count(flowId, nowMs := "") {
        w := this._Window(flowId)
        if (nowMs = "")
            nowMs := A_TickCount
        sec := nowMs // 1000
        if (sec != w["lastSec"]) {
            this._Purge(w, sec)
            w["lastSec"] := sec
        }
        idx := Mod(sec, RunawayGuard.WINDOW_S) + 1
        counts := w["counts"]
        secs := w["secs"]
        if (secs[idx] != sec) {
            w["total"] -= counts[idx]
            counts[idx] := 0
            secs[idx] := sec
        }
        counts[idx] += 1
        w["total"] += 1
        return w["total"]
    }

    ; A start was refused (limit reached). text names the limit. Returns the log line when one is due, "" otherwise: at most
    ; one line per REFUSED_LOG_MS and flow, which tells how many starts were refused since the last line.
    Refused(flowId, text, nowMs := "") {
        w := this._Window(flowId)
        if (nowMs = "")
            nowMs := A_TickCount
        w["refused"] += 1
        if (w["logged"] && nowMs - w["lastLog"] < RunawayGuard.REFUSED_LOG_MS)
            return ""
        n := w["refused"]
        w["refused"] := 0
        w["logged"] := true
        w["lastLog"] := nowMs
        return n " start" (n = 1 ? "" : "s") " refused since the last line: " text
    }

    ; Forgets a flow (deleted from the table): its window and its refusals.
    Forget(flowId) {
        this._flows.Delete(flowId)
    }

    _Window(flowId) {
        if (this._flows.Has(flowId))
            return this._flows[flowId]
        n := RunawayGuard.WINDOW_S
        counts := []
        secs := []
        loop n {
            counts.Push(0)
            secs.Push(-1)
        }
        w := Map("counts", counts, "secs", secs, "total", 0, "lastSec", -1, "refused", 0, "logged", false
            , "lastLog", 0)
        this._flows[flowId] := w
        return w
    }

    ; Clears the buckets that are older than the window at second sec.
    _Purge(w, sec) {
        counts := w["counts"]
        secs := w["secs"]
        for idx, when in secs {
            if (when >= 0 && sec - when >= RunawayGuard.WINDOW_S) {
                w["total"] -= counts[idx]
                counts[idx] := 0
                secs[idx] := -1
            }
        }
    }
}
