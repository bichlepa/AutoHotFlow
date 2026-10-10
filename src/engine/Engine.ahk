#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Ids.ahk
#Include ..\core\Json.ahk
#Include ..\core\Log.ahk
#Include ..\core\Role.ahk
#Include FlowRecord.ahk
#Include FlowTable.ahk
#Include Executor.ahk

; Engine role (WI-10, ARCHITECTURE 3, 4, 6.1, PROTOCOL 4.2, 4.3, 4.6).
;
; Owns the committed flow definitions (through FlowTable) and the runtime state. It never touches
; files: flow files are read from storage with cmd.storage.flow.read and parsed here. It never shows
; a dialog and never blocks: every request has a timeout and is answered by a callback.
;
; Start: after the handshake the engine asks storage for the flow list and reads each file. Single
; file errors are reported as evt.storage.error and do not stop the start. evt.engine.ready is sent
; once the list was read. A failing list is retried (LOAD_TRIES times, LOAD_RETRY_MS apart).
;
; Every evt.* carries "epoch" (the start of this engine process) and "seq" (one counter per engine
; process, +1 per event). A client that sees a new epoch or a gap in seq asks for cmd.engine.snapshot.
class Engine extends Role {
    static STORAGE := "storage"
    static READ_TIMEOUT_MS := 30000
    static LOAD_TRIES := 5
    static LOAD_RETRY_MS := 500
    ; Safety net for the dispatcher: a tick every 100 ms in case a kick was lost (ARCHITECTURE 2.3).
    static SAFETY_MS := 100

    __New(args) {
        super.__New(args)
        this.epoch := Engine._NewEpoch()
        this.seq := 0
        this.flows := FlowTable()
        this.executor := Executor(this)
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
    Emit(to, msgType, payload) {
        this.seq += 1
        payload["epoch"] := this.epoch
        payload["seq"] := this.seq
        this.peer.Send(to, msgType, payload)
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
        st := Map("pending", files.Length)
        for f in files {
            if (!(f is Map)) {
                st["pending"] -= 1
                this._StorageError("flows.list", "", "entry is not an object")
                continue
            }
            name := f.Get("name", "")
            path := f.Get("path", "")
            this.peer.Request(Engine.STORAGE, "cmd.storage.flow.read", Map("path", path)
                , ObjBindMethod(this, "_OnFlowRead", st, name, path), Engine.READ_TIMEOUT_MS)
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
        }
        st["pending"] -= 1
        if (st["pending"] = 0)
            this._Loaded()
    }

    _Loaded() {
        if (this._flowsLoaded)
            return
        this._flowsLoaded := true
        added := []
        for rec in this.flows.All()
            added.Push(rec.FlowId)
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
