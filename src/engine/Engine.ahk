#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Ids.ahk
#Include ..\core\Json.ahk
#Include ..\core\Log.ahk
#Include ..\core\Role.ahk
#Include FlowRecord.ahk
#Include FlowTable.ahk
#Include Executor.ahk
#Include WorkerBridge.ahk

; Engine role (WI-10, ARCHITECTURE 3, 4, 6.1, PROTOCOL 4.2, 4.3, 4.6).
;
; Owns the committed flow definitions (through FlowTable) and the runtime state. It never touches
; files: flow files are read from storage with cmd.storage.flow.read and parsed here. It never shows
; a dialog and never blocks: every request has a timeout and is answered by a callback.
;
; Start: after the handshake the engine asks storage for the flow list and reads the files, LOAD_PARALLEL at a
; time (the next request leaves when an answer has been handled, so the message loop answers pings in between).
; Single file errors are reported as evt.storage.error and do not stop the start. When storage does not answer
; (timeout, connection lost) the files not yet asked for are reported as failed without being asked.
; evt.engine.ready is sent once the list was read. A failing list is retried (LOAD_TRIES times, LOAD_RETRY_MS apart).
;
; Every evt.* carries "epoch" (the start of this engine process) and "seq" (one counter per engine
; process, +1 per event). A client that sees a new epoch or a gap in seq asks for cmd.engine.snapshot.
class Engine extends Role {
    static STORAGE := "storage"
    ; Operation names of cmd.flow.patch (PROTOCOL 4.2). Known, but not applied in Phase 2.
    static PATCH_OPS := Map("element.add", true, "element.update", true, "element.remove", true
        , "connection.add", true, "connection.remove", true, "flow.settings", true)
    static READ_TIMEOUT_MS := 30000
    static LOAD_TRIES := 5
    static LOAD_RETRY_MS := 500
    ; At most this many cmd.storage.flow.read are on their way at the same time. Every answer costs the engine a
    ; parse of the whole flow text (about 100 ms for 93 KB), so a ping behind many answers waited too long (WI-24).
    ; With K requests in flight, a ping waits for at most K answers.
    static LOAD_PARALLEL := 2
    ; Safety net for the dispatcher: a tick every 100 ms in case a kick was lost (ARCHITECTURE 2.3).
    static SAFETY_MS := 100

    __New(args) {
        super.__New(args)
        this.epoch := Engine._NewEpoch()
        this.seq := 0
        this.flows := FlowTable()
        this.executor := Executor(this)
        this.workers := WorkerBridge(this, Engine._PoolSize(args))
        this._flowsLoaded := false     ; not _loaded: that name is the method _Loaded (case-insensitive)
        this._loadTries := 0
        this._loadRetryFn := () => this._LoadFlows()
        this._tickFn := () => this._Tick()
        this._safetyFn := () => this._Tick()
    }

    ; --- role hooks ----------------------------------------------------------------------------

    RegisterHandlers() {
        this.On("cmd.engine.snapshot", (msg) => this._CmdSnapshot(msg))
        this.On("cmd.flow.get", (msg) => this._CmdFlowGet(msg))
        this.On("cmd.flow.start", (msg) => this._CmdFlowStart(msg))
        this.On("cmd.flow.stop", (msg) => this._CmdFlowStop(msg))
        this.On("cmd.flow.toggle", (msg) => this._CmdFlowToggle(msg))
        this.On("cmd.flow.enable", (msg) => this._CmdFlowEnable(msg, true))
        this.On("cmd.flow.disable", (msg) => this._CmdFlowEnable(msg, false))
        this.On("cmd.flow.patch", (msg) => this._CmdFlowPatch(msg))
        this.On("evt.worker.done", (msg) => this.workers.OnDone(msg))
        if (this.workers.Size > 0) {
            ; Worker crashes come from the supervisor (topic "process"), which owns the process handles.
            this.On("evt.process.", (msg) => this.workers.OnProcessEvent(msg))
            this.peer.Subscribe("process")
        }
        SetTimer(this._safetyFn, Engine.SAFETY_MS)
    }

    OnReady() {
        this.SetLogTarget(Engine.STORAGE)
        if (!this._flowsLoaded)
            this._LoadFlows()
    }

    ; sys.shutdown: every instance is stopped before sys.bye (ARCHITECTURE 6.3, step 2).
    OnShutdown(deadlineMs) {
        this.executor.StopAll("shutdown")
    }

    ; --- events --------------------------------------------------------------------------------

    ; Sends an event to a topic address ("topic:engine", "topic:flow:<id>") with epoch and seq.
    ; The peer drops it when it is not ready (Peer.droppedSends); events are not kept (PROTOCOL 5a).
    ; Numbering and sending are one step: AHK interrupts a thread that runs longer than 15 ms, and
    ; an event emitted by the interrupting thread would otherwise leave first with a higher seq
    ; (found by the 200 parallel instances of the stress test, WI-16).
    Emit(to, msgType, payload) {
        prev := Critical("On")  ; reason: numbering and sending are one step (see above)
        try {
            this.seq += 1
            payload["epoch"] := this.epoch
            payload["seq"] := this.seq
            this.peer.Send(to, msgType, payload)
        } finally {
            Critical(prev)
        }
    }

    ; evt.flow.state for one flow: enabled flag and whether an instance runs.
    EmitFlowState(flowId) {
        rec := this.flows.Get(flowId)
        enabled := IsObject(rec) ? rec.Enabled : false
        this.Emit("topic:flow:" flowId, "evt.flow.state", Map("flowId", flowId, "enabled", enabled
            , "executing", this.executor.IsExecuting(flowId)))
    }

    ; Asks for a dispatch tick soon (once, after the current message).
    Kick() {
        SetTimer(this._tickFn, -1)
    }

    _Tick() {
        try {
            this.executor.Tick()
        } catch as e {
            this._Log("a0", "engine", "dispatch failed: " Type(e) ": " e.Message)
        }
    }

    ; --- loading (cmd.storage.*) ---------------------------------------------------------------

    _LoadFlows() {
        if (this._flowsLoaded)
            return
        this._loadTries += 1
        try {
            this.peer.Request(Engine.STORAGE, "cmd.storage.flows.list", Map(), (res) => this._OnFlowList(res)
                , Engine.READ_TIMEOUT_MS)
        } catch as e {
            this._StorageError("flows.list", "", Type(e) ": " e.Message)
            this._RetryLoad()
        }
    }

    _OnFlowList(res) {
        if (!res.payload.Get("ok", false)) {
            this._StorageError("flows.list", "", Engine._ErrorText(res))
            this._RetryLoad()
            return
        }
        files := res.payload.Get("files", [])
        if (files.Length = 0) {
            this._Loaded()
            return
        }
        ; pending: files without a result yet; inflight: requests sent and not answered; next: index in files.
        st := Map("files", files, "pending", files.Length, "inflight", 0, "next", 1, "storageDown", false)
        this._ReadNext(st)
    }

    ; Sends read requests until LOAD_PARALLEL are in flight; calls _Loaded when every file has a result.
    _ReadNext(st) {
        files := st["files"]
        while (st["inflight"] < Engine.LOAD_PARALLEL && st["next"] <= files.Length) {
            f := files[st["next"]]
            st["next"] += 1
            if (!(f is Map)) {
                st["pending"] -= 1
                this._StorageError("flows.list", "", "entry is not an object")
                continue
            }
            name := f.Get("name", "")
            path := f.Get("path", "")
            if (st["storageDown"]) {
                st["pending"] -= 1
                this._StorageError("flow.read", path, "not read: storage did not answer before")
                continue
            }
            try {
                this.peer.Request(Engine.STORAGE, "cmd.storage.flow.read", Map("path", path)
                    , ObjBindMethod(this, "_OnFlowRead", st, name, path), Engine.READ_TIMEOUT_MS)
                st["inflight"] += 1
            } catch as e {
                st["pending"] -= 1
                this._StorageError("flow.read", path, Type(e) ": " e.Message)
            }
        }
        if (st["pending"] = 0)
            this._Loaded()
    }

    _OnFlowRead(st, name, path, res) {
        if (res.payload.Get("ok", false)) {
            try {
                this.flows.Load(name, res.payload.Get("text", ""))
            } catch as e {
                this._StorageError("flow.parse", path, e.Message)
            }
        } else {
            this._StorageError("flow.read", path, Engine._ErrorText(res))
            ; A storage that does not answer would make every further read wait for its own deadline, one after the
            ; other (before WI-24 all waited at once). The rest is failed at once.
            code := res.payload.Get("error", Map()) is Map ? res.payload["error"].Get("code", "") : ""
            if (code = ErrCode.TIMEOUT || code = ErrCode.PEER_GONE || code = ErrCode.SHUTTING_DOWN)
                st["storageDown"] := true
        }
        st["inflight"] -= 1
        st["pending"] -= 1
        this._ReadNext(st)
    }

    _Loaded() {
        if (this._flowsLoaded)
            return
        this._flowsLoaded := true
        added := []
        for rec in this.flows.All()
            added.Push(rec.FlowId)
        ; The supervisor starts a restarted engine with --restarted=<n>. The engine owns the epoch, so it
        ; announces the new one itself (ARCHITECTURE 6.2, PROTOCOL 4.3); clients then call cmd.engine.snapshot.
        if (this.args.Has("restarted"))
            this.Emit("topic:engine", "evt.engine.restarted", Map())
        this.Emit("topic:engine", "evt.flow.list.changed", Map("added", added, "removed", [], "changed", []))
        this.Emit("topic:engine", "evt.engine.ready", Map())
        this._Log("a1", "engine", "ready with " this.flows.Count " flow(s)")
    }

    _RetryLoad() {
        if (this._loadTries >= Engine.LOAD_TRIES) {
            this._Log("a0", "engine", "flow list not loaded after " this._loadTries " tries, engine stays not ready")
            return
        }
        SetTimer(this._loadRetryFn, -Engine.LOAD_RETRY_MS)
    }

    _StorageError(op, path, message) {
        this._Log("a0", "engine", "storage " op " failed for '" path "': " message)
        if (this.peer.status = "ready")
            this.Emit("topic:engine", "evt.storage.error", Map("op", op, "path", path, "message", message))
    }

    ; --- commands ------------------------------------------------------------------------------

    _CmdSnapshot(msg) {
        list := []
        for rec in this.flows.All() {
            list.Push(Map("flowId", rec.FlowId, "name", rec.Def.Name, "category", rec.Def.Category
                , "enabled", rec.Enabled, "executing", this.executor.IsExecuting(rec.FlowId), "rev", rec.Rev))
        }
        return Map("epoch", this.epoch, "seq", this.seq, "flows", list, "settings", Map())
    }

    _CmdFlowGet(msg) {
        rec := this.flows.Require(Engine.Text(msg, "flowId"))
        return Map("rev", rec.Rev, "definition", rec.Def.Raw)
    }

    _CmdFlowStart(msg) {
        rec := this.flows.Require(Engine.Text(msg, "flowId"))
        instId := this.executor.StartFlow(rec, Engine.Optional(msg, "triggerId"))
        ; Policy wait while the flow runs: the instance is queued (PROTOCOL 4.2), "waiting" is only sent then.
        if (this.executor.IsWaiting(instId))
            return Map("instanceId", instId, "waiting", true)
        return Map("instanceId", instId)
    }

    _CmdFlowStop(msg) {
        flowId := Engine.Text(msg, "flowId")
        this.flows.Require(flowId)
        return Map("stopped", this.executor.StopFlow(flowId, "flow.stop"))
    }

    _CmdFlowToggle(msg) {
        flowId := Engine.Text(msg, "flowId")
        rec := this.flows.Require(flowId)
        if (this.executor.IsExecuting(flowId)) {
            this.executor.StopFlow(flowId, "toggle")
            return Map("action", "stopped")
        }
        instId := this.executor.StartFlow(rec)
        return Map("action", "started", "instanceId", instId)
    }

    ; Phase 2: sets the flag and reports it. No trigger is armed (WI-14, Phase 3).
    _CmdFlowEnable(msg, enabled) {
        flowId := Engine.Text(msg, "flowId")
        rec := this.flows.Require(flowId)
        rec.Enabled := enabled
        this.EmitFlowState(flowId)
        return Map()
    }

    ; Patch schema (PROTOCOL 4.2). Phase 2 checks the revision and the shape of the operations, then
    ; refuses them: applying operations is Phase 3. A stale baseRev is a conflict with the current state.
    ; Operations are checked all before any is applied (atomic), and an empty list changes nothing.
    _CmdFlowPatch(msg) {
        flowId := Engine.Text(msg, "flowId")
        rec := this.flows.Require(flowId)
        base := msg.payload.Get("baseRev", "")
        if (!IsInteger(base))
            throw AhfError("payload field 'baseRev' must be an integer", ErrCode.BAD_PAYLOAD)
        ops := msg.payload.Get("ops", "")
        if (!(ops is Array))
            throw AhfError("payload field 'ops' must be an array", ErrCode.BAD_PAYLOAD)
        if (Integer(base) != rec.Rev)
            return Map("ok", false, "error", Map("code", ErrCode.CONFLICT
                , "message", "flow '" flowId "' is at rev " rec.Rev ", baseRev was " base)
                , "rev", rec.Rev, "definition", rec.Def.Raw)
        for op in ops {
            if (!(op is Map) || !op.Has("op") || IsObject(op["op"]))
                throw AhfError("each operation needs an 'op' field", ErrCode.BAD_PAYLOAD)
            name := String(op["op"])
            if (!Engine.PATCH_OPS.Has(name))
                throw AhfError("unknown patch operation '" name "'", ErrCode.BAD_PAYLOAD)
            throw AhfError("patch operation '" name "' is not applied before phase 3", ErrCode.BAD_PAYLOAD)
        }
        return Map("rev", rec.Rev)
    }

    ; --- helpers -------------------------------------------------------------------------------

    ; A required text field of a command. Missing, empty or non-scalar values are bad_payload.
    static Text(msg, key) {
        v := msg.payload.Get(key, "")
        if (IsObject(v) || v = "")
            throw AhfError("payload field '" key "' is missing", ErrCode.BAD_PAYLOAD)
        return String(v)
    }

    ; An optional text field: "" when missing, bad_payload when it is an object.
    static Optional(msg, key) {
        v := msg.payload.Get(key, "")
        if (IsObject(v))
            throw AhfError("payload field '" key "' must be a value", ErrCode.BAD_PAYLOAD)
        return (v = "") ? "" : String(v)
    }

    ; Number of worker slots from --workers (default 0: no pool, worker elements end with "exception").
    static _PoolSize(args) {
        raw := args.Get("workers", "0")
        if (!IsInteger(raw) || Integer(raw) < 0 || Integer(raw) > WorkerBridge.MAX_SIZE)
            throw AhfError("--workers must be an integer from 0 to " WorkerBridge.MAX_SIZE, ErrCode.BAD_ARGS)
        return Integer(raw)
    }

    static _ErrorText(res) {
        err := res.payload.Get("error", "")
        if (err is Map)
            return err.Get("code", "") ": " err.Get("message", "")
        return "no error details"
    }

    ; Epoch of this process: the start time in UTC with milliseconds, as one integer. Two starts of
    ; the engine differ, so a client can see that the engine was restarted (PROTOCOL 5).
    static _NewEpoch() => Integer(A_NowUTC) * 1000 + Integer(A_MSec)
}
