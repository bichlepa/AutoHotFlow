#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Time.ahk
#Include core\FlowDefinition.ahk

; The enabled state of the triggers in FlowState.json (WI-0060, E0057, PROTOCOL 4.6). The engine owns the state and
; holds it in FlowRecord; the file is written only by storage, on request of the engine (cmd.storage.flowstate.*).
;
; Format: {"formatVersion": 1, "flows": {"<flowId>": ["<triggerId>", ...]}}. A flow without an entry has no enabled
; trigger. Entries of flows that are not loaded are kept, so that a flow file that comes back gets its state again.
;
; Start (Load): one cmd.storage.flowstate.read after the flow files and the variables, before evt.engine.ready. When
; storage is gone or silent, onDown is called and the engine waits for storage again, as for the variables. A file
; that cannot be parsed is logged (a0), renamed by storage (cmd.storage.flowstate.keepBroken) and treated as missing.
; A read that fails for another reason is reported (evt.storage.error), and this session writes nothing, so that a
; state that could not be read is not overwritten.
;
; Writes (Touch): a change marks the state; the write leaves at most once per WRITE_INTERVAL_MS (coalesced). A failed
; write is reported once and retried after the interval. Nothing is written before the file was read. At shutdown
; FlushAll sends the state that is still marked, without waiting for the answer (storage empties its queue before it
; ends, as for the variables, ARCHITECTURE 6.3). A crash loses at most the last interval.
class FlowStateFile {
    static FORMAT_VERSION := 1
    static WRITE_INTERVAL_MS := 1000
    static TIMEOUT_MS := 30000

    __New(engine, flows) {
        this._engine := engine
        this._flows := flows           ; FlowTable of the engine
        this._loaded := false
        this._dirty := false
        this._writable := true         ; false after a read that failed for another reason
        this._scheduled := false
        this._closing := false
        this._reported := false        ; the last write failed and was reported
        this._lastWrite := 0           ; Time.NowMs() of the last write request
        this._kept := FlowDefinition.NewIndex()   ; flow ID -> Array of trigger IDs of flows that are not loaded
        this._writeFn := () => this._Write()
    }

    ; True once the file was read (or found broken or missing) in this start.
    Loaded => this._loaded

    ; Reads the state (once per start). onDone() runs when the state is in memory; onDown(why) when storage is gone or
    ; silent (the caller waits for storage and calls Load again).
    Load(onDone, onDown) {
        if (this._loaded) {
            onDone()
            return
        }
        try {
            this._engine.peer.Request("storage", "cmd.storage.flowstate.read", Map()
                , (res) => this._OnRead(res, onDone, onDown), FlowStateFile.TIMEOUT_MS)
        } catch as e {
            onDown(Type(e) ": " e.Message)
        }
    }

    ; The state has changed: it is written soon (at most once per WRITE_INTERVAL_MS).
    Touch() {
        if (this._closing || !this._writable)
            return
        this._dirty := true
        this._Schedule()
    }

    ; sys.shutdown: sends the state if it is still marked. Returns true if a request left. Does not wait for the answer.
    FlushAll(deadlineMs) {
        this._closing := true
        SetTimer(this._writeFn, 0)
        this._scheduled := false
        if (!this._loaded || !this._dirty || !this._writable)
            return false
        this._dirty := false
        return this._Send(Max(500, Integer(deadlineMs)), true)
    }

    ; Parses the text of FlowState.json into Map(flowId -> Array of trigger IDs). Throws AhfError for a file that is not
    ; in this format. A missing "flows" key is an empty state.
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
        out := FlowDefinition.NewIndex()
        if (!root.Has("flows"))
            return out
        flows := root["flows"]
        if (!(flows is Map))
            throw AhfError("'flows' is not an object", ErrCode.BAD_PAYLOAD)
        for flowId, ids in flows {
            if (!(ids is Array))
                throw AhfError("the entry of flow '" flowId "' is not a list", ErrCode.BAD_PAYLOAD)
            list := []
            for id in ids {
                if (IsObject(id))
                    throw AhfError("the entry of flow '" flowId "' has an object in its list", ErrCode.BAD_PAYLOAD)
                list.Push(String(id))
            }
            out[flowId] := list
        }
        return out
    }

    ; The text that the file gets: every loaded flow with enabled triggers, and the kept entries of flows not loaded.
    Build() {
        flows := FlowDefinition.NewIndex()
        for rec in this._flows.All() {
            ids := rec.EnabledTriggers()
            if (ids.Length)
                flows[rec.FlowId] := ids
        }
        for flowId, ids in this._kept {
            if (ids.Length && !this._flows.Has(flowId))
                flows[flowId] := ids
        }
        root := Map("formatVersion", FlowStateFile.FORMAT_VERSION, "flows", flows)
        return Json.Stringify(root, 2)
    }

    ; --- internals ---------------------------------------------------------------------------------

    _OnRead(res, onDone, onDown) {
        if (!res.payload.Get("ok", false)) {
            if (Engine._StorageGone(res)) {
                onDown(Engine._ErrorText(res))
                return
            }
            this._writable := false
            this._engine._StorageError("flowstate.read", "FlowState.json", Engine._ErrorText(res))
            this._Applied(FlowDefinition.NewIndex(), onDone)
            return
        }
        entries := FlowDefinition.NewIndex()
        if (Engine._Flag(res.payload.Get("exists", false))) {
            try {
                entries := FlowStateFile.Parse(res.payload.Get("text", ""))
            } catch as e {
                this._engine._Log("a0", "engine", "FlowState.json is broken (" e.Message "); it is kept as "
                    . "FlowState.json.broken, the state starts empty")
                try {
                    this._engine.peer.Request("storage", "cmd.storage.flowstate.keepBroken", Map()
                        , (r) => this._OnKept(r), FlowStateFile.TIMEOUT_MS)
                } catch as e2 {
                    this._engine._Log("a0", "engine", "keeping FlowState.json as broken failed: " e2.Message)
                }
                entries := FlowDefinition.NewIndex()
            }
        }
        this._Applied(entries, onDone)
    }

    _OnKept(res) {
        if (!res.payload.Get("ok", false))
            this._engine._Log("a0", "engine", "keeping FlowState.json as broken failed: " Engine._ErrorText(res))
    }

    ; Puts the read entries into the loaded flows (merged with what is set already) and keeps the rest.
    _Applied(entries, onDone) {
        for flowId, ids in entries {
            rec := this._flows.Get(flowId)
            if (IsObject(rec))
                rec.LoadEnabledTriggers(ids)
            else
                this._kept[flowId] := ids
        }
        this._loaded := true
        if (this._dirty)
            this._Schedule()
        onDone()
    }

    _Schedule() {
        if (this._scheduled || !this._dirty || !this._loaded || !this._writable || this._closing)
            return
        wait := Max(1, this._lastWrite + FlowStateFile.WRITE_INTERVAL_MS - Time.NowMs())
        this._scheduled := true
        SetTimer(this._writeFn, -wait)
    }

    _Write() {
        this._scheduled := false
        if (this._closing || !this._loaded || !this._dirty || !this._writable)
            return
        this._dirty := false
        this._Send(FlowStateFile.TIMEOUT_MS, false)
    }

    ; Sends the state as it is now. Returns true if a request left.
    _Send(timeoutMs, closing) {
        try {
            text := this.Build()
            this._lastWrite := Time.NowMs()
            this._engine.peer.Request("storage", "cmd.storage.flowstate.write", Map("text", text)
                , (res) => this._OnWritten(res, closing), timeoutMs)
            return true
        } catch as e {
            if (!closing)
                this._Failed(Type(e) ": " e.Message, true)
            else
                this._engine._Log("a0", "engine", "shutdown: FlowState.json not sent: " Type(e) ": " e.Message)
            return false
        }
    }

    _OnWritten(res, closing) {
        if (res.payload.Get("ok", false)) {
            if (this._reported) {
                this._reported := false
                this._engine._Log("a1", "engine", "FlowState.json written after an earlier failure")
            }
            return
        }
        this._Failed(Engine._ErrorText(res), !closing)
    }

    ; Reports the first failure; marks the state again for a retry after the interval, unless the engine is closing.
    _Failed(text, retry) {
        if (!this._reported) {
            this._reported := true
            this._engine._StorageError("flowstate.write", "FlowState.json", text)
        }
        if (retry && !this._closing) {
            this._dirty := true
            this._Schedule()
        }
    }
}
