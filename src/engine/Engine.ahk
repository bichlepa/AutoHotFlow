#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Ids.ahk
#Include ..\core\Json.ahk
#Include ..\core\Log.ahk
#Include ..\core\Role.ahk
#Include FlowRecord.ahk
#Include FlowTable.ahk
#Include FlowStateFile.ahk
#Include FlowLifecycle.ahk
#Include FlowCategories.ahk
#Include Executor.ahk
#Include TriggerArms.ahk
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
; the same waiting for storage after an abort); then (WI-0060, E0063) the enabled state of the triggers, one file per
; flow (FlowStateFile). evt.engine.ready is sent once every file of the list has a result (loaded, or a real read or parse
; error) and the variables and the state are loaded. Changes of the variables are written back delayed by VarWriter
; and at shutdown; changes of the trigger state by FlowStateFile.
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
        this.flowState := FlowStateFile(this, this.flows)   ; enabled state of the triggers (WI-0060)
        this.lifecycle := FlowLifecycle(this)               ; create, duplicate, rename and delete a flow (WI-0070)
        this.categories := FlowCategories(this)             ; categories and the order of the list (WI-0071)
        this.arms := TriggerArms(this)                       ; arming of the enabled triggers in the trigger host (WI-0062)
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
        this.On("cmd.flow.enable", (msg) => this._CmdFlowEnable(msg))
        this.On("cmd.flow.disable", (msg) => this._CmdFlowDisable(msg))
        this.On("cmd.trigger.enable", (msg) => this._CmdTriggerSwitch(msg, true))
        this.On("cmd.trigger.disable", (msg) => this._CmdTriggerSwitch(msg, false))
        this.On("cmd.flow.patch", (msg) => this._CmdFlowPatch(msg))
        this.On("cmd.flow.save", (msg) => this._CmdFlowSave(msg))
        this.On("cmd.flow.create", (msg) => this.lifecycle.CmdCreate(msg))
        this.On("cmd.flow.duplicate", (msg) => this.lifecycle.CmdDuplicate(msg))
        this.On("cmd.flow.meta.update", (msg) => this.lifecycle.CmdMetaUpdate(msg))
        this.On("cmd.flow.delete", (msg) => this.lifecycle.CmdDelete(msg))
        this.On("cmd.category.create", (msg) => this.categories.CmdCreate(msg))
        this.On("cmd.category.rename", (msg) => this.categories.CmdRename(msg))
        this.On("cmd.category.delete", (msg) => this.categories.CmdDelete(msg))
        this.On("cmd.category.order", (msg) => this.categories.CmdOrder(msg))
        this.On("cmd.category.sort", (msg) => this.categories.CmdSort(msg))
        this.On("evt.worker.done", (msg) => this.workers.OnDone(msg))
        this.On("evt.trigger.fired", (msg) => this._OnTriggerFired(msg))
        this.On("evt.trigger.error", (msg) => this._OnTriggerError(msg))
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
            flows.Push(Map("flowId", rec.FlowId, "name", rec.Def.Name, "rev", rec.Rev, "enabled", Json.Bool(rec.IsFlowEnabled())
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
        try {
            this.flowState.FlushAll(deadlineMs)
        } catch as e {
            this._Log("a0", "engine", "shutdown: sending the trigger state failed: " Type(e) ": " e.Message)
        }
        try {
            this.categories.FlushAll(deadlineMs)
        } catch as e {
            this._Log("a0", "engine", "shutdown: sending the category order failed: " Type(e) ": " e.Message)
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

    ; evt.flow.state for one flow: the derived enabled state, the number of independent triggers that are enabled and
    ; whether an instance runs (E0056).
    EmitFlowState(flowId) {
        rec := this.flows.Get(flowId)
        enabled := IsObject(rec) ? rec.IsFlowEnabled() : false
        independent := IsObject(rec) ? rec.IndependentActiveCount() : 0
        payload := Map("flowId", flowId, "enabled", Json.Bool(enabled), "independentActive", independent
            , "executing", Json.Bool(this.executor.IsExecuting(flowId)), "instances", this.executor.RunningCount(flowId))
        stateError := this.flowState.ErrorOf(flowId)
        if (stateError != "")
            payload["stateError"] := stateError          ; the state is unknown (E0063): its file cannot be read
        this.Emit("topic:flow:" flowId, "evt.flow.state", payload)
    }

    ; evt.trigger.state for one trigger: its target state and its arming (WI-0060, WI-0062). Called whenever one of them
    ; changes.
    EmitTriggerState(flowId, triggerId) {
        rec := this.flows.Get(flowId)
        enabled := IsObject(rec) && rec.TriggerEnabled(triggerId)
        info := this.arms.Info(flowId, triggerId)
        this.Emit("topic:flow:" flowId, "evt.trigger.state", Map("flowId", flowId, "elementId", triggerId
            , "enabled", Json.Bool(enabled), "armed", Json.Bool(info["armed"]), "message", info["message"]))
    }

    ; A flow leaves the flow table (no command does it yet, S0004): its instances stop, its triggers are disarmed.
    RemoveFlow(flowId) {
        this.executor.FlowDeleted(flowId)
        this.arms.FlowRemoved(flowId)
        return this.flows.Remove(flowId)
    }

    ; True while cmd.flow.delete waits for storage for this flow (WI-0070): no start, no fired trigger, and the writers of
    ; its files hold back.
    IsDeleting(flowId) => this.lifecycle.IsDeleting(flowId)

    ; True once the start is complete (evt.engine.ready was sent).
    IsLoaded => this._flowsLoaded

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
        name := msg.payload.Get("name", "")
        if (name = Engine.STORAGE) {
            if (msg.type = "evt.process.ready")
                this._StartLoad()
            return
        }
        ; The trigger host: a ready host starts a pass of arms (WI-0062); a host that ended has no arms any more.
        if (name = TriggerArms.HOST) {
            if (msg.type = "evt.process.ready")
                this.arms.HostReady()
            else if (msg.type = "evt.process.crashed" || msg.type = "evt.process.exited")
                this.arms.HostGone()
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
        ; The order of the list is read first (WI-0071): storage gone or silent makes the start wait, as the variables do.
        this.categories.Load(() => this._VariablesNext(), (why) => this._LoadInterrupted(why))
    }

    _VariablesNext() {
        if (this._flowsLoaded)
            return
        flowIds := []
        for rec in this.flows.All()
            flowIds.Push(rec.FlowId)
        this.varLoader.Run(flowIds, () => this._StateLoaded(), (why) => this._LoadInterrupted(why))
    }

    ; The variables are loaded: the enabled state of the triggers is next (WI-0060). Storage gone: the start waits again.
    _StateLoaded() {
        if (this._flowsLoaded)
            return
        this.flowState.Load(() => this._VarsLoaded(), (why) => this._LoadInterrupted(why))
    }

    ; Flows, variables and the trigger state are loaded: the start is complete.
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
        for rec in this.flows.All()                     ; a flow whose state is unknown says so (E0063)
            if (this.flowState.ErrorOf(rec.FlowId) != "")
                this.EmitFlowState(rec.FlowId)
        this.Emit("topic:engine", "evt.engine.ready", Map())
        this._Log("a1", "engine", "ready with " this.flows.Count " flow(s) and " this.varLoader.Count " variable(s)")
        this.arms.EngineReady()         ; the arms of the enabled triggers follow when the trigger host is ready (WI-0062)
    }

    _StorageError(op, path, message) {
        this._Log("a0", "engine", "storage " op " failed for '" path "': " message)
        if (this.peer.status = "ready")
            this.Emit("topic:engine", "evt.storage.error", Map("op", op, "path", path, "message", message))
    }

    ; --- commands ------------------------------------------------------------------------------

    ; The packages that the elements of a loaded flow use and that are not installed in this process (E0080, REQ-MIG-070):
    ; the names in the order of the elements, each once. A missing package is not an error of the flow: it loads, and the
    ; element fails when it runs. The registry of the engine holds the classes of every trigger and action it can run.
    _MissingPackages(def) {
        names := []
        for id, elem in def.Raw["allElements"] {
            if (!(elem is Map))
                continue
            package := FlowDefinition.TextOf(def.FlowId, elem, "package", "")
            if (package = "" || ElementRegistry.HasPackage(package))
                continue
            for name in names
                if (name = package)
                    continue 2
            names.Push(package)
        }
        return names
    }

    _CmdSnapshot(msg) {
        list := []
        for rec in this.flows.All() {
            entry := Map("flowId", rec.FlowId, "name", rec.Def.Name, "category", rec.Def.Category
                , "enabled", Json.Bool(rec.IsFlowEnabled()), "executing", Json.Bool(this.executor.IsExecuting(rec.FlowId))
                , "instances", this.executor.RunningCount(rec.FlowId), "missingPackages", this._MissingPackages(rec.Def)
                , "rev", rec.Rev, "independentActive", rec.IndependentActiveCount(), "triggers", this.arms.Snapshot(rec))
            stateError := this.flowState.ErrorOf(rec.FlowId)
            if (stateError != "")
                entry["stateError"] := stateError       ; as in evt.flow.state: the state is unknown (E0063)
            list.Push(entry)
        }
        ; "ready": the start is complete (evt.engine.ready was sent). A client that subscribed late cannot know it from the
        ; event (F-0090).
        return Map("epoch", this.epoch, "seq", this.seq, "flows", list, "categories", this.categories.Entries()
            , "settings", Map(), "ready", Json.Bool(this._flowsLoaded))
    }

    _CmdFlowGet(msg) {
        rec := this.flows.Require(Engine.Text(msg, "flowId"))
        return Map("rev", rec.Rev, "definition", rec.Def.WireDefinition())
    }

    _CmdFlowStart(msg) {
        rec := this.flows.Require(Engine.Text(msg, "flowId"))
        if (this.IsDeleting(rec.FlowId))
            throw AhfError("flow '" rec.FlowId "' is being deleted", ErrCode.BUSY)
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
        if (this.IsDeleting(flowId))
            throw AhfError("flow '" flowId "' is being deleted", ErrCode.BUSY)
        instId := this.executor.StartFlow(rec)
        return Map("action", "started", "instanceId", instId)
    }

    ; cmd.flow.enable (E0056): every trigger that follows the flow is enabled. Nothing is armed yet (WI-0062).
    _CmdFlowEnable(msg) {
        rec := this.flows.Require(Engine.Text(msg, "flowId"))
        if (!rec.HasFollowingTrigger())
            return Engine._NoFollowingTrigger(rec.FlowId)
        return this._SwitchOrRead(msg, rec, () => this._EnableFollowing(rec))
    }

    _EnableFollowing(rec) {
        this._SwitchTriggers(rec, rec.SetFollowingEnabled(true))
        return Map()
    }

    ; cmd.flow.disable (E0056): every trigger that follows the flow is disabled, with all: true every trigger. The answer
    ; counts the independent triggers that stay enabled, so the manager can ask about them.
    _CmdFlowDisable(msg) {
        rec := this.flows.Require(Engine.Text(msg, "flowId"))
        all := Engine._Flag(msg.payload.Get("all", 0))
        if (!all && !rec.HasFollowingTrigger())
            return Engine._NoFollowingTrigger(rec.FlowId)
        return this._SwitchOrRead(msg, rec, () => this._DisableFollowing(rec, all))
    }

    _DisableFollowing(rec, all) {
        this._SwitchTriggers(rec, rec.SetFollowingEnabled(false, all))
        return Map("independentActive", rec.IndependentActiveCount())
    }

    ; cmd.trigger.enable / cmd.trigger.disable (E0056): one trigger. bad_payload if the element is not a trigger of the flow.
    _CmdTriggerSwitch(msg, enabled) {
        rec := this.flows.Require(Engine.Text(msg, "flowId"))
        if (this.IsDeleting(rec.FlowId))
            throw AhfError("flow '" rec.FlowId "' is being deleted", ErrCode.BUSY)
        triggerId := Engine.Text(msg, "elementId")
        if (rec.Def.ElementKind(triggerId) != "trigger")
            throw AhfError("element '" triggerId "' is not a trigger of flow '" rec.FlowId "'", ErrCode.BAD_PAYLOAD)
        return this._SwitchOrRead(msg, rec, () => this._SwitchOne(rec, triggerId, enabled))
    }

    _SwitchOne(rec, triggerId, enabled) {
        if (rec.SetTriggerEnabled(triggerId, enabled))
            this._SwitchTriggers(rec, [triggerId])
        return Map()
    }

    ; Applies a switch to a flow (E0063, PROTOCOL 4.2). A flow whose state is known switches at once. A flow whose
    ; state is unknown reads its file first (the answer comes later, Deferred); force skips the read and writes the
    ; state of the session. apply() returns the answer Map. A switch that cannot wait answers ok false at once.
    _SwitchOrRead(msg, rec, apply) {
        flowId := rec.FlowId
        if (this.flowState.IsKnown(flowId))
            return apply()
        if (!this.flowState.Loaded)
            return Map("ok", false, "message", "the state of flow '" flowId "' is not loaded yet; try again")
        if (this.flowState.IsReading(flowId))
            return Map("ok", false, "message", "the state of flow '" flowId "' is being read; try again")
        if (Engine._Flag(msg.payload.Get("force", 0))) {
            this.flowState.Force(flowId)
            this.EmitFlowState(flowId)                  ; the state is known now (stateError is gone)
            return apply()
        }
        why := this.flowState.Establish(flowId
            , () => this._ReplySwitch(msg, flowId, apply)
            , (text) => this._ReplyRefused(msg, flowId, text))
        if (why != "")
            return Map("ok", false, "message", "the state of flow '" flowId "' cannot be read (" why "); nothing changed")
        return Deferred.Marker()
    }

    _ReplySwitch(request, flowId, apply) {
        try {
            this.EmitFlowState(flowId)                  ; the read succeeded: the state is known now
            ; The read enabled the triggers of the file. Arm and announce them before the switch, as the start does; else
            ; only the switched triggers would be armed and the others stay unarmed until a restart.
            rec := this.flows.Get(flowId)
            merged := this.flowState.TakeMerged(flowId)
            if (IsObject(rec) && merged.Length > 0) {
                for triggerId in merged
                    this.arms.Changed(rec, triggerId)
                for triggerId in merged
                    this.EmitTriggerState(flowId, triggerId)
            }
            this.peer.Reply(request, apply())
        } catch as e {
            this._Log("a0", "engine", "answering a switch failed: " Type(e) ": " e.Message)
        }
    }

    _ReplyRefused(request, flowId, why) {
        try {
            this.peer.Reply(request, Map("ok", false, "message", "the state of flow '" flowId "' cannot be read (" why
                . "); nothing changed; try again, or force the write"))
        } catch as e {
            this._Log("a0", "engine", "answering a switch failed: " Type(e) ": " e.Message)
        }
    }

    ; A switch of an inline element (WI-0065, ctx.SetTriggers, ctx.SetTriggerEnabled): the same switch as the commands,
    ; without a reply. scope "one" switches the trigger triggerId; the other scopes are those of FlowRecord.TriggersOf.
    ; Returns the number of triggers of the scope. Unlike a command, an element cannot wait for the read of a state that
    ; is not known yet (E0063): such a switch is refused at once and changes nothing. The caller turns AhfError into an
    ; exception of the element.
    SwitchFromElement(flowId, scope, enabled, triggerId := "") {
        rec := this.flows.Get(flowId)
        if (!IsObject(rec))
            throw AhfError("flow '" flowId "' is not loaded", ErrCode.NOT_FOUND)
        if (!this.flowState.IsKnown(flowId))
            throw AhfError("the state of flow '" flowId "' cannot be read; nothing changed", ErrCode.DENIED)
        if (scope = "one") {
            if (rec.Def.ElementKind(triggerId) != "trigger")
                throw AhfError("element '" triggerId "' is not a trigger of flow '" flowId "'", ErrCode.BAD_PAYLOAD)
            this._SwitchTriggers(rec, rec.SetEnabledOf([triggerId], enabled))
            return 1
        }
        ids := rec.TriggersOf(scope)
        this._SwitchTriggers(rec, rec.SetEnabledOf(ids, enabled))
        return ids.Length
    }

    ; The runaway guard stopped the flow (WI-0066, REQ-EXE-170, E0062; called by the Executor after its instances ended): all
    ; triggers of the flow are disabled, independent ones too, and the state is saved (WI-0060). The users are told by
    ; evt.flow.limit, the log has an a0 entry. Nothing here waits.
    LimitReached(flowId, kind, limit) {
        this._Log("a0", "engine", "flow '" flowId "' stopped: more than " limit " " kind " (runaway guard); all its triggers are disabled")
        this.Emit("topic:flow:" flowId, "evt.flow.limit", Map("flowId", flowId, "kind", kind, "limit", limit))
        rec := this.flows.Get(flowId)
        if (IsObject(rec))
            this._SwitchTriggers(rec, rec.SetFollowingEnabled(false, true))
    }

    ; Arms or disarms the switched triggers (WI-0062), sends evt.trigger.state for each of them, then evt.flow.state, and
    ; marks the state of this flow for its file (WI-0060, E0063). Nothing is sent when nothing changed.
    _SwitchTriggers(rec, changed) {
        if (changed.Length = 0)
            return
        for triggerId in changed
            this.arms.Changed(rec, triggerId)
        for triggerId in changed
            this.EmitTriggerState(rec.FlowId, triggerId)
        this.EmitFlowState(rec.FlowId)
        this.flowState.Touch(rec.FlowId)
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
        ; A write queued behind a pending delete in storage would re-create the deleted file (WI-0070, E0066).
        if (this.IsDeleting(flowId))
            throw AhfError("flow '" flowId "' is being deleted", ErrCode.BUSY)
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

    ; evt.trigger.fired (WI-0062): an event of an armed trigger starts an instance at it. An event of another generation,
    ; or of a trigger that is not armed or not enabled any more, is dropped (a2).
    _OnTriggerFired(msg) {
        p := msg.payload
        key := String(p.Get("triggerKey", ""))
        gen := p.Get("gen", "")
        flowId := String(p.Get("flowId", ""))
        elementId := String(p.Get("elementId", ""))
        rec := this.flows.Get(flowId)
        if (!IsObject(rec) || !this.arms.Accepts(key, gen) || !rec.TriggerEnabled(elementId) || this.IsDeleting(flowId)) {
            this._Log("a2", "engine", "dropped the event of trigger '" key "' (generation " gen ")")
            return
        }
        data := p.Get("data", "")
        if (!(data is Map))
            data := Map()
        try {
            this.executor.StartFlow(rec, elementId, Map("params", this.arms.ParamsOf(key), "data", data))
        } catch as e {
            ; A refusal by the runaway guard is logged by the executor, at most once per 10 s (WI-0066): not here, or a
            ; flood of fired triggers would flood the log.
            if (e is AhfError && e.code = ErrCode.LIMIT)
                return
            ; busy (policy skip) and similar: the event is lost, as in v1, and the reason is in the log
            Log.Write("f1", "engine", "trigger '" elementId "' did not start an instance: " Executor.ErrorText(e), flowId)
        }
    }

    ; evt.trigger.error (WI-0062): the message of the current arming (it stays armed; the host has logged it).
    _OnTriggerError(msg) {
        p := msg.payload
        key := String(p.Get("triggerKey", ""))
        this.arms.Reported(key, p.Get("gen", ""), String(p.Get("message", "")))
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

    ; The answer of a switch of a flow that has no trigger which follows it (nothing changed).
    static _NoFollowingTrigger(flowId) => Map("ok", false, "message", "flow '" flowId "' has no trigger that follows the "
        . "flow, nothing changed")

    ; A boolean of a message: true for Json.True, 1, "1" or "true" (the parser gives 1 and 0 for true and false).
    static _Flag(v) => (v == Json.True || (!IsObject(v) && (v = 1 || v = "1" || v = "true")))

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
