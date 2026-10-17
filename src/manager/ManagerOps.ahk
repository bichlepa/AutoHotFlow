#Requires AutoHotkey v2.0
#Include ..\core\Json.ahk
#Include ..\core\Lang.ahk

; The operations of the manager on flows and categories (WI-0074; PROTOCOL 4.2 and the lifecycle and category paragraphs).
; Every operation sends commands to the engine through ManagerModel.Command (with its timeout). The questions of the
; operations go through the seam `ask`, which is the window (ManagerWindow, UiDialogs) or, headless, the test driver:
;
;   ask.Confirm(kind, args, done)          done(true|false)
;   ask.Input(kind, default, check, done)  done(text), "" for Cancel; check(text) returns "" or the error text
;   ask.Choose(kind, items, done)          items: Array of [id, label] with integer IDs; done(id), 0 for Cancel
;
; The kinds: "independent" (E0056), "force" (E0063), "delete" (E0066), "categoryDelete", "categoryMove", "rename",
; "categoryNew", "categoryRename". Every operation calls done(answer) exactly once: the answer of the last command
; (Map from ManagerModel._Answered), or "" when nothing was sent (a question was answered no, or no flow matched).
; The operations run in a chain: one command after the other, so that the engine does not answer busy.
class ManagerOps {
    __New(model) {
        this.m := model
        this.ask := ""           ; the seam, set by the owner of the operations
    }

    ; --- names (the rules of the engine, checked before the command, so the dialog shows them) -----------------------------

    ; "" when the name of a flow is accepted, else the text of the reason. taken: the other names (ignoring case).
    static NameProblem(name, taken) {
        if (name = "" || Trim(name) = "")
            return Lang("Name_empty")
        if (InStr(name, "|"))
            return Lang("Name_bar")
        for other in taken {
            if (StrLower(other) = StrLower(name))
                return Lang("Name_taken")
        }
        return ""
    }

    ; The same for a category, which also may not be named Uncategorized (the uncategorized group).
    static CategoryProblem(name, taken) {
        if (StrLower(name) = "uncategorized")
            return Lang("Name_reserved")
        return ManagerOps.NameProblem(name, taken)
    }

    ; --- switches (E0056, E0063) ----------------------------------------------------------------------------------------

    ; Enables or disables flows, one after the other. A flow that is inactive while independent triggers are enabled is asked
    ; first: "yes" disables them too (all), "no" leaves the flow as it is. A switch that the engine refuses because the state
    ; of the flow cannot be read is asked once more: "yes" writes the state of the session (force), "no" changes nothing.
    SetEnabled(flowIds, enable, done := "") {
        this._SwitchNext(this._Known(flowIds), 1, enable, "", done)
    }

    _SwitchNext(ids, i, enable, last, done) {
        if (i > ids.Length) {
            ManagerOps._Done(done, last)
            return
        }
        id := ids[i]
        rec := this.m.Flow(id)
        next := (ans) => this._SwitchNext(ids, i + 1, enable, ans, done)
        if (rec = "") {                      ; removed meanwhile (a resync while a question was open)
            next(last)
            return
        }
        if (!enable && !rec["enabled"] && rec["independentActive"] > 0) {
            this._Confirm("independent", [rec["name"], rec["independentActive"]]
                , (yes) => (yes ? this._SwitchOne(id, false, true, next) : next(last)))
            return
        }
        this._SwitchOne(id, enable, false, next)
    }

    _SwitchOne(id, enable, all, next, forced := false) {
        payload := Map("flowId", id)
        if (all)
            payload["all"] := Json.True
        if (forced)
            payload["force"] := Json.True
        type := enable ? "cmd.flow.enable" : "cmd.flow.disable"
        ; The watch starts before the command: the trigger host's message can come before the answer of the engine.
        if (enable)
            this.m.WatchPackages(id)
        this.m.Command(type, payload, (ans) => this._AfterSwitch(id, enable, all, forced, ans, next))
    }

    _AfterSwitch(id, enable, all, forced, ans, next) {
        if (enable && !ans["ok"])
            this.m.UnwatchPackages(id)
        if (!forced && !ans["ok"] && InStr(ans["message"], "cannot be read (")) {
            this._Confirm("force", [this.m.Flow(id) = "" ? id : this.m.Flow(id)["name"]]
                , (yes) => (yes ? this._SwitchOne(id, enable, all, next, true) : next(ans)))
            return
        }
        next(ans)
    }

    ; --- flows: new, duplicate, delete, rename, move (E0066, E0067) -------------------------------------------------

    ; A new flow in the category ("" = Uncategorized); the engine picks the name (New flow <n>).
    NewFlow(category, done := "") {
        this.m.Command("cmd.flow.create", Map("category", category), done)
    }

    Duplicate(flowId, done := "") {
        if (this.m.Flow(flowId) = "") {
            ManagerOps._Done(done, "")
            return
        }
        this.m.Command("cmd.flow.duplicate", Map("flowId", flowId), done)
    }

    ; Deletes flows, each after its own confirmation (final, E0066).
    Delete(flowIds, done := "") {
        this._DeleteNext(this._Known(flowIds), 1, "", done)
    }

    _DeleteNext(ids, i, last, done) {
        if (i > ids.Length) {
            ManagerOps._Done(done, last)
            return
        }
        id := ids[i]
        if (this.m.Flow(id) = "") {          ; removed meanwhile (a resync while a question was open)
            this._DeleteNext(ids, i + 1, last, done)
            return
        }
        this._Confirm("delete", [this.m.Flow(id)["name"]], (yes) => (yes
            ? this.m.Command("cmd.flow.delete", Map("flowId", id), (ans) => this._DeleteNext(ids, i + 1, ans, done))
            : this._DeleteNext(ids, i + 1, last, done)))
    }

    ; Rename with the dialog: the name is checked here first (the rules of the engine); the engine checks it again.
    Rename(flowId, done := "") {
        rec := this.m.Flow(flowId)
        if (rec = "") {
            ManagerOps._Done(done, "")
            return
        }
        taken := this.m.FlowNames(flowId)
        this._Input("rename", rec["name"], (v) => ManagerOps.NameProblem(v, taken)
            , (value) => (value = "" ? ManagerOps._Done(done, "") : this.RenameTo(flowId, value, done)))
    }

    ; The name as given (no dialog): the engine checks it and answers bad_payload with the reason.
    RenameTo(flowId, name, done := "") {
        this.m.Command("cmd.flow.meta.update", Map("flowId", flowId, "name", name), done)
    }

    ; Moves flows into a category ("" = Uncategorized), before the flow beforeId ("" = at the end). Per moved flow one
    ; meta update (its category), then one cmd.category.order with the new order of the target and of every category the
    ; flows came from (E0067: a flow moved into a category is appended by the engine, then the order is set).
    Move(flowIds, target, beforeId := "", done := "") {
        ids := []
        for id in this._Known(flowIds) {
            if (id != beforeId)
                ids.Push(id)
        }
        if (ids.Length = 0) {
            ManagerOps._Done(done, "")
            return
        }
        moved := Map()
        for id in ids
            moved[id] := true
        order := this.m.CategoryOrderMap()
        newTarget := []
        placed := false
        for id in (order.Has(target) ? order[target] : []) {
            if (moved.Has(id))
                continue
            if (beforeId != "" && id = beforeId && !placed) {
                for mid in ids
                    newTarget.Push(mid)
                placed := true
            }
            newTarget.Push(id)
        }
        if (!placed) {
            for mid in ids
                newTarget.Push(mid)
        }
        flows := Map()
        flows[target] := newTarget
        updates := []
        for id in ids {
            src := this.m.Flow(id)["category"]
            if (src != target)
                updates.Push(id)
            if (src != target && !flows.Has(src)) {
                rest := []
                for x in (order.Has(src) ? order[src] : []) {
                    if (!moved.Has(x))
                        rest.Push(x)
                }
                flows[src] := rest
            }
        }
        this._MetaNext(updates, 1, target, flows, done)
    }

    _MetaNext(updates, i, target, flows, done) {
        if (i > updates.Length) {
            this.m.Command("cmd.category.order", Map("flows", flows), done)
            return
        }
        this.m.Command("cmd.flow.meta.update", Map("flowId", updates[i], "category", target), (ans) => (ans["ok"]
            ? this._MetaNext(updates, i + 1, target, flows, done) : ManagerOps._Done(done, ans)))
    }

    ; --- categories (E0067) -----------------------------------------------------------------------------------------

    CategoryNew(done := "") {
        taken := this.m.CategoryNames()
        this._Input("categoryNew", "", (v) => ManagerOps.CategoryProblem(v, taken)
            , (value) => (value = "" ? ManagerOps._Done(done, "")
            : this.m.Command("cmd.category.create", Map("name", value), done)))
    }

    CategoryRename(name, done := "") {
        taken := []
        for c in this.m.CategoryNames() {
            if (c != name)
                taken.Push(c)
        }
        this._Input("categoryRename", name, (v) => ManagerOps.CategoryProblem(v, taken)
            , (value) => (value = "" ? ManagerOps._Done(done, "")
            : this.m.Command("cmd.category.rename", Map("name", name, "newName", value), done)))
    }

    ; Deletes a category after a confirmation. Its flows move to the category the user chooses first (cmd.category.delete).
    CategoryDelete(name, done := "") {
        this._Confirm("categoryDelete", [name], (yes) => (yes ? this._CategoryDeleteMove(name, done)
            : ManagerOps._Done(done, "")))
    }

    _CategoryDeleteMove(name, done) {
        counts := this.m.CategoryOrderMap()
        if (!counts.Has(name)) {
            this.m.Command("cmd.category.delete", Map("name", name, "moveTo", ""), done)
            return
        }
        targets := [""]
        for c in this.m.CategoryNames() {
            if (c != name)
                targets.Push(c)
        }
        items := []
        for i, t in targets
            items.Push([i, t = "" ? Lang("Uncategorized") : t])
        this._Choose("categoryMove", items, (idx) => (idx >= 1 && idx <= targets.Length
            ? this.m.Command("cmd.category.delete", Map("name", name, "moveTo", targets[idx]), done)
            : ManagerOps._Done(done, "")))
    }

    CategorySort(done := "") {
        this.m.Command("cmd.category.sort", Map(), done)
    }

    ; Puts the category before the category beforeName ("" = at the end, after the last category).
    CategoryMove(name, beforeName := "", done := "") {
        if (name = beforeName) {
            ManagerOps._Done(done, "")
            return
        }
        out := []
        for c in this.m.CategoryNames() {
            if (c != name)
                out.Push(c)
        }
        at := out.Length + 1
        if (beforeName != "") {
            for i, c in out {
                if (c = beforeName) {
                    at := i
                    break
                }
            }
        }
        out.InsertAt(at, name)
        this.m.Command("cmd.category.order", Map("categories", out), done)
    }

    ; --- helpers ------------------------------------------------------------------------------------------------------

    ; The known flows of a list, each once, in the given order.
    _Known(flowIds) {
        out := []
        seen := Map()
        for id in flowIds {
            if (!seen.Has(id) && this.m.flows.Has(id)) {
                seen[id] := true
                out.Push(id)
            }
        }
        return out
    }

    _Confirm(kind, args, done) {
        if (!IsObject(this.ask)) {
            done(false)
            return
        }
        this.ask.Confirm(kind, args, done)
    }

    _Input(kind, default, check, done) {
        if (!IsObject(this.ask)) {
            done("")
            return
        }
        this.ask.Input(kind, default, check, done)
    }

    _Choose(kind, items, done) {
        if (!IsObject(this.ask)) {
            done(0)
            return
        }
        this.ask.Choose(kind, items, done)
    }

    static _Done(done, answer) {
        if (IsObject(done))
            done(answer)
    }
}
