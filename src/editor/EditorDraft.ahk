#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Lang.ahk
#Include ..\core\FlowPatch.ahk
#Include EditorView.ahk

; The draft of the flow in the editor (WI-0096, PROTOCOL 4.11, ARCHITECTURE 4.2): the committed definition of the engine plus
; the operations that the engine has not answered yet (the queue), the undo and redo steps and the selection. The editor
; changes its flow only through this class: Commit sends a patch (cmd.flow.patch), Undo and Redo send the inverse or the
; operations of a step, the view is written as flowSettings (not an undo step, E0086).
;
; Patch client (PROTOCOL 4.2): one patch is in flight; the others wait in the queue. ok takes the new rev. conflict: the
; queued operations are applied again on the definition of the answer and the head is sent once more (a second conflict,
; or an operation that no longer applies, refuses the queue). A refused operation (bad_payload) drops the queue, clears
; the undo stack, shows a text in the status bar and asks the engine for the definition. timeout or peer_gone: the outcome
; is unknown, so the queue and the stacks go and the engine's saved state is asked for (decision, WI-0096).
; An answer that comes while a patch is in flight (a definition from a resync) waits until the patch is answered.
;
; The model (EditorModel) gives: DraftChanged(kind) (the scene is built again), Resync(reason), Schedule(ms, fn),
; and the session (property session). Pure data otherwise: no window, no timer of its own.
class EditorDraft {
    static UNDO_MAX := 100
    static PATCH_MS := 5000
    static RETRY_MS := 1000
    static VIEW_EPSILON := 0.000001
    static SELECT_MODES := Map("one", 1, "toggle", 1, "all", 1, "none", 1)

    __New(peer, flowId, model) {
        this.peer := peer
        this.flowId := flowId
        this.model := model
        this.committed := ""     ; the definition of the engine's last answer (a Map), "" before the first
        this.rev := -1           ; the revision of committed
        this.root := ""          ; the draft: committed plus the queue (the scene is built from it)
        this.queue := []         ; Map("ops", ops, "done", fn or "", "conflicts", n); the first is in flight while inFlight
        this.inFlight := false
        this.deferred := ""      ; Map("definition", def, "rev", rev): an answer of a resync that came while a patch was in flight
        this.undoSteps := []          ; Map("ops", ops, "inv", inverse) of each step; the last one is the newest
        this.redoSteps := []
        this.selection := Map()  ; element or connection ID -> true (a new Map on every change, never changed in place)
        this.message := ""       ; the text of the status bar after a refusal, "" for none
    }

    ; --- the committed definition --------------------------------------------------------------------------------------

    ; The definition of the engine (cmd.flow.get) arrived. While a patch is in flight it waits until that patch is answered.
    Accept(definition, rev) {
        if (this.inFlight) {
            this.deferred := Map("definition", definition, "rev", rev)
            return
        }
        this._Base(definition, rev)
    }

    _Base(definition, rev) {
        this.committed := definition
        this.rev := rev
        if (this._Rebuild())
            this._Send()
    }

    ; The draft is the committed definition with the queue applied. A queued operation that does not apply any more refuses
    ; the queue (returns false then).
    _Rebuild() {
        root := this.committed
        for item in this.queue {
            try {
                root := FlowPatch.Apply(root, item["ops"])
            } catch as e {
                this._Refuse("Status change refused", true)
                return false
            }
        }
        this.root := root
        this._Prune()
        this.model.DraftChanged("flow")
        return true
    }

    ; A new epoch (the engine restarted): the queue and both stacks go; the saved state comes with the next definition.
    NewEpoch() {
        this._DropQueue()
        this.undoSteps := []
        this.redoSteps := []
        this.deferred := ""
        this.message := ""
    }

    ; An evt.flow.committed with this rev is the echo of the patch in flight (its answer follows): not a reason to ask again.
    OwnCommit(rev) => this.inFlight && this.queue.Length > 0 && rev = this.rev + 1

    ; --- edits -----------------------------------------------------------------------------------------------------------

    ; Applies ops to the draft and queues them for the engine. undoable: the change is an undo step (a new step clears the
    ; redo steps). done(ok) is called when the engine answered (or the queue went). Returns Map("ok", bool, "code", ..., "message").
    Commit(ops, undoable := true, done := "") {
        if (!(this.root is Map))
            return Map("ok", false, "code", ErrCode.BUSY, "message", "the flow is not loaded yet")
        try {
            root := FlowPatch.Apply(this.root, ops)
        } catch as e {
            return Map("ok", false, "code", ErrCode.BAD_PAYLOAD, "message", e.Message)
        }
        if (undoable) {
            this.undoSteps.Push(Map("ops", ops, "inv", FlowPatch.Diff(root, this.root)))
            if (this.undoSteps.Length > EditorDraft.UNDO_MAX)
                this.undoSteps.RemoveAt(1)
            this.redoSteps := []
        }
        this.root := root
        this._Prune()
        this.message := ""
        this.queue.Push(Map("ops", ops, "done", done, "conflicts", 0))
        this._Send()
        this.model.DraftChanged("flow")
        return Map("ok", true)
    }

    ; The step on top of the undo stack is undone: its inverse goes out as a patch that is no undo step. A step whose
    ; inverse no longer applies stays where it is, and the status bar says so.
    Undo() => this._Walk(this.undoSteps, this.redoSteps, "inv", "Status undo refused")

    Redo() => this._Walk(this.redoSteps, this.undoSteps, "ops", "Status redo refused")

    _Walk(from, to, key, refusedKey) {
        if (from.Length = 0)
            return Map("ok", true, "done", false)
        step := from[from.Length]
        res := this.Commit(step[key], false)
        if (!res["ok"]) {
            this.message := Lang(refusedKey)
            this.model.DraftChanged("flow")
            return Map("ok", false, "done", false, "message", res["message"])
        }
        from.Pop()
        to.Push(step)
        return Map("ok", true, "done", true)
    }

    ; The view (zoom, offset) is written as flowSettings (E0086, PROTOCOL 4.2 flow.settings with view). It is not an undo
    ; step. Nothing is sent when the flow settings already have this view. done(ok) is called at once or when answered.
    SaveView(view, done := "") {
        if (!(this.root is Map)) {
            EditorDraft._Call(done, false)
            return
        }
        saved := EditorView.FromFlowSettings(this.root.Get("flowSettings", ""))
        eps := EditorDraft.VIEW_EPSILON
        if (Abs(saved.Zoom - view.Zoom) < eps && Abs(saved.OffsetX - view.OffsetX) < eps
                && Abs(saved.OffsetY - view.OffsetY) < eps) {
            EditorDraft._Call(done, true)
            return
        }
        settings := Map("zoomFactor", Format("{:f}", view.Zoom), "Offsetx", Format("{:f}", view.OffsetX)
            , "Offsety", Format("{:f}", view.OffsetY))
        ops := [Map("op", "flow.settings", "settings", settings, "view", Json.True)]
        res := this.Commit(ops, false, done)
        if (!res["ok"])
            EditorDraft._Call(done, false)
    }

    ; --- selection -------------------------------------------------------------------------------------------------------

    ; one: the IDs given are the selection; toggle: each given ID flips; all: every element and connection; none: nothing.
    ; An ID that the flow does not have is left out.
    SetSelection(ids, mode) {
        sel := Map()
        if (mode = "all") {
            for id in this._Ids("allElements")
                sel[id] := true
            for id in this._Ids("allConnections")
                sel[id] := true
        } else if (mode = "toggle") {
            sel := this.selection.Clone()
            for id in ids {
                if (sel.Has(id))
                    sel.Delete(id)
                else if (this._Exists(id))
                    sel[id] := true
            }
        } else if (mode = "one") {
            for id in ids {
                if (this._Exists(id))
                    sel[id] := true
            }
        }
        this.selection := sel
    }

    ; The selection without the IDs that the flow no longer has (a removed element or connection).
    _Prune() {
        if (this.selection.Count = 0)
            return
        sel := Map()
        for id in this.selection {
            if (this._Exists(id))
                sel[id] := true
        }
        this.selection := sel
    }

    _Exists(id) => (this.root is Map) && (this.root.Get("allElements", Map()).Has(id)
        || this.root.Get("allConnections", Map()).Has(id))

    ; The ID of a new element or connection (kind "element" or "connection"): the draft's ElementIDCounter is the next
    ; free number (as v1 writes it; FlowPatch raises it when an element is added), so the ID is that number, or the first
    ; one above it that the flow still uses. The v1 format: element0000000010. Two IDs taken before a commit are the same:
    ; take one, and commit it at once.
    NextId(kind) {
        n := (this.root is Map) ? this.root.Get("ElementIDCounter", 1) + 0 : 1
        loop {
            id := kind Format("{:010}", n)
            if (!this._Exists(id))
                return id
            n += 1
        }
    }

    _Ids(key) {
        ids := []
        if (this.root is Map)
            for id in this.root.Get(key, Map())
                ids.Push(id)
        return ids
    }

    ; --- the patch client ------------------------------------------------------------------------------------------------

    _Send() {
        if (this.inFlight || this.queue.Length = 0 || !(this.committed is Map))
            return
        this.inFlight := true
        this._Request(this.queue[1])
    }

    _Request(item) {
        payload := Map("flowId", this.flowId, "baseRev", this.rev, "ops", item["ops"], "session", this.model.session)
        try {
            this.peer.Request("engine", "cmd.flow.patch", payload, (ans) => this._OnAnswer(item, ans), EditorDraft.PATCH_MS)
        } catch as e {
            this._Lost("the request could not be sent: " e.Message)
        }
    }

    ; Sends the head again later (the engine was busy: a flow whose deletion is pending).
    _Retry(item) {
        this.model.Schedule(EditorDraft.RETRY_MS, () => this._RetryNow(item))
    }

    _RetryNow(item) {
        if (this.queue.Length > 0 && ObjPtr(this.queue[1]) = ObjPtr(item))
            this._Request(item)
    }

    _OnAnswer(item, ans) {
        if (this.queue.Length = 0 || ObjPtr(this.queue[1]) != ObjPtr(item))
            return                          ; the queue was dropped since (a reset, a refusal): this answer is old
        p := ans.payload
        if (p.Get("ok", 0)) {
            this._Acked(item, p.Get("rev", this.rev + 1))
            return
        }
        code := EditorDraft._Code(p)
        if (code = "conflict")
            this._Conflict(item, p)
        else if (code = "busy")
            this._Retry(item)
        else if (code = "timeout" || code = "peer_gone")
            this._Lost("patch " code)
        else
            this._Refuse("Status change refused", true)
    }

    ; The engine applied the head: its rev is the new one; the committed definition gets the same operations.
    _Acked(item, rev) {
        this.rev := rev
        this.queue.RemoveAt(1)
        this.inFlight := false
        try {
            this.committed := FlowPatch.Apply(this.committed, item["ops"])
        } catch as e {
            this._Refuse("Status change refused", true)
            return
        }
        EditorDraft._Call(item["done"], true)
        if (this.deferred != "") {
            d := this.deferred
            this.deferred := ""
            if (d["rev"] >= this.rev) {
                this._Base(d["definition"], d["rev"])     ; the answer includes the patch (or is newer)
                return
            }
        }
        this._Send()
    }

    ; The engine changed the flow meanwhile: its definition is the base; the head goes out again (once).
    _Conflict(item, p) {
        definition := p.Get("definition", "")
        item["conflicts"] := item["conflicts"] + 1
        if (!(definition is Map) || item["conflicts"] > 1) {
            this._Refuse("Status change refused", true)
            return
        }
        this.committed := definition
        this.rev := p.Get("rev", this.rev)
        if (this._Rebuild())
            this._Request(item)
    }

    ; The engine refused the change or the state is lost: the queue and the stacks go, the engine's state is asked for.
    _Refuse(textKey, resync) {
        this._DropQueue()
        this.undoSteps := []
        this.redoSteps := []
        this.deferred := ""
        this.message := Lang(textKey)
        this.root := this.committed
        this._Prune()
        this.model.DraftChanged("flow")
        if (resync)
            this.model.Resync("patch refused")
    }

    _Lost(why) {
        this._DropQueue()
        this.undoSteps := []
        this.redoSteps := []
        this.deferred := ""
        this.message := Lang("Status change lost")
        this.root := this.committed
        this._Prune()
        this.model.DraftChanged("flow")
        this.model.Resync("patch lost: " why)
    }

    ; Drops the queue; the callbacks of its patches get false.
    _DropQueue() {
        items := this.queue
        this.queue := []
        this.inFlight := false
        for item in items
            EditorDraft._Call(item["done"], false)
    }

    ; --- helpers ---------------------------------------------------------------------------------------------------------

    static _Call(fn, value) {
        if (IsObject(fn))
            fn(value)
    }

    ; The code of a refused answer ("conflict", "busy", "timeout", ...), "?" when there is none.
    static _Code(payload) {
        if (payload.Has("error") && IsObject(payload["error"]))
            return payload["error"].Get("code", "?")
        return "?"
    }
}
