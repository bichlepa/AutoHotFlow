#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Time.ahk
#Include core\FlowDefinition.ahk

; The enabled state of the triggers, one file per flow: FlowStates/<flowId>.json (WI-0060, E0057, E0063, PROTOCOL 4.6).
; The engine owns the state and holds it in FlowRecord; the files are written only by storage, on request of the engine.
;
; Format: {"formatVersion": 1, "enabled": ["<triggerId>", ...]}. A missing file means nothing is enabled.
;
; Start (Load): every loaded flow is read once, PARALLEL reads at a time (as the flow files). A read that fails for
; another reason is retried after RETRY_DELAYS; when every try failed, the state of that flow is unknown (ErrorOf): its
; triggers are not armed, nothing is written for it, and evt.flow.state carries stateError. A broken file is kept as
; <flowId>.json.broken and treated as missing. When storage is gone or silent, onDown is called and the start waits
; again (as the variables); the flows that have no result yet are read then.
;
; Switch (Establish, Force): a flow with an unknown state reads its file once more before a switch is applied; if that
; fails, the switch is refused. Force gives the flow the state of the session and writes it (the owner's confirmation).
; A flow whose state is not read yet (start) or is being read cannot be switched; the engine refuses at once.
;
; Writes (Touch): a changed flow is written at most once per WRITE_INTERVAL_MS, coalesced per flow. A failed write is
; reported once per flow and retried after the interval. FlushAll sends the changed flows at shutdown, without waiting
; for the answers (storage empties its queue before it ends, ARCHITECTURE 6.3). A crash loses at most the last interval.
class FlowStateFile {
    static FORMAT_VERSION := 1
    static WRITE_INTERVAL_MS := 1000
    static TIMEOUT_MS := 30000
    static PARALLEL := 2
    static RETRY_DELAYS := [250, 500, 1000]   ; pauses before the second, third and fourth try of a start read

    __New(engine, flows) {
        this._engine := engine
        this._flows := flows           ; FlowTable of the engine
        this._loaded := false          ; every loaded flow has a result (known or unknown)
        this._down := false            ; the start was stopped by storage; the engine waits and calls Load again
        this._queue := []              ; flow IDs of the start that have no read yet
        this._reads := Map()          ; flow ID -> attempt, while a read or a retry of the flow is open
        this._known := Map()           ; flow ID -> true, the state is established
        this._merged := Map()          ; flow ID -> IDs of the triggers that the last read enabled (TakeMerged)
        this._errors := Map()          ; flow ID -> text, the state is unknown (the file could not be read)
        this._waiters := Map()         ; flow ID -> [onReady, onFail] of a switch that waits for its read
        this._dirty := Map()           ; flow ID -> true, changed and not written yet
        this._reported := Map()        ; flow ID -> true, the last write failed and was reported
        this._scheduled := false
        this._closing := false
        this._lastWrite := 0           ; Time.NowMs() of the last write request
        this._onDone := ""
        this._onDown := ""
        this._writeFn := () => this._Write()
    }

    ; True once every loaded flow has a result in this start.
    Loaded => this._loaded

    ; True when the state of the flow is established (read, missing or broken, or forced).
    ; The triggers that the last read of this flow enabled (once; empty if none). The engine arms and announces them.
    TakeMerged(flowId) {
        merged := this._merged.Get(flowId, [])
        this._merged.Delete(flowId)
        return merged
    }

    IsKnown(flowId) => this._known.Has(flowId)

    ; The text of the read error when the state of the flow is unknown, else "".
    ErrorOf(flowId) => this._errors.Get(flowId, "")

    ; True while a read of the flow is open (start or switch).
    IsReading(flowId) => this._reads.Has(flowId)

    ; Reads the states of the loaded flows (once per start). onDone() runs when every flow has a result; onDown(why)
    ; when storage is gone or silent (the caller waits for storage and calls Load again).
    Load(onDone, onDown) {
        if (this._loaded) {
            onDone()
            return
        }
        this._onDone := onDone
        this._onDown := onDown
        this._down := false
        this._queue := []
        for rec in this._flows.All() {
            flowId := rec.FlowId
            if (!this._known.Has(flowId) && !this._errors.Has(flowId) && !this._reads.Has(flowId))
                this._queue.Push(flowId)
        }
        this._Pump()
    }

    ; Reads the state of one flow before a switch is applied (its state is unknown). Returns "" when the read left;
    ; then onReady() runs when the state is known (and merged into the flow), onFail(why) when it could not be read.
    ; Otherwise it returns the reason and calls nothing.
    Establish(flowId, onReady, onFail) {
        this._waiters[flowId] := [onReady, onFail]
        why := this._Read(flowId, 0)
        if (why != "")
            this._Forget(this._waiters, flowId)
        return why
    }

    ; The user confirmed that the file is overwritten: the state of the session is kept and written.
    Force(flowId) {
        this._Forget(this._errors, flowId)
        this._known[flowId] := true
        this.Touch(flowId)
    }

    ; The state of a flow has changed: it is written soon (at most once per WRITE_INTERVAL_MS). Not for an unknown flow.
    Touch(flowId) {
        if (this._closing || this._errors.Has(flowId))
            return
        this._dirty[flowId] := true
        this._Schedule()
    }

    ; sys.shutdown: sends the changed flows, without waiting for the answers. Returns true if a request left.
    FlushAll(deadlineMs) {
        this._closing := true
        SetTimer(this._writeFn, 0)
        this._scheduled := false
        if (!this._loaded)
            return false
        flowIds := this._Writable()
        sent := false
        for flowId in flowIds
            sent := this._Send(flowId, Max(500, Integer(deadlineMs)), true) || sent
        return sent
    }

    ; Parses the text of one state file into the Array of enabled trigger IDs. Throws AhfError for a file that is not in
    ; this format. A missing "enabled" key means nothing enabled.
    static Parse(text) {
        try {
            root := Json.Parse(text)
        } catch as e {
            throw AhfError("not valid JSON: " e.Message, ErrCode.BAD_JSON)
        }
        if (!(root is Map))
            throw AhfError("the root is not an object", ErrCode.BAD_PAYLOAD)
        if (!root.Has("formatVersion") || root["formatVersion"] != FlowStateFile.FORMAT_VERSION)
            throw AhfError("unknown format version", ErrCode.BAD_PAYLOAD)
        if (!root.Has("enabled"))
            return []
        list := root["enabled"]
        if (!(list is Array))
            throw AhfError("'enabled' is not a list", ErrCode.BAD_PAYLOAD)
        out := []
        for id in list {
            if (IsObject(id))
                throw AhfError("'enabled' has an object in its list", ErrCode.BAD_PAYLOAD)
            out.Push(String(id))
        }
        return out
    }

    ; The text that the state file of one flow gets: its enabled triggers.
    Build(flowId) {
        rec := this._flows.Get(flowId)
        enabled := IsObject(rec) ? rec.EnabledTriggers() : []
        return Json.Stringify(Map("formatVersion", FlowStateFile.FORMAT_VERSION, "enabled", enabled), 2)
    }

    ; --- start -------------------------------------------------------------------------------------

    ; Sends the next reads while fewer than PARALLEL are open. When every flow has a result, the start is complete.
    _Pump() {
        if (this._loaded)
            return
        while (this._queue.Length && this._reads.Count < FlowStateFile.PARALLEL) {
            flowId := this._queue.RemoveAt(1)
            why := this._Read(flowId, 0)
            if (why != "") {
                this._Stop(flowId, why)
                return
            }
        }
        if (this._queue.Length = 0 && this._reads.Count = 0)
            this._Finish()
    }

    _Finish() {
        if (this._loaded)
            return
        this._loaded := true
        onDone := this._onDone
        this._onDone := ""
        this._onDown := ""
        this._Schedule()
        onDone()
    }

    ; Storage is gone: the flow goes back to the queue and the engine waits (once per stop).
    _Stop(flowId, why) {
        this._queue.InsertAt(1, flowId)
        if (this._down)
            return
        this._down := true
        this._onDown(why)
    }

    ; Sends a read of the state of one flow. Returns "" when the request left, else the reason.
    _Read(flowId, attempt) {
        this._reads[flowId] := attempt
        try {
            this._engine.peer.Request("storage", "cmd.storage.flowstate.read", Map("flowId", flowId)
                , (res) => this._OnRead(flowId, attempt, res), FlowStateFile.TIMEOUT_MS)
            return ""
        } catch as e {
            this._Forget(this._reads, flowId)
            return Type(e) ": " e.Message
        }
    }

    _Retry(flowId, attempt) {
        if (this._closing)
            return
        why := this._Read(flowId, attempt)
        if (why != "")
            this._Stop(flowId, why)
    }

    _OnRead(flowId, attempt, res) {
        waiting := this._waiters.Has(flowId)
        if (!res.payload.Get("ok", false)) {
            why := Engine._ErrorText(res)
            if (Engine._StorageGone(res)) {
                this._Forget(this._reads, flowId)
                if (waiting)
                    this._Settle(flowId, false, why)
                else
                    this._Stop(flowId, why)
                return
            }
            if (!waiting && attempt < FlowStateFile.RETRY_DELAYS.Length) {
                SetTimer(() => this._Retry(flowId, attempt + 1), -FlowStateFile.RETRY_DELAYS[attempt + 1])
                return
            }
            this._Forget(this._reads, flowId)
            this._errors[flowId] := why
            this._engine._StorageError("flowstate.read", FlowStateFile._PathText(flowId), why)
            this._Settle(flowId, false, why)
            return
        }
        this._Forget(this._reads, flowId)
        enabled := []
        if (Engine._Flag(res.payload.Get("exists", false))) {
            try {
                enabled := FlowStateFile.Parse(res.payload.Get("text", ""))
            } catch as e {
                this._engine._Log("a0", "engine", FlowStateFile._PathText(flowId) " is broken (" e.Message "); it is kept as "
                    . flowId ".json.broken, the state starts empty")
                this._Keep(flowId)
                enabled := []
            }
        }
        rec := this._flows.Get(flowId)
        if (IsObject(rec))
            this._merged[flowId] := rec.LoadEnabledTriggers(enabled)
        this._Forget(this._errors, flowId)
        this._known[flowId] := true
        this._Settle(flowId, true, "")
    }

    ; A read has its result. A switch that waits for it is answered; otherwise the start goes on.
    _Settle(flowId, ok, why) {
        if (this._waiters.Has(flowId)) {
            waiter := this._waiters[flowId]
            this._Forget(this._waiters, flowId)
            if (ok)
                waiter[1]()
            else
                waiter[2](why)
            return
        }
        this._Pump()
    }

    _Keep(flowId) {
        try {
            this._engine.peer.Request("storage", "cmd.storage.flowstate.keepBroken", Map("flowId", flowId)
                , (res) => this._OnKept(flowId, res), FlowStateFile.TIMEOUT_MS)
        } catch as e {
            this._engine._Log("a0", "engine", "keeping " FlowStateFile._PathText(flowId) " as broken failed: " e.Message)
        }
    }

    _OnKept(flowId, res) {
        if (!res.payload.Get("ok", false))
            this._engine._Log("a0", "engine", "keeping " FlowStateFile._PathText(flowId) " as broken failed: "
                . Engine._ErrorText(res))
    }

    ; --- writes ------------------------------------------------------------------------------------

    _Schedule() {
        if (this._scheduled || this._dirty.Count = 0 || !this._loaded || this._closing)
            return
        wait := Max(1, this._lastWrite + FlowStateFile.WRITE_INTERVAL_MS - Time.NowMs())
        this._scheduled := true
        SetTimer(this._writeFn, -wait)
    }

    _Write() {
        this._scheduled := false
        if (this._closing || !this._loaded)
            return
        for flowId in this._Writable()
            this._Send(flowId, FlowStateFile.TIMEOUT_MS, false)
    }

    ; The changed flows that may be written now, and removed from the changed set. A flow that is being deleted keeps its
    ; mark until the deletion is answered (WI-0070); a flow that is gone is dropped.
    _Writable() {
        flowIds := []
        held := Map()
        for flowId, _ in this._dirty {
            if (this._engine.IsDeleting(flowId)) {
                held[flowId] := true
                continue
            }
            if (this._flows.Has(flowId))
                flowIds.Push(flowId)
        }
        this._dirty := held
        return flowIds
    }

    ; The state of a deleted flow is dropped: nothing of it is kept or written (WI-0070, E0066).
    Forget(flowId) {
        for map in [this._known, this._errors, this._merged, this._waiters, this._dirty, this._reported]
            this._Forget(map, flowId)
    }

    ; Sends the state of one flow as it is now. Returns true if a request left.
    _Send(flowId, timeoutMs, closing) {
        try {
            text := this.Build(flowId)
            this._lastWrite := Time.NowMs()
            this._engine.peer.Request("storage", "cmd.storage.flowstate.write", Map("flowId", flowId, "text", text)
                , (res) => this._OnWritten(flowId, res, closing), timeoutMs)
            return true
        } catch as e {
            why := Type(e) ": " e.Message
            if (closing)
                this._engine._Log("a0", "engine", "shutdown: " FlowStateFile._PathText(flowId) " not sent: " why)
            else
                this._Failed(flowId, why, true)
            return false
        }
    }

    _OnWritten(flowId, res, closing) {
        if (res.payload.Get("ok", false)) {
            if (this._reported.Has(flowId)) {
                this._Forget(this._reported, flowId)
                this._engine._Log("a1", "engine", FlowStateFile._PathText(flowId) " written after an earlier failure")
            }
            return
        }
        this._Failed(flowId, Engine._ErrorText(res), !closing)
    }

    ; Reports the first failure of a flow; marks it again for a retry after the interval, unless the engine is closing.
    _Failed(flowId, why, retry) {
        if (!this._reported.Has(flowId)) {
            this._reported[flowId] := true
            this._engine._StorageError("flowstate.write", FlowStateFile._PathText(flowId), why)
        }
        if (retry && !this._closing) {
            this._dirty[flowId] := true
            this._Schedule()
        }
    }

    static _PathText(flowId) => "FlowStates/" flowId ".json"

    ; Map.Delete throws for a missing key in AHK v2, and most of these entries may be absent.
    _Forget(map, flowId) {
        if (map.Has(flowId))
            map.Delete(flowId)
    }
}
