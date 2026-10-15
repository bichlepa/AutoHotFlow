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
#Include VarRequests.ahk
#Include vars\EngineVars.ahk
#Include vars\VarLoader.ahk
#Include vars\VarWriter.ahk

; Engine role (WI-0010, ARCHITECTURE 3, 4, 6.1, PROTOCOL 4.2, 4.3, 4.6).
;
; Owns the committed flow definitions (through FlowTable) and the runtime state. It never touches
; files: flow files are read from storage with cmd.storage.flow.read and parsed here. It never shows
; a dialog and never blocks: every request has a timeout and is answered by a callback.
;
; Start (WI-0031): after the handshake the engine waits until the supervisor reports storage as ready (it subscribes
; to the topic "process" first, then asks cmd.process.list; PROTOCOL 5a), however long that takes. Then it asks
; storage for the flow list and reads the files, LOAD_PARALLEL at a time (the next request leaves when an answer
; has been handled, so the message loop answers pings in between). Single file errors are reported as
; evt.storage.error and do not stop the start. When storage does not answer (timeout, connection lost, no such
; peer) the files not yet asked for are not asked, nothing is reported as an error, and the engine waits for
; storage again; then it fetches the list again and reads only the files that have no result yet.
; Then (WI-0041) it loads the global and static variables through storage (VarLoader, staggered the same way, with
; the same waiting for storage after an abort); evt.engine.ready is sent once every file of the list has a result
; (loaded, or a real read or parse error) and the variables are loaded. Changes of the variables are written back
; delayed by VarWriter and at shutdown.
; A list that fails for another reason is retried without limit, with a growing pause.
;
; Every evt.* carries "epoch" (the start of this engine process) and "seq" (one counter per engine
; process, +1 per event). A client that sees a new epoch or a gap in seq asks for cmd.engine.snapshot.
class Engine extends Role {
    static STORAGE := "storage"
    ; Operation names of cmd.flow.patch (PROTOCOL 4.2). Known, but not applied in Phase 2.
    static PATCH_OPS := Map("element.add", true, "element.update", true, "element.remove", true
        , "connection.add", true, "connection.remove", true, "flow.settings", true)
    static READ_TIMEOUT_MS := 30000
    static LOAD_RETRY_MS := 500
    static LOAD_RETRY_MAX_MS := 5000
    ; Pause between two questions "is storage ready?" while storage is missing, and the least time between two
    ; log lines about waiting (a storage that starts late must not fill the log).
    static STORAGE_POLL_MS := 1000
    static STORAGE_LIST_TIMEOUT_MS := 5000
    static WAIT_LOG_MS := 30000
    ; At most this many cmd.storage.flow.read are on their way at the same time. Every answer costs the engine a
    ; parse of the whole flow text (about 100 ms for 93 KB), so a ping behind many answers waited too long (WI-0024).
    ; With K requests in flight, a ping waits for at most K answers.
    static LOAD_PARALLEL := 2
    ; Safety net for the dispatcher: a tick every 100 ms in case a kick was lost (ARCHITECTURE 2.3).
    static SAFETY_MS := 100
    ; cmd.flow.save waits this long for the answer of storage (one write with a backup, WI-0039).
    static SAVE_TIMEOUT_MS := 30000

    __New(args) {
        super.__New(args)
        this.epoch := Engine._NewEpoch()
        this.seq := 0
        this.flows := FlowTable()
        this.vars := EngineVars()      ; global and static variables (WI-0040)
        this.varLoader := VarLoader(this, this.vars)
        varOpts := Engine._VarOptions(args)
        this.varWriter := VarWriter(this, this.vars, varOpts["delayMs"], varOpts["timeoutMs"])
        this.vars.OnChange := (scope, flowId, name) => this.varWriter.Touch(scope, flowId, name)
        this.executor := Executor(this)
        pool := Engine._PoolOptions(args)
        this.workers := WorkerBridge(this, pool["size"], pool["warm"], pool["idleMs"])
        this.varRequests := VarRequests(this)   ; cmd.engine.var.* of worker elements and clients (WI-0050)
        this._flowsLoaded := false     ; not _loaded: that name is the method _Loaded (case-insensitive)
        this._loadTries := 0           ; failed flow lists in a row for a real reason (not: storage missing)
        this._loadActive := false      ; flows.list or flow.read requests are on their way
        this._listPending := false     ; a cmd.process.list for the state of storage is on its way
        this._doneFiles := Map()       ; path -> true: files that have a result (loaded, or a real error)
        this._lastWaitLog := ""        ; tick of the last "waiting for storage" log line
        this._loadRetryFn := () => this._LoadFlows()
        this._pollFn := () => this._WaitForStorage()
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
        this.On("cmd.flow.save", (msg) => this._CmdFlowSave(msg))
        this.On("evt.worker.done", (msg) => this.workers.OnDone(msg))
        this.On("cmd.engine.var.", (msg) => this.varRequests.Handle(msg))
        ; The topic "process" tells the engine when storage is ready (start, WI-0031) and, with a pool, which worker
        ; crashed (the supervisor owns the process handles).
        this.On("evt.process.", (msg) => this._OnProcessEvent(msg))
        this.peer.Subscribe("process")
        SetTimer(this._safetyFn, Engine.SAFETY_MS)
    }

    OnReady() {
        this.SetLogTarget(Engine.STORAGE)
        this.workers.Start()        ; ends the workers of an earlier engine, then the pool may grow (WI-0027)
        if (!this._flowsLoaded)
            this._WaitForStorage()
    }

    ; Role part of the snapshot (doc/PROTOCOL.md 4.9): loaded flows, instances with threads, the worker pool.
    DiagInfo() {
        flows := []
        for rec in this.flows.All() {
            flows.Push(Map("flowId", rec.FlowId, "name", rec.Def.Name, "rev", rec.Rev, "enabled", Json.Bool(rec.Enabled)
                , "executing", Json.Bool(this.executor.IsExecuting(rec.FlowId))))
        }
        return Map("epoch", this.epoch, "seq", this.seq, "flows", flows, "instances", this.executor.DiagInstances()
            , "workers", this.workers.DiagInfo()
            , "variables", Map("loaded", this.varLoader.Count, "writePending", this.varWriter.Pending
                , "writeInflight", this.varWriter.Inflight))
    }

    ; sys.shutdown: every instance is stopped, then the variables that are not written yet go to storage, all before
    ; sys.bye (ARCHITECTURE 6.3, step 2). The requests carry the rest of the deadline as their limit. The engine does
    ; not wait for the answers: the frames are in the send queue ahead of sys.bye, and storage is the last process to
    ; end and empties its queue.
    OnShutdown(deadlineMs) {
        ; The variables are written whatever goes wrong while the instances are stopped: they are the one thing
        ; that cannot be recovered later.
        try {
            this.workers.Stop()
        } catch as e {
            this._Log("a0", "engine", "shutdown: stopping the workers failed: " Type(e) ": " e.Message)
        }
        try {
            this.executor.StopAll("shutdown")
        } catch as e {
            this._Log("a0", "engine", "shutdown: stopping the instances failed: " Type(e) ": " e.Message)
        }
        sent := this.varWriter.FlushAll(deadlineMs)
        if (sent > 0)
            this._Log("a1", "engine", "shutdown: " sent " variable(s) sent to storage")
    }

    ; --- events --------------------------------------------------------------------------------

    ; Sends an event to a topic address ("topic:engine", "topic:flow:<id>") with epoch and seq.
    ; The peer drops it when it is not ready (Peer.droppedSends); events are not kept (PROTOCOL 5a).
    ; Numbering and sending are one step: AHK interrupts a thread that runs longer than 15 ms, and
    ; an event emitted by the interrupting thread would otherwise leave first with a higher seq
    ; (found by the 200 parallel instances of the stress test, WI-0016).
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
        this.Emit("topic:flow:" flowId, "evt.flow.state", Map("flowId", flowId, "enabled", Json.Bool(enabled)
            , "executing", Json.Bool(this.executor.IsExecuting(flowId))))
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

    _OnProcessEvent(msg) {
        if (msg.payload.Get("name", "") = Engine.STORAGE) {
            if (msg.type = "evt.process.ready")
                this._StartLoad()
            return
        }
        if (this.workers.Size > 0)
            this.workers.OnProcessEvent(msg)
    }

    ; Asks the supervisor whether storage is ready; asks again after STORAGE_POLL_MS if it is not (or if the supervisor
    ; did not answer). evt.process.ready of storage starts the load earlier. No limit of tries (F-0027).
    _WaitForStorage() {
        if (this._flowsLoaded || this._loadActive || this._listPending)
            return
        this._listPending := true
        try {
            this.peer.Request("supervisor", "cmd.process.list", Map(), (res) => this._OnStorageState(res)
                , Engine.STORAGE_LIST_TIMEOUT_MS)
        } catch as e {
            this._listPending := false
            this._LogWaiting("process list not requested: " Type(e) ": " e.Message)
            SetTimer(this._pollFn, -Engine.STORAGE_POLL_MS)
        }
    }

    _OnStorageState(res) {
        this._listPending := false
        if (this._flowsLoaded || this._loadActive)
            return
        if (res.payload.Get("ok", false)) {
            for p in res.payload.Get("processes", []) {
                if (p is Map && p.Get("name", "") = Engine.STORAGE && p.Get("state", "") = "ready") {
                    this._StartLoad()
                    return
                }
            }
            this._LogWaiting("storage is not ready")
        } else {
            this._LogWaiting("storage state not known: " Engine._ErrorText(res))
        }
        SetTimer(this._pollFn, -Engine.STORAGE_POLL_MS)
    }

    ; At most one line per WAIT_LOG_MS, level a1: waiting for a late storage is normal (F-0021).
    _LogWaiting(text) {
        if (this._lastWaitLog != "" && A_TickCount - this._lastWaitLog < Engine.WAIT_LOG_MS)
            return
        this._lastWaitLog := A_TickCount
        this._Log("a1", "engine", "waiting for storage: " text)
    }

    ; Storage is ready: read the list (again). Called by the process event and by the answer of cmd.process.list.
    _StartLoad() {
        if (this._flowsLoaded || this._loadActive)
            return
        this._loadActive := true
        SetTimer(this._pollFn, 0)
        this._LoadFlows()
    }

    _LoadFlows() {
        if (this._flowsLoaded)
            return
        try {
            this.peer.Request(Engine.STORAGE, "cmd.storage.flows.list", Map(), (res) => this._OnFlowList(res)
                , Engine.READ_TIMEOUT_MS)
        } catch as e {
            this._LoadInterrupted(Type(e) ": " e.Message)
        }
    }

    ; The load stopped because storage is gone or silent: nothing is reported as an error, the engine waits again.
    _LoadInterrupted(why) {
        this._loadActive := false
        this._LogWaiting("loading interrupted (" why "), " this._doneFiles.Count " file(s) have a result")
        ; Not at once: the supervisor may still call a dead storage "ready", and then the engine would spin.
        SetTimer(this._pollFn, -Engine.STORAGE_POLL_MS)
    }

    _OnFlowList(res) {
        if (!res.payload.Get("ok", false)) {
            if (Engine._StorageGone(res)) {
                this._LoadInterrupted(Engine._ErrorText(res))
                return
            }
            this._StorageError("flows.list", "", Engine._ErrorText(res))
            this._loadTries += 1
            SetTimer(this._loadRetryFn, -Min(Engine.LOAD_RETRY_MS * this._loadTries, Engine.LOAD_RETRY_MAX_MS))
            return
        }
        this._loadTries := 0
        files := []
        for f in res.payload.Get("files", []) {
            if (f is Map && this._doneFiles.Has(f.Get("path", "")))
                continue            ; read by an earlier round: stays loaded
            files.Push(f)
        }
        if (files.Length = 0) {
            this._Loaded()
            return
        }
        ; pending: files without a result yet; inflight: requests sent and not answered; next: index in files.
        st := Map("files", files, "pending", files.Length, "inflight", 0, "next", 1, "storageDown", "")
        this._ReadNext(st)
    }

    ; Sends read requests until LOAD_PARALLEL are in flight; calls _Loaded when every file has a result, or
    ; _LoadInterrupted when storage went away and the last answer is in.
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
            if (st["storageDown"] != "") {
                st["pending"] -= 1          ; not asked, no result: the next round reads it
                continue
            }
            try {
                this.peer.Request(Engine.STORAGE, "cmd.storage.flow.read", Map("path", path)
                    , ObjBindMethod(this, "_OnFlowRead", st, name, path), Engine.READ_TIMEOUT_MS)
                st["inflight"] += 1
            } catch as e {
                st["pending"] -= 1
                st["storageDown"] := Type(e) ": " e.Message
            }
        }
        if (st["pending"] = 0) {
            if (st["storageDown"] != "")
                this._LoadInterrupted(st["storageDown"])
            else
                this._Loaded()
        }
    }

    _OnFlowRead(st, name, path, res) {
        if (res.payload.Get("ok", false)) {
            this._doneFiles[path] := true
            try {
                this.flows.Load(name, res.payload.Get("text", ""))
            } catch as e {
                this._StorageError("flow.parse", path, e.Message)
            }
        } else if (Engine._StorageGone(res)) {
            ; A storage that does not answer would make every further read wait for its own deadline, one after the
            ; other (before WI-0024 all waited at once). No further file is asked for; this one has no result yet.
            if (st["storageDown"] = "")
                st["storageDown"] := Engine._ErrorText(res)
        } else {
            this._doneFiles[path] := true
            this._StorageError("flow.read", path, Engine._ErrorText(res))
        }
        st["inflight"] -= 1
        st["pending"] -= 1
        this._ReadNext(st)
    }

    ; Every flow file has a result: the variables are next (their static tables are per loaded flow).
    _Loaded() {
        if (this._flowsLoaded)
            return
        flowIds := []
        for rec in this.flows.All()
            flowIds.Push(rec.FlowId)
        this.varLoader.Run(flowIds, () => this._VarsLoaded(), (why) => this._LoadInterrupted(why))
    }

    ; Flows and variables are loaded: the start is complete.
    _VarsLoaded() {
        if (this._flowsLoaded)
            return
        this._flowsLoaded := true
        this._loadActive := false
        SetTimer(this._pollFn, 0)
        added := []
        for rec in this.flows.All()
            added.Push(rec.FlowId)
        ; The supervisor starts a restarted engine with --restarted=<n>. The engine owns the epoch, so it
        ; announces the new one itself (ARCHITECTURE 6.2, PROTOCOL 4.3); clients then call cmd.engine.snapshot.
        if (this.args.Has("restarted"))
            this.Emit("topic:engine", "evt.engine.restarted", Map())
        this.Emit("topic:engine", "evt.flow.list.changed", Map("added", added, "removed", [], "changed", []))
        this.Emit("topic:engine", "evt.engine.ready", Map())
        this._Log("a1", "engine", "ready with " this.flows.Count " flow(s) and " this.varLoader.Count " variable(s)")
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
                , "enabled", Json.Bool(rec.Enabled), "executing", Json.Bool(this.executor.IsExecuting(rec.FlowId))
                , "rev", rec.Rev))
        }
        ; "ready": the start is complete (evt.engine.ready was sent). A client that subscribed late cannot know it from the
        ; event (F-0090).
        return Map("epoch", this.epoch, "seq", this.seq, "flows", list, "settings", Map()
            , "ready", Json.Bool(this._flowsLoaded))
    }

    _CmdFlowGet(msg) {
        rec := this.flows.Require(Engine.Text(msg, "flowId"))
        return Map("rev", rec.Rev, "definition", rec.Def.WireDefinition())
    }

    _CmdFlowStart(msg) {
        rec := this.flows.Require(Engine.Text(msg, "flowId"))
        instId := this.executor.StartFlow(rec, Engine.Optional(msg, "triggerId"))
        ; Policy wait while the flow runs: the instance is queued (PROTOCOL 4.2), "waiting" is only sent then.
        if (this.executor.IsWaiting(instId))
            return Map("instanceId", instId, "waiting", Json.True)
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

    ; Phase 2: sets the flag and reports it. No trigger is armed (WI-0014, Phase 3).
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
                , "rev", rec.Rev, "definition", rec.Def.WireDefinition())
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

    ; cmd.flow.save (PROTOCOL 4.2, WI-0039): writes the committed definition through storage and answers when storage has
    ; written it. The file carries the format version and the markers of the elements whose expression texts wait for
    ; their class (FlowDefinition.ToFileText). The revision is the one that was written, even if a patch commits
    ; another one while storage works.
    _CmdFlowSave(msg) {
        flowId := Engine.Text(msg, "flowId")
        rec := this.flows.Require(flowId)
        savedRev := rec.Rev
        text := rec.Def.ToFileText()
        this.peer.Request(Engine.STORAGE, "cmd.storage.flow.write"
            , Map("path", "Flows/" flowId ".json", "text", text, "backup", Json.True)
            , (res) => this._OnFlowSaved(msg, flowId, savedRev, res), Engine.SAVE_TIMEOUT_MS)
        return Deferred.Marker()
    }

    _OnFlowSaved(request, flowId, savedRev, res) {
        try {
            if (res.payload.Get("ok", false)) {
                this.Emit("topic:flow:" flowId, "evt.flow.saved", Map("flowId", flowId, "savedRev", savedRev))
                this.peer.Reply(request, Map("savedRev", savedRev))
                return
            }
            this._Log("a0", "engine", "saving flow '" flowId "' failed: " Engine._ErrorText(res))
            err := res.payload.Get("error", "")
            this.peer.Reply(request, Map("ok", false, "error", (err is Map) ? err
                : Map("code", ErrCode.INTERNAL, "message", "storage did not write the flow")))
        } catch as e {
            this._Log("a0", "engine", "answering cmd.flow.save failed: " Type(e) ": " e.Message)
        }
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

    ; Pool options (WI-0027, ARCHITECTURE 6.4): --workers=<N> (default 4, 0 = no pool; worker elements then end with
    ; "exception"), --warm-workers=<W> (default 1, at most N), --worker-idle-ms=<ms> (default 60000).
    static _PoolOptions(args) {
        size := Engine._IntOption(args, "workers", WorkerBridge.DEFAULT_SIZE, 0, WorkerBridge.MAX_SIZE)
        warm := Engine._IntOption(args, "warm-workers", Min(WorkerBridge.DEFAULT_WARM, size), 0, size)
        idleMs := Engine._IntOption(args, "worker-idle-ms", WorkerBridge.DEFAULT_IDLE_MS, WorkerBridge.MIN_IDLE_MS
            , WorkerBridge.MAX_IDLE_MS)
        return Map("size", size, "warm", warm, "idleMs", idleMs)
    }

    ; Options of the variable files (WI-0041): --var-write-delay-ms=<ms> (default 200, 0 to 60000): how long a change
    ; waits for more changes of the same variable; --var-write-timeout-ms=<ms> (default 10000, 100 to 120000): limit
    ; of one write request to storage. The supervisor passes both on to the engine.
    static _VarOptions(args) {
        return Map("delayMs", Engine._IntOption(args, "var-write-delay-ms", VarWriter.DELAY_MS, 0, 60000)
            , "timeoutMs", Engine._IntOption(args, "var-write-timeout-ms", VarWriter.TIMEOUT_MS, 100, 120000))
    }

    static _IntOption(args, key, fallback, low, high) {
        raw := args.Get(key, fallback)
        if (!IsInteger(raw) || Integer(raw) < low || Integer(raw) > high)
            throw AhfError("--" key " must be an integer from " low " to " high, ErrCode.BAD_ARGS)
        return Integer(raw)
    }

    ; True if the answer says that storage is not there or not answering: the engine waits for it instead of
    ; reporting an error. not_found counts only for the hub's "no peer 'storage'", not for a missing file.
    static _StorageGone(res) {
        err := res.payload.Get("error", "")
        if (!(err is Map))
            return false
        code := err.Get("code", "")
        if (code = ErrCode.TIMEOUT || code = ErrCode.PEER_GONE || code = ErrCode.SHUTTING_DOWN)
            return true
        return code = ErrCode.NOT_FOUND && SubStr(String(err.Get("message", "")), 1, 7) = "no peer"
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
