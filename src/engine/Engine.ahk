#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Ids.ahk
#Include ..\core\Json.ahk
#Include ..\core\Log.ahk
#Include ..\core\Role.ahk
#Include FlowRecord.ahk
#Include FlowTable.ahk

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

    __New(args) {
        super.__New(args)
        this.epoch := Engine._NewEpoch()
        this.seq := 0
        this.flows := FlowTable()
        this._flowsLoaded := false     ; not _loaded: that name is the method _Loaded (case-insensitive)
        this._loadTries := 0
        this._loadRetryFn := () => this._LoadFlows()
    }

    ; --- role hooks ----------------------------------------------------------------------------

    RegisterHandlers() {
        this.On("cmd.engine.snapshot", (msg) => this._CmdSnapshot(msg))
        this.On("cmd.flow.get", (msg) => this._CmdFlowGet(msg))
    }

    OnReady() {
        this.SetLogTarget(Engine.STORAGE)
        if (!this._flowsLoaded)
            this._LoadFlows()
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
                , "enabled", rec.Enabled, "executing", false, "rev", rec.Rev))
        }
        return Map("epoch", this.epoch, "seq", this.seq, "flows", list, "settings", Map())
    }

    _CmdFlowGet(msg) {
        rec := this.flows.Require(Engine.Text(msg, "flowId"))
        return Map("rev", rec.Rev, "definition", rec.Def.Raw)
    }

    ; --- helpers -------------------------------------------------------------------------------

    ; A required text field of a command. Missing, empty or non-scalar values are bad_payload.
    static Text(msg, key) {
        v := msg.payload.Get(key, "")
        if (IsObject(v) || v = "")
            throw AhfError("payload field '" key "' is missing", ErrCode.BAD_PAYLOAD)
        return String(v)
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
