#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Time.ahk

; Automatic saving of the flows (WI-0095, E0065, PROTOCOL 4.2 and 4.6, ARCHITECTURE 4.2). A committed revision that is
; not written yet is sent to storage about DELAY_MS after the last commit, and at the latest MAX_DELAY_MS after the first
; commit that is not sent yet. A flow has no unsaved state: the engine writes it, the user does not save it.
;
; One write per flow is in flight. A commit during that write is kept: the flow is dirty again and gets another write
; after its own delay. Storage writes what the request carries, and the requests of one flow keep their order, so the
; file always ends with the newest text that was sent (a rename of the manager that overlaps a patch is covered this way,
; F-0163). A write that fails is reported once (a0 and the storage notice) and retried after a pause that doubles up to
; RETRY_MAX_MS; the flow stays unsaved until a write succeeds.
;
; cmd.flow.save (Save) sends the flow now and answers when storage has written a revision that is at least the one of the
; request. A flow whose deletion starts is forgotten (Forget): no automatic write may create its file again (E0066).
;
; Backups (E0065): the engine asks storage for a backup at the first write of an editing session (a patch with a new
; `session` ID, not a view patch) and then at most every BACKUP_EVERY_MS per flow. A write without a backup request
; follows the same interval. BackupDue and Backed serve the writes of the manager, which follow the interval too.
;
; At shutdown FlushAll sends the flows that are still dirty, without waiting for the answers: the frames leave before
; sys.bye and storage writes its queue empty before it ends (ARCHITECTURE 6.3).
class FlowSaver {
    static DELAY_MS := 3000
    static MAX_DELAY_MS := 10000
    static BACKUP_EVERY_MS := 600000
    static RETRY_MIN_MS := 1000
    static RETRY_MAX_MS := 30000
    static TIMEOUT_MS := 30000

    __New(engine, delayMs := 3000, maxDelayMs := 10000, backupEveryMs := 600000) {
        this._engine := engine
        this._delayMs := delayMs
        this._maxDelayMs := maxDelayMs
        this._backupEveryMs := backupEveryMs
        this._dirty := Map()        ; flow ID -> entry (see _NewEntry); a flow without entry is saved
        this._sess := Map()         ; flow ID -> Map(session, pending, backed, backedAt): the backup state of the flow
        this._closing := false
        this._runFn := () => this._Run()
    }

    ; Number of flows with a revision that is not written yet.
    Pending => this._dirty.Count

    ; True when the flow has a revision that is not written yet (or a write or a save that waits).
    IsDirty(flowId) => this._dirty.Has(flowId)

    ; A patch or a rename committed a new revision of the flow. session is the editor session of a patch (may be ""),
    ; view is true for a patch that changes the view only (it never asks for a backup).
    NoteCommit(flowId, session := "", view := false) {
        if (this._closing)
            return
        now := Time.NowMs()
        if (!view && session != "") {
            s := this._SessionOf(flowId)
            if (s["session"] != session) {
                s["session"] := session
                s["pending"] := true
            }
        }
        if (!this._dirty.Has(flowId))
            this._dirty[flowId] := FlowSaver._NewEntry()
        entry := this._dirty[flowId]
        if (entry["firstAt"] = 0)
            entry["firstAt"] := now
        entry["lastAt"] := now
        this._Schedule()
    }

    ; cmd.flow.save: the flow is written now. The request is answered when storage has written the revision that is
    ; committed at this moment (or a newer one). Returns nothing; the answer goes through the peer.
    Save(flowId, request, rev) {
        if (!this._dirty.Has(flowId))
            this._dirty[flowId] := FlowSaver._NewEntry()
        entry := this._dirty[flowId]
        entry["waiters"].Push(Map("request", request, "rev", rev))
        entry["retryAt"] := 0
        this._Schedule()
    }

    ; The flow is being deleted: its automatic write is dropped, and a save that waits gets busy. A write that is in
    ; flight is ahead of the delete in storage and its answer is ignored.
    Forget(flowId) {
        if (this._dirty.Has(flowId)) {
            entry := this._dirty[flowId]
            this._dirty.Delete(flowId)
            for w in entry["waiters"]
                this._Reply(w["request"], Map("ok", false, "error", Map("code", ErrCode.BUSY
                    , "message", "flow '" flowId "' is being deleted")))
        }
        if (this._sess.Has(flowId))
            this._sess.Delete(flowId)
    }

    ; True if a write of the flow (from the manager) should ask for a backup now (the interval of 10 minutes has passed,
    ; or no backup of this flow was made since the engine started).
    BackupDue(flowId) {
        s := this._SessionOf(flowId)
        return !s["backed"] || Time.NowMs() - s["backedAt"] >= this._backupEveryMs
    }

    ; A write with the backup flag was acknowledged (the manager's writes; the saver calls it itself).
    Backed(flowId, backup) {
        if (!backup)
            return
        s := this._SessionOf(flowId)
        s["backed"] := true
        s["backedAt"] := Time.NowMs()
    }

    ; sys.shutdown: sends every dirty flow, with the rest of the deadline as the limit of each request. Returns how many
    ; were sent; the ones that could not leave are counted in the log.
    FlushAll(deadlineMs) {
        this._closing := true
        SetTimer(this._runFn, 0)
        timeoutMs := Max(500, Integer(deadlineMs))
        flowIds := []
        for flowId in this._dirty
            flowIds.Push(flowId)
        sent := 0
        lost := 0
        for flowId in flowIds {
            if (this._Send(flowId, timeoutMs))
                sent += 1
            else
                lost += 1
        }
        if (lost > 0)
            this._engine._Log("a0", "engine", "shutdown: " lost " of " (sent + lost) " unsaved flow(s) not written (storage refused the requests)")
        return sent
    }

    ; --- internals ---------------------------------------------------------------------------------------------

    static _NewEntry() => Map("firstAt", 0, "lastAt", 0, "retryAt", 0, "retries", 0, "inflight", false
        , "reported", false, "waiters", [])

    static _IsTrue(v) => (v == Json.True || (!IsObject(v) && (v = 1 || v = "true")))

    ; True if every operation of a patch is a view change (`flow.settings` with `view` true). A patch without operations
    ; is not a view patch.
    static IsViewPatch(ops) {
        if (!(ops is Array) || ops.Length = 0)
            return false
        for op in ops {
            if (!(op is Map) || op.Get("op", "") != "flow.settings" || !FlowSaver._IsTrue(op.Get("view", 0)))
                return false
        }
        return true
    }

    _SessionOf(flowId) {
        if (!this._sess.Has(flowId))
            this._sess[flowId] := Map("session", "", "pending", false, "backed", false, "backedAt", 0)
        return this._sess[flowId]
    }

    ; The time at which the entry is due (Time.NowMs() value); 0 means now.
    _DueAt(entry) {
        if (entry["waiters"].Length > 0)
            return 0
        if (entry["retryAt"] > 0)
            return entry["retryAt"]
        if (entry["firstAt"] = 0)
            return 0
        return Min(entry["lastAt"] + this._delayMs, entry["firstAt"] + this._maxDelayMs)
    }

    ; One timer for all flows: it runs when the earliest entry that is not in flight is due. SetTimer replaces the
    ; timer that is set, so an urgent save moves the run forward.
    _Schedule() {
        if (this._closing)
            return
        due := ""
        for _, entry in this._dirty {
            if (entry["inflight"])
                continue
            at := this._DueAt(entry)
            if (due = "" || at < due)
                due := at
        }
        if (due = "") {
            SetTimer(this._runFn, 0)
            return
        }
        now := Time.NowMs()
        wait := (due <= now) ? 1 : Max(1, Integer(due - now) + 1)
        SetTimer(this._runFn, -wait)
    }

    _Run() {
        if (this._closing)
            return
        try {
            now := Time.NowMs()
            due := []
            for flowId, entry in this._dirty {
                if (!entry["inflight"] && this._DueAt(entry) <= now)
                    due.Push(flowId)
            }
            for flowId in due          ; not while the Map is enumerated
                this._Send(flowId, FlowSaver.TIMEOUT_MS)
        } catch as e {
            this._engine._Log("a0", "engine", "saving flows failed: " Type(e) ": " e.Message)
        }
        this._Schedule()
    }

    ; Sends the committed revision of the flow as it is now. Returns true if a request left.
    _Send(flowId, timeoutMs) {
        entry := this._dirty[flowId]
        rec := this._engine.flows.Get(flowId)
        if (!IsObject(rec)) {
            ; the flow is gone (not by a delete through Forget): nothing to write
            this._dirty.Delete(flowId)
            for w in entry["waiters"]
                this._Reply(w["request"], Map("ok", false, "error", Map("code", ErrCode.NOT_FOUND
                    , "message", "flow '" flowId "' is not loaded any more")))
            return false
        }
        s := this._SessionOf(flowId)
        backup := s["pending"] || !s["backed"] || Time.NowMs() - s["backedAt"] >= this._backupEveryMs
        savedRev := rec.Rev
        path := "Flows/" flowId ".json"
        try {
            text := rec.Def.ToFileText()
            entry["inflight"] := true
            entry["firstAt"] := 0          ; the commits so far go with this write
            entry["retryAt"] := 0
            if (backup)
                s["pending"] := false      ; a failed backup asks again (_Failed)
            this._engine.peer.Request(Engine.STORAGE, "cmd.storage.flow.write"
                , Map("path", path, "text", text, "backup", backup ? Json.True : Json.False)
                , ObjBindMethod(this, "_OnAnswer", flowId, entry, savedRev, backup), timeoutMs)
            return true
        } catch as e {
            entry["inflight"] := false
            if (backup)
                s["pending"] := true
            this._Failed(flowId, entry, Map("code", ErrCode.INTERNAL, "message", Type(e) ": " e.Message))
            return false
        }
    }

    _OnAnswer(flowId, entry, savedRev, backup, res) {
        entry["inflight"] := false
        ; a flow that was forgotten (deleted) or replaced by a newer entry: this answer changes nothing
        if (!(this._dirty.Has(flowId) && this._dirty[flowId] == entry))
            return
        if (res.payload.Get("ok", false)) {
            if (backup)
                this.Backed(flowId, true)
            if (entry["reported"]) {
                entry["reported"] := false
                this._engine._Log("a1", "engine", "flow '" flowId "' written after an earlier failure")
            }
            entry["retries"] := 0
            this._engine.Emit("topic:flow:" flowId, "evt.flow.saved", Map("flowId", flowId, "savedRev", savedRev))
            this._ResolveWaiters(entry, savedRev)
            rec := this._engine.flows.Get(flowId)
            if (!IsObject(rec) || rec.Rev <= savedRev)
                this._dirty.Delete(flowId)
            this._Schedule()
            return
        }
        err := res.payload.Get("error", "")
        if (backup)
            this._SessionOf(flowId)["pending"] := true
        this._Failed(flowId, entry, (err is Map) ? err
            : Map("code", ErrCode.INTERNAL, "message", "storage did not write the flow"))
    }

    ; Answers the saves that waited for a revision up to savedRev.
    _ResolveWaiters(entry, savedRev) {
        rest := []
        for w in entry["waiters"] {
            if (w["rev"] <= savedRev)
                this._Reply(w["request"], Map("savedRev", savedRev))
            else
                rest.Push(w)
        }
        entry["waiters"] := rest
    }

    ; A write failed: the first failure of a series is reported, the flow is retried after a pause that grows.
    _Failed(flowId, entry, err) {
        if (!entry["reported"]) {
            entry["reported"] := true
            text := String(err.Get("code", "")) ": " String(err.Get("message", ""))
            this._engine._StorageError("flow.write", "Flows/" flowId ".json", text)
        }
        pause := Min(FlowSaver.RETRY_MAX_MS, FlowSaver.RETRY_MIN_MS * (2 ** Min(entry["retries"], 5)))
        entry["retries"] += 1
        entry["retryAt"] := Time.NowMs() + pause
        waiters := entry["waiters"]
        entry["waiters"] := []
        for w in waiters
            this._Reply(w["request"], Map("ok", false, "error", err))
        this._Schedule()
    }

    _Reply(request, payload) {
        try {
            this._engine.peer.Reply(request, payload)
        } catch as e {
            this._engine._Log("a0", "engine", "answering a save failed: " Type(e) ": " e.Message)
        }
    }
}
