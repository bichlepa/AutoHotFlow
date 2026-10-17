#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Lang.ahk
#Include ..\core\Time.ahk
#Include ..\core\ipc\Deferred.ahk
#Include core\FlowOrder.ahk

; The categories and the order of the flow list (WI-0071, E0067, PROTOCOL 4.2 "Categories", 4.6 Categories.json). The engine
; holds the order (FlowOrder); storage keeps the file. Start: the file is read before the flows' variables and the trigger
; state, and before evt.engine.ready. A missing or broken file gives an order built from the flows, alphabetically; a read
; that fails for another reason makes the start wait (nothing is written before the file was read).
;
; Changes: create, order and sort change the order at once; every change of the order (also a flow created, moved or
; deleted, see Sync) sends evt.category.changed and marks the file. The file is written at most once per WRITE_INTERVAL_MS,
; and at shutdown (FlushAll). Rename and delete write the category of their flows first, one flow file each (through
; FlowLifecycle.SetCategory); the order follows when every write has been answered. While such a command waits, the
; category commands are busy and a flow cannot take the category (IsBusy, FlowLifecycle).
class FlowCategories {
    static WRITE_INTERVAL_MS := 1000
    static TIMEOUT_MS := 30000
    static RETRY_MS := 1000
    static UNCATEGORIZED_NAME := "Uncategorized"

    __New(engine) {
        this._engine := engine
        this._order := FlowOrder()
        this._loaded := false          ; the file was read (or built) in this start
        this._busy := false            ; a rename or delete waits for the flow files
        this._lastSig := ""            ; signature of the order as last reconciled; a change is written and sent
        this._dirty := false           ; changed and not written yet
        this._scheduled := false
        this._closing := false
        this._lastWrite := 0           ; Time.NowMs() of the last write request
        this._reported := false        ; the last write failed and was reported
        this._onDone := ""
        this._onDown := ""
        this._readFn := () => this._Read()
        this._writeFn := () => this._Write()
    }

    ; True while a rename or delete waits for the flow files.
    IsBusy => this._busy

    ; True when the category exists ("" is the uncategorized group, which always exists).
    Has(name) => this._order.Has(name)

    ; The order for the snapshot and the event: Array of Map(name, flows).
    Entries() => this._order.Entries()

    ; --- start -------------------------------------------------------------------------------------

    ; Reads the file once per start. onDone() runs when the order is in line with the flows; onDown(why) when storage is
    ; gone or silent (the engine waits and calls Load again).
    Load(onDone, onDown) {
        if (this._loaded) {
            onDone()
            return
        }
        this._onDone := onDone
        this._onDown := onDown
        this._Read()
    }

    _Read() {
        try {
            this._engine.peer.Request("storage", "cmd.storage.categories.read", Map()
                , (res) => this._OnRead(res), FlowCategories.TIMEOUT_MS)
        } catch as e {
            this._onDown(Type(e) ": " e.Message)
        }
    }

    _OnRead(res) {
        if (!res.payload.Get("ok", false)) {
            why := Engine._ErrorText(res)
            if (Engine._StorageGone(res)) {
                this._onDown(why)
                return
            }
            ; another failure: the start waits here and reads again (the order is needed before the start goes on)
            this._engine._StorageError("categories.read", "Categories.json", why)
            SetTimer(this._readFn, -FlowCategories.RETRY_MS)
            return
        }
        if (!Engine._Flag(res.payload.Get("exists", false))) {
            this._Finish(true)
            return
        }
        try {
            entries := FlowOrder.Parse(res.payload.Get("text", ""))
        } catch as e {
            this._engine._Log("a0", "engine", "Categories.json is broken (" e.Message "); it is kept as "
                . "Categories.json.broken, the order is built from the flows")
            this._Keep()
            this._Finish(true)
            return
        }
        this._order.Load(entries)
        this._lastSig := this._order.Signature()
        this._Finish(false)
    }

    ; The order is brought in line with the flows. A fresh order (no usable file) is sorted alphabetically, as v1 showed
    ; the list. Then the start goes on; the file is written when it differs from what was read.
    _Finish(fresh) {
        if (fresh)
            this._order := FlowOrder()
        this._order.Reconcile(this._Members())
        if (fresh)
            this._order.SortAlphabetically(this._NameMap())
        this._loaded := true
        this._Sync(false)
        onDone := this._onDone
        this._onDone := ""
        this._onDown := ""
        onDone()
    }

    _Keep() {
        try {
            this._engine.peer.Request("storage", "cmd.storage.categories.keepBroken", Map()
                , (res) => this._OnKept(res), FlowCategories.TIMEOUT_MS)
        } catch as e {
            this._engine._Log("a0", "engine", "keeping Categories.json as broken failed: " e.Message)
        }
    }

    _OnKept(res) {
        if (!res.payload.Get("ok", false))
            this._engine._Log("a0", "engine", "keeping Categories.json as broken failed: " Engine._ErrorText(res))
    }

    ; --- changes that the table makes ------------------------------------------------------------

    ; Brings the order in line with the flows (membership follows the category of each flow). Called after every change
    ; of the flow table; emit false during the start (the event is not sent before evt.engine.ready).
    Sync(emit := true) => this._Sync(emit)

    _Sync(emit) {
        this._order.Reconcile(this._Members())
        sig := this._order.Signature()
        if (sig == this._lastSig)
            return
        this._lastSig := sig
        if (!this._loaded)
            return
        this._dirty := true
        this._Schedule()
        if (emit)
            this._engine.Emit("topic:engine", "evt.category.changed", Map("categories", this._order.Entries()))
    }

    _Members() {
        members := []
        for rec in this._engine.flows.All()
            members.Push(Map("flowId", rec.FlowId, "category", rec.Def.Category))
        return members
    }

    _NameMap() {
        names := Map()
        names.CaseSense := "On"
        for rec in this._engine.flows.All()
            names[rec.FlowId] := rec.Def.Name
        return names
    }

    ; --- commands ------------------------------------------------------------------------------------

    ; cmd.category.create { name }: appended before the uncategorized group. Answered at once.
    CmdCreate(msg) {
        this._RequireReady()
        this._RequireFree()
        name := Engine.Text(msg, "name")
        this._CheckName(name, "")
        this._order.Create(name)
        this._Sync(true)
        return Map()
    }

    ; cmd.category.rename { name, newName }: the flow files of the category get the new name first (one write each).
    CmdRename(msg) {
        this._RequireReady()
        this._RequireFree()
        name := this._KnownCategory(msg, "name")
        newName := Engine.Text(msg, "newName")
        if (name == newName)
            return Map()
        this._CheckName(newName, name)
        flowIds := this._order.FlowsOf(name)
        this._RequireIdleFlows(flowIds)
        if (flowIds.Length = 0) {
            this._order.Rename(name, newName)
            this._Sync(true)
            return Map()
        }
        this._WriteCategories(flowIds, newName, (failed) => this._RenameDone(msg, name, newName, failed))
        return Deferred.Marker()
    }

    ; Every answer goes out, also when a step throws (the request must not wait for its deadline). While the writes were
    ; pending, another command may have changed the flows: a Sync then created newName from the written flows, so the
    ; old group is merged into it instead of renamed.
    _RenameDone(request, name, newName, failed) {
        try {
            if (!(failed is Map)) {
                if (this._order.Has(newName)) {
                    this._Sync(false)
                    if (this._order.Has(name)) {
                        this._order.MoveAll(name, newName)
                        this._order.Remove(name)
                    }
                } else {
                    this._order.Rename(name, newName)
                }
            }
            this._Sync(true)
            if (failed is Map)
                this._ReplyFailed(request, "renaming category '" name "' failed", failed)
            else
                this._engine.peer.Reply(request, Map())
        } catch as e {
            this._AnswerInternal(request, "renaming category '" name "'", e)
        }
    }

    ; Answers a request whose last step threw: an internal error, logged with the reason.
    _AnswerInternal(request, what, e) {
        this._engine._Log("a0", "engine", "answering " what " failed: " Type(e) ": " e.Message)
        try {
            this._engine.peer.Reply(request, Map("ok", false, "error"
                , Map("code", ErrCode.INTERNAL, "message", "the engine could not finish " what)))
        } catch as e2 {
            this._engine._Log("a0", "engine", "answering failed too: " Type(e2) ": " e2.Message)
        }
    }

    ; cmd.category.delete { name, moveTo }: the flows move to moveTo first; then the category is removed.
    CmdDelete(msg) {
        this._RequireReady()
        this._RequireFree()
        name := this._KnownCategory(msg, "name")
        flowIds := this._order.FlowsOf(name)
        moveTo := ""
        if (flowIds.Length) {
            if (!msg.payload.Has("moveTo"))
                throw AhfError("the flows of category '" name "' must move to another category (moveTo)", ErrCode.BAD_PAYLOAD)
            moveTo := Engine.Optional(msg, "moveTo")
            if (moveTo == name || !this._order.Has(moveTo))
                throw AhfError("moveTo must be another existing category or '' (uncategorized)", ErrCode.BAD_PAYLOAD)
        }
        this._RequireIdleFlows(flowIds)
        if (flowIds.Length = 0) {
            this._order.Remove(name)
            this._Sync(true)
            return Map()
        }
        this._WriteCategories(flowIds, moveTo, (failed) => this._DeleteDone(msg, name, moveTo, failed))
        return Deferred.Marker()
    }

    _DeleteDone(request, name, moveTo, failed) {
        try {
            if (!(failed is Map) && this._order.Has(name)) {
                this._order.MoveAll(name, moveTo)
                this._order.Remove(name)
            }
            this._Sync(true)
            if (failed is Map)
                this._ReplyFailed(request, "deleting category '" name "' failed", failed)
            else
                this._engine.peer.Reply(request, Map())
        } catch as e {
            this._AnswerInternal(request, "deleting category '" name "'", e)
        }
    }

    ; cmd.category.order { categories?, flows? }: a new order, checked as a whole (every list is a permutation); a refused
    ; order changes nothing.
    CmdOrder(msg) {
        this._RequireReady()
        this._RequireFree()
        p := msg.payload
        if (!p.Has("categories") && !p.Has("flows"))
            throw AhfError("cmd.category.order needs categories or flows", ErrCode.BAD_PAYLOAD)
        next := this._order.Clone()
        if (p.Has("categories")) {
            list := p["categories"]
            if (!(list is Array))
                throw AhfError("payload field 'categories' must be a list", ErrCode.BAD_PAYLOAD)
            next.SetCategories(list)
        }
        if (p.Has("flows")) {
            byName := p["flows"]
            if (!(byName is Map))
                throw AhfError("payload field 'flows' must be an object of lists", ErrCode.BAD_PAYLOAD)
            for name, ids in byName {
                if (!(ids is Array))
                    throw AhfError("the flows of '" name "' must be a list", ErrCode.BAD_PAYLOAD)
                next.SetFlows(name, ids)
            }
        }
        this._order := next
        this._Sync(true)
        return Map()
    }

    ; cmd.category.sort {}: categories and flows sorted by name, once.
    CmdSort(msg) {
        this._RequireReady()
        this._RequireFree()
        this._order.SortAlphabetically(this._NameMap())
        this._Sync(true)
        return Map()
    }

    ; --- writes of the flow files --------------------------------------------------------------------

    ; Sets the category of every flow to toName, one write per flow; done(failed) runs when all are answered, failed is
    ; "" or the error of the first failed write. The category commands are busy until then.
    _WriteCategories(flowIds, toName, done) {
        this._busy := true
        st := Map("left", flowIds.Length, "failed", false)
        for flowId in flowIds
            this._WriteOne(st, flowId, toName, done)
    }

    _WriteOne(st, flowId, toName, done) {
        try {
            this._engine.lifecycle.SetCategory(flowId, toName, (ok, err) => this._OneDone(st, ok, err, done))
        } catch as e {
            this._OneDone(st, false, Map("code", ErrCode.INTERNAL, "message", Type(e) ": " e.Message), done)
        }
    }

    _OneDone(st, ok, err, done) {
        if (!ok && !(st["failed"] is Map))
            st["failed"] := err
        st["left"] -= 1
        if (st["left"] > 0)
            return
        this._busy := false
        try {
            done(st["failed"])
        } catch as e {
            this._engine._Log("a0", "engine", "finishing a category change failed: " Type(e) ": " e.Message)
        }
    }

    ; --- checks ----------------------------------------------------------------------------------------

    _RequireReady() {
        if (!this._engine.IsLoaded)
            throw AhfError("the engine is still loading the flows", ErrCode.BUSY)
    }

    _RequireFree() {
        if (this._busy)
            throw AhfError("a category change is still being saved; try again", ErrCode.BUSY)
    }

    _RequireIdleFlows(flowIds) {
        for flowId in flowIds
            this._engine.lifecycle.CheckIdle(flowId)
    }

    ; The category of a text field of a rename or delete: an existing category, not the uncategorized group.
    _KnownCategory(msg, key) {
        if (!msg.payload.Has(key))
            throw AhfError("payload field '" key "' is missing", ErrCode.BAD_PAYLOAD)
        name := Engine.Optional(msg, key)
        if (name == FlowOrder.UNCATEGORIZED)
            throw AhfError("the uncategorized group cannot be renamed or deleted", ErrCode.BAD_PAYLOAD)
        if (!this._order.Has(name))
            throw AhfError("unknown category '" name "'", ErrCode.BAD_PAYLOAD)
        return name
    }

    ; A name of a category: not empty, no "|" (as flow names), not the uncategorized group's name, unique ignoring case.
    ; ownName is the category that keeps the name (a rename may change the case of its own name).
    _CheckName(name, ownName) {
        if (name = "")
            throw AhfError("the name of a category must not be empty", ErrCode.BAD_PAYLOAD)
        if (InStr(name, "|"))
            throw AhfError("the name of a category must not contain '|'", ErrCode.BAD_PAYLOAD)
        if (StrLower(name) = StrLower(Lang(FlowCategories.UNCATEGORIZED_NAME)))
            throw AhfError("the name '" name "' is reserved for the uncategorized group", ErrCode.BAD_PAYLOAD)
        for existing in this._order.Names() {
            if (existing != "" && existing != ownName && StrLower(existing) = StrLower(name))
                throw AhfError("a category with name '" name "' already exists.", ErrCode.BAD_PAYLOAD)
        }
    }

    ; --- answers ---------------------------------------------------------------------------------------

    _ReplyFailed(request, text, err) {
        this._engine._Log("a0", "engine", text ": " err.Get("message", ""))
        this._engine.peer.Reply(request, Map("ok", false, "error", err))
    }

    ; --- writes --------------------------------------------------------------------------------------------

    _Schedule() {
        if (this._scheduled || !this._dirty || !this._loaded || this._closing)
            return
        wait := Max(1, this._lastWrite + FlowCategories.WRITE_INTERVAL_MS - Time.NowMs())
        this._scheduled := true
        SetTimer(this._writeFn, -wait)
    }

    _Write() {
        this._scheduled := false
        if (this._closing || !this._loaded || !this._dirty)
            return
        this._Send(FlowCategories.TIMEOUT_MS, false)
    }

    ; sys.shutdown: the changed order is sent without waiting for the answer (storage empties its queue before it ends).
    ; Returns true if a request left.
    FlushAll(deadlineMs) {
        this._closing := true
        SetTimer(this._writeFn, 0)
        this._scheduled := false
        if (!this._loaded || !this._dirty)
            return false
        return this._Send(Max(500, Integer(deadlineMs)), true)
    }

    ; Sends the whole order as it is now. Returns true if a request left.
    _Send(timeoutMs, closing) {
        this._dirty := false
        text := this._order.Text()
        this._lastWrite := Time.NowMs()
        try {
            this._engine.peer.Request("storage", "cmd.storage.categories.write", Map("text", text)
                , (res) => this._OnWritten(res, closing), timeoutMs)
            return true
        } catch as e {
            why := Type(e) ": " e.Message
            if (closing)
                this._engine._Log("a0", "engine", "shutdown: Categories.json not sent: " why)
            else
                this._Failed(why)
            return false
        }
    }

    _OnWritten(res, closing) {
        if (res.payload.Get("ok", false)) {
            if (this._reported) {
                this._reported := false
                this._engine._Log("a1", "engine", "Categories.json written after an earlier failure")
            }
            return
        }
        this._Failed(Engine._ErrorText(res), !closing)
    }

    ; Reports the first failure; the write is tried again after the interval, unless the engine is closing.
    _Failed(why, retry := true) {
        if (!this._reported) {
            this._reported := true
            this._engine._StorageError("categories.write", "Categories.json", why)
        }
        if (retry && !this._closing) {
            this._dirty := true
            this._Schedule()
        }
    }
}
