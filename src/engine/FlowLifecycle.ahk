#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Lang.ahk
#Include ..\core\ipc\Deferred.ahk
#Include core\FlowDefinition.ahk
#Include core\FlowExprConvert.ahk
#Include FlowRecord.ahk

; The life of a flow in the engine (WI-0070, PROTOCOL 4.2 "Flow lifecycle", E0065, E0066): create, duplicate, rename and
; move (cmd.flow.meta.update) and delete. The engine owns the committed definitions (FlowTable); storage writes the
; files. A command changes the table only after storage has answered, so an error of storage changes nothing in the
; table. Names are checked here, in every command that sets one.
;
; Pending work: while a create or duplicate waits, its flow ID and its name are taken (_ids, _names); while a meta
; update waits, the flow is busy (_metaPending); while a delete waits, the flow is busy and its files are held back
; by the writers (_deleting, Engine.IsDeleting). The engine never blocks: every request has a timeout and every
; answer goes through the callback.
class FlowLifecycle {
    static CREATE_TRIES := 5
    static TIMEOUT_MS := 30000
    static ID_TRIES := 20
    static FLOW_PREFIX := "Flow "
    static TRIGGER_ID := "element0000000001"

    __New(engine) {
        this._engine := engine
        this._deleting := Map()         ; flow ID -> true while cmd.flow.delete waits for storage
        this._metaPending := Map()      ; flow ID -> true while cmd.flow.meta.update waits for storage
        this._ids := Map()              ; flow ID -> true for a create or duplicate that waits for storage
        this._names := Map()            ; name -> flow ID of the create, duplicate or rename that holds it
        this._names.CaseSense := "Off"  ; flow names are compared ignoring case, as in v1
    }

    IsDeleting(flowId) => this._deleting.Has(flowId)

    ; --- commands --------------------------------------------------------------------------------

    ; cmd.flow.create { name?, category?, definition? }: the empty v1 flow (one manual trigger, disabled) or the given
    ; definition (loaded like a file, expression texts converted, all triggers disabled, E0058).
    CmdCreate(msg) {
        this._RequireLoaded()
        name := Engine.Optional(msg, "name")
        category := Engine.Optional(msg, "category")
        defn := msg.payload.Get("definition", "")
        if (defn is Map) {
            raw := FlowDefinition.CopyValue(defn)
            if (name = "" && !IsObject(raw.Get("name", "")))
                name := String(raw.Get("name", ""))
            convert := true
        } else if (defn = "") {
            raw := FlowLifecycle._EmptyFlow()
            convert := false
        } else {
            throw AhfError("payload field 'definition' must be an object", ErrCode.BAD_PAYLOAD)
        }
        if (name = "")
            name := this._NewName(Lang("New_flow"))
        else
            this._CheckName(name, "")
        raw["name"] := name
        if (category != "" || !raw.Has("category"))
            raw["category"] := category
        return this._Create(msg, raw, "", convert, 1)
    }

    ; cmd.flow.duplicate { flowId, name? }: a copy of the committed definition with a new ID; all triggers disabled, no
    ; static variables and no state file (the copy has none).
    CmdDuplicate(msg) {
        this._RequireLoaded()
        flowId := Engine.Text(msg, "flowId")
        rec := this._engine.flows.Require(flowId)
        this._RequireIdle(flowId)
        name := Engine.Optional(msg, "name")
        if (name = "")
            name := this._NewCopyName(rec.Def.Name)
        else
            this._CheckName(name, "")
        raw := FlowDefinition.CopyValue(rec.Def.Raw)
        raw["name"] := name
        return this._Create(msg, raw, rec.Def.Pending, false, 1)
    }

    ; cmd.flow.meta.update { flowId, name?, category? }: the committed definition gets the new name and category, and the
    ; file is written at once (E0065). The revision is committed when storage has written the file.
    CmdMetaUpdate(msg) {
        flowId := Engine.Text(msg, "flowId")
        rec := this._engine.flows.Require(flowId)
        this._RequireIdle(flowId)
        name := rec.Def.Name
        category := rec.Def.Category
        if (msg.payload.Has("name"))
            name := FlowLifecycle._Field(msg, "name")
        if (msg.payload.Has("category"))
            category := FlowLifecycle._Field(msg, "category")
        if (!(name == rec.Def.Name))          ; a change of case counts as a change (= ignores case)
            this._CheckName(name, flowId)
        if (name == rec.Def.Name && category == rec.Def.Category)
            return Map("rev", rec.Rev)
        raw := FlowDefinition.CopyValue(rec.Def.Raw)
        raw["name"] := name
        raw["category"] := category
        def := FlowDefinition(flowId, raw, rec.Rev + 1)
        def.Pending := rec.Def.Pending.Clone()
        this._metaPending[flowId] := true
        this._ReserveName(name, flowId)
        this._engine.peer.Request("storage", "cmd.storage.flow.write"
            , Map("path", "Flows/" flowId ".json", "text", def.ToFileText(), "backup", Json.True)
            , (res) => this._OnMetaWritten(msg, flowId, rec, def, res), FlowLifecycle.TIMEOUT_MS)
        return Deferred.Marker()
    }

    ; cmd.flow.delete { flowId } (E0066, E0009): the instances stop at once; storage removes the flow file, the state file
    ; and the static variables; the table entry goes when storage has answered.
    CmdDelete(msg) {
        flowId := Engine.Text(msg, "flowId")
        this._engine.flows.Require(flowId)
        this._RequireIdle(flowId)
        this._deleting[flowId] := true
        stopped := this._engine.executor.FlowDeleted(flowId)
        this._engine._Log("a1", "engine", "deleting flow '" flowId "': " stopped " instance(s) stopped")
        this._engine.peer.Request("storage", "cmd.storage.flow.delete", Map("flowId", flowId)
            , (res) => this._OnDeleted(msg, flowId, res), FlowLifecycle.TIMEOUT_MS)
        return Deferred.Marker()
    }

    ; --- create and duplicate --------------------------------------------------------------------

    ; Starts the write of a new flow with a flow ID that no flow of the table has. Returns the marker of a deferred answer.
    _Create(request, raw, pending, convert, attempt) {
        flowId := this._FreshId()
        def := this._Build(flowId, raw, pending, convert)
        this._ids[flowId] := true
        this._ReserveName(def.Name, flowId)
        this._engine.peer.Request("storage", "cmd.storage.flow.write"
            , Map("path", "Flows/" flowId ".json", "text", def.ToFileText(), "backup", Json.True, "createOnly", Json.True)
            , (res) => this._OnCreated(request, flowId, def, raw, pending, convert, attempt, res)
            , FlowLifecycle.TIMEOUT_MS)
        return Deferred.Marker()
    }

    _OnCreated(request, flowId, def, raw, pending, convert, attempt, res) {
        try {
            this._ids.Delete(flowId)
            this._UnreserveName(def.Name, flowId)
            if (res.payload.Get("ok", false)) {
                this._engine.flows.Insert(FlowRecord(flowId, def, 1))
                this._engine.Emit("topic:engine", "evt.flow.list.changed"
                    , Map("added", [flowId], "removed", [], "changed", []))
                this._engine._Log("a1", "engine", "flow '" flowId "' created: " def.Name)
                this._engine.peer.Reply(request, Map("flowId", flowId))
                return
            }
            err := res.payload.Get("error", "")
            if (err is Map && err.Get("code", "") = ErrCode.CONFLICT && attempt < FlowLifecycle.CREATE_TRIES) {
                ; the file of this ID exists after all (not in the table): another ID
                this._Create(request, raw, pending, convert, attempt + 1)
                return
            }
            this._ReplyStorageError(request, "creating flow '" flowId "' failed", res)
        } catch as e {
            this._ReplyInternal(request, "creating a flow", e)
        }
    }

    ; A flow ID for a new flow: "Flow <number>", a number that no flow of the table has and no pending create takes.
    _FreshId() {
        loop FlowLifecycle.ID_TRIES {
            flowId := FlowLifecycle.FLOW_PREFIX Random(100000000, 999999999)
            if (!this._engine.flows.Has(flowId) && !this._ids.Has(flowId))
                return flowId
        }
        throw AhfError("no free flow ID was found", ErrCode.INTERNAL)
    }

    ; The record of a new flow (its definition, converted when the definition came from outside).
    _Build(flowId, raw, pending, convert) {
        def := FlowDefinition(flowId, FlowDefinition.CopyValue(raw), 1)
        if (convert) {
            try {
                FlowExprConvert.Run(def)
            } catch as e {
                Log.Write("f1", "flow create", "converting the expression texts failed (" Type(e) ": " e.Message "); "
                    . "the flow is created unconverted", flowId)
            }
        } else if (IsObject(pending)) {
            def.Pending := pending.Clone()
        }
        return def
    }

    ; The empty flow of v1 (NewFlow, initNewFlow): one manual trigger that is the default trigger; strictTypes as in v2.
    static _EmptyFlow() {
        trigger := Map("class", "Trigger_Manual", "DefaultTrigger", Json.True, "ID", FlowLifecycle.TRIGGER_ID
            , "name", Lang("Manual"), "package", "Default", "packageVersion", "1.2.0", "pars", Map("ID", "")
            , "type", "trigger", "x", 0, "y", 0)
        elements := Map()
        elements[FlowLifecycle.TRIGGER_ID] := trigger
        settings := Map("ExecutionPolicy", "default", "DefaultWorkingDir", 1, "WorkingDir", ""
            , FlowDefinition.STRICT_KEY, FlowDefinition.NEW_FLOW_STRICT_TYPES)
        return Map("name", "", "category", "", "ElementIDCounter", 1, "allElements", elements
            , "allConnections", Map(), "flowSettings", settings)
    }

    ; --- rename and move -------------------------------------------------------------------------

    _OnMetaWritten(request, flowId, rec, def, res) {
        try {
            this._metaPending.Delete(flowId)
            this._UnreserveName(def.Name, flowId)
            if (!res.payload.Get("ok", false)) {
                this._ReplyStorageError(request, "saving flow '" flowId "' failed", res)
                return
            }
            if (!(this._engine.flows.Get(flowId) == rec)) {
                this._ReplyError(request, ErrCode.NOT_FOUND, "flow '" flowId "' is not loaded any more")
                return
            }
            rec.Commit(def)
            this._engine.Emit("topic:flow:" flowId, "evt.flow.committed"
                , Map("flowId", flowId, "rev", rec.Rev, "byMeta", Json.True))
            this._engine.Emit("topic:engine", "evt.flow.list.changed", Map("added", [], "removed", [], "changed", [flowId]))
            this._engine.peer.Reply(request, Map("rev", rec.Rev))
        } catch as e {
            this._ReplyInternal(request, "changing a flow", e)
        }
    }

    ; --- delete ----------------------------------------------------------------------------------

    _OnDeleted(request, flowId, res) {
        try {
            this._deleting.Delete(flowId)
            if (!res.payload.Get("ok", false)) {
                ; nothing is removed: the held writes go on, the flow stays as it was (its instances are stopped)
                this._engine.varWriter.Resume()
                this._engine.flowState.Touch(flowId)
                this._ReplyStorageError(request, "deleting flow '" flowId "' failed", res)
                return
            }
            this._engine.RemoveFlow(flowId)
            this._engine.flowState.Forget(flowId)
            this._engine.vars.DropStatic(flowId)
            this._engine.varWriter.Forget(flowId)
            this._engine.Emit("topic:engine", "evt.flow.list.changed", Map("added", [], "removed", [flowId], "changed", []))
            this._engine._Log("a1", "engine", "flow '" flowId "' deleted")
            this._engine.peer.Reply(request, Map())
        } catch as e {
            this._ReplyInternal(request, "deleting a flow", e)
        }
    }

    ; --- names and checks ------------------------------------------------------------------------

    ; A name of a flow: not empty, no "|" (v1: the manager lists the names separated by "|"), not the name of another
    ; flow, ignoring case. ownId is the flow that keeps the name (it does not count as a clash). Throws bad_payload with
    ; the text the manager shows.
    _CheckName(name, ownId) {
        if (name = "")
            throw AhfError("the name of a flow must not be empty", ErrCode.BAD_PAYLOAD)
        if (InStr(name, "|"))
            throw AhfError(Lang("Following characters are prohibited in a flow name: '%1%'", "|"), ErrCode.BAD_PAYLOAD)
        if (this._NameTaken(name, ownId))
            throw AhfError(Lang("A flow with name '%1%' already exists.", name), ErrCode.BAD_PAYLOAD)
    }

    ; True if another flow has the name (ignoring case) or a pending command holds it.
    _NameTaken(name, ownId) {
        lower := StrLower(name)
        for rec in this._engine.flows.All() {
            if (rec.FlowId != ownId && StrLower(rec.Def.Name) = lower)
                return true
        }
        owner := this._names.Get(name, "")
        return owner != "" && owner != ownId
    }

    ; "New flow <n>" with the lowest n that is free (v1 NewFlow).
    _NewName(prefix) {
        n := 1
        loop {
            candidate := prefix " " n
            if (!this._NameTaken(candidate, ""))
                return candidate
            n += 1
        }
    }

    ; "<name> 2", or the next number that is free (WI-0070, MIGRATION M-0079).
    _NewCopyName(name) {
        n := 2
        loop {
            candidate := name " " n
            if (!this._NameTaken(candidate, ""))
                return candidate
            n += 1
        }
    }

    _ReserveName(name, flowId) {
        this._names[name] := flowId
    }

    _UnreserveName(name, flowId) {
        if (this._names.Get(name, "") = flowId)
            this._names.Delete(name)
    }

    _RequireLoaded() {
        if (!this._engine.IsLoaded)
            throw AhfError("the engine is still loading the flows", ErrCode.BUSY)
    }

    ; A flow that a command of this class is changing cannot take another command now.
    _RequireIdle(flowId) {
        if (this._deleting.Has(flowId))
            throw AhfError("flow '" flowId "' is being deleted", ErrCode.BUSY)
        if (this._metaPending.Has(flowId))
            throw AhfError("a change of flow '" flowId "' is still being saved; try again", ErrCode.BUSY)
        if (this._engine.flowState.IsReading(flowId))
            throw AhfError("the state of flow '" flowId "' is being read; try again", ErrCode.BUSY)
    }

    ; A text field that is set (for a name or category): a value, not an object.
    static _Field(msg, key) {
        v := msg.payload.Get(key, "")
        if (IsObject(v))
            throw AhfError("payload field '" key "' must be a value", ErrCode.BAD_PAYLOAD)
        return String(v)
    }

    ; --- answers ---------------------------------------------------------------------------------

    _ReplyStorageError(request, text, res) {
        this._engine._Log("a0", "engine", text ": " Engine._ErrorText(res))
        err := res.payload.Get("error", "")
        this._engine.peer.Reply(request, Map("ok", false, "error", (err is Map) ? err
            : Map("code", ErrCode.INTERNAL, "message", "storage did not write the flow")))
    }

    _ReplyError(request, code, text) {
        this._engine.peer.Reply(request, Map("ok", false, "error", Map("code", code, "message", text)))
    }

    _ReplyInternal(request, what, e) {
        this._engine._Log("a0", "engine", "answering a flow command failed (" what "): " Type(e) ": " e.Message)
        try {
            this._ReplyError(request, ErrCode.INTERNAL, "the engine could not finish " what)
        } catch as e2 {
            this._engine._Log("a0", "engine", "answering failed too: " Type(e2) ": " e2.Message)
        }
    }
}
