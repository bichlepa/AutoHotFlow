#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\ErrCode.ahk
#Include ..\core\Json.ahk
#Include ..\core\Lang.ahk
#Include ManagerModel.ahk

; The import of the flows and variables of AutoHotFlow v1 (WI-0076, REQ-MIG-060, E0068, PROTOCOL 4.8 "Import from v1").
; The manager runs one chain, one request after the other; the v1 folder is only read (storage, cmd.storage.v1.*), the
; flows are created by the engine (cmd.flow.create with the ID of the v1 file, numberName for a copy), the variables are
; handed to the engine (cmd.import.v1.vars). The questions go through the seam `ask` (ManagerWindow or the test driver):
;   ask.Confirm("importCopies", [count], done)   yes: the flows whose ID exists in v2 are imported as copies
;   ask.Confirm("autostartV1", [], done)        yes: the shortcut of v1 in the startup folder is removed (preselection no)
;
; The result (Map, see Text) is a report: per flow created, copy, skipped (with the reason) or failed (with the message), the
; MIGRATION places the engine marked, the variables taken over, kept or failed, and the autostart step. A file that cannot be
; parsed is listed, the others go on. A request that fails is listed as well; only a failed listing of the folder ends the
; import at once.
class ManagerImport {
    static STORAGE_MS := 30000
    ; A create writes a flow file (and a category list) in storage: longer than a click (ManagerModel.COMMAND_MS, 5 s).
    static WRITE_MS := 30000

    __New(model) {
        this.m := model
        this.ask := ""          ; the seam of the questions (Confirm)
        this.log := ""         ; fn(level, text): the log of the role
        this.running := false
    }

    ; Starts the import of the v1 folder dir. startupDir is the startup folder of the autostart step; "" leaves that step out
    ; (the tests: a test never touches the real startup folder). done(result) runs once, when the import is over.
    Start(dir, startupDir, done) {
        if (this.running) {
            ManagerImport._Done(done, Map("ok", 0, "error", Lang("Import_busy")))
            return
        }
        this.running := true
        this.dir := dir
        this.startupDir := startupDir
        this.done := done
        this.copies := false
        this.names := []
        this.varList := []
        this.idOf := Map()                  ; v1 flow name -> flow ID of the created flow
        this.cats := Map()                  ; category names of v2 (ignoring case), the import adds the missing ones
        this.cats.CaseSense := "Off"
        for c in this.m.CategoryNames()
            this.cats[c] := true
        this.pending := []                  ; variables read, not yet handed to the engine
        this.res := Map("ok", 1, "dir", dir, "error", "", "flows", [], "vars", [], "autostart", "none"
            , "autostartError", "", "copies", 0)
        this._Request("cmd.storage.v1.list", Map("dir", dir), (p) => this._Listed(p))
    }

    ; --- the chain -------------------------------------------------------------------------------------------------

    _Listed(p) {
        if (!p.Get("ok", 0))
            return this._Fail(Lang("Import_source_error", ManagerImport._Message(p)))
        this.names := p["flows"]
        this.varList := p["vars"]
        existing := 0
        for name in this.names {
            if (this.m.flows.Has(name))
                existing += 1
        }
        if (existing = 0)
            return this._AfterCopies(false)
        this._Confirm("importCopies", [existing], (yes) => this._AfterCopies(yes))
    }

    _AfterCopies(copies) {
        this.copies := copies ? true : false
        this._Flows(1)
    }

    _Flows(i) {
        if (i > this.names.Length)
            return this._StartVariables()
        name := this.names[i]
        this._Request("cmd.storage.v1.read", Map("dir", this.dir, "kind", "flow", "name", name)
            , (p) => this._Read(i, name, p))
    }

    _Read(i, name, p) {
        if (!p.Get("ok", 0))
            return this._Entry(i, name, "failed", "", ManagerImport._Message(p), [])
        defn := ""
        try {
            defn := Json.Parse(p["text"])
        } catch as e {
            return this._Entry(i, name, "failed", "", Lang("Import_reason_json", e.Message), [])
        }
        if (!(defn is Map))
            return this._Entry(i, name, "failed", "", Lang("Import_reason_not_flow"), [])
        exists := this.m.flows.Has(name)
        if (exists && !this.copies)
            return this._Entry(i, name, "skipped", "", Lang("Import_reason_exists"), [])
        cat := defn.Get("category", "")
        cat := IsObject(cat) ? "" : String(cat)
        if (StrLower(cat) = "uncategorized") {
            defn["category"] := ""
            cat := ""
        }
        if (cat != "" && !this.cats.Has(cat)) {
            ; v1 keeps the category in the flow file; v2 keeps the list of categories, so the import adds the category first
            this.m.Command("cmd.category.create", Map("name", cat), (ans) => this._CategoryAdded(i, name, exists, defn, cat, ans), ManagerImport.WRITE_MS)
            return
        }
        this._Send(i, name, exists, defn)
    }

    _CategoryAdded(i, name, exists, defn, cat, ans) {
        if (ans["ok"])
            this.cats[cat] := true
        this._Send(i, name, exists, defn)     ; a category that could not be added makes the flow fail with its reason
    }

    _Send(i, name, exists, defn) {
        payload := Map("definition", defn)
        if (exists)
            payload["numberName"] := Json.True    ; a copy: a new ID (the engine picks it), the name gets a number
        else
            payload["flowId"] := name             ; the flow keeps the ID of the v1 file
        this.m.Command("cmd.flow.create", payload, (ans) => this._Created(i, name, exists, ans), ManagerImport.WRITE_MS)
    }

    _Created(i, name, copy, ans) {
        if (!ans["ok"]) {
            state := (ans["code"] = ErrCode.CONFLICT || ans["code"] = ErrCode.BAD_PAYLOAD) ? "skipped" : "failed"
            return this._Entry(i, name, state, "", ans["message"], [])
        }
        p := ans["payload"]
        flowId := p.Get("flowId", "")
        this.idOf[name] := flowId
        this._Entry(i, name, copy ? "copy" : "created", flowId, "", p.Get("places", []), p.Get("name", ""))
    }

    ; The variables to read: the static variables of a flow that was not imported are listed as skipped here, so the
    ; chain below only asks storage for variables that are taken over (no synchronous recursion over skipped entries).
    _StartVariables() {
        this.reads := []
        for ref in this.varList {
            if (ref["scope"] = "static" && !this.idOf.Has(ref["flowId"])) {
                this._VarEntry("static", ref["flowId"], ref["name"], "skipped", "")
                continue
            }
            this.reads.Push(ref)
        }
        this._Variables(1)
    }

    _Variables(j) {
        if (j > this.reads.Length)
            return this._SendVariables()
        ref := this.reads[j]
        scope := ref["scope"]
        flowId := ref["flowId"]
        name := ref["name"]
        newId := (scope = "static") ? this.idOf[flowId] : ""
        this._Request("cmd.storage.v1.read", Map("dir", this.dir, "kind", "var", "scope", scope, "flowId", flowId
            , "name", name), (p) => this._VarRead(j, scope, newId, name, p))
    }

    _VarRead(j, scope, newId, name, p) {
        if (!p.Get("ok", 0)) {
            this._VarEntry(scope, newId, name, "failed", ManagerImport._Message(p))
        } else if (p.Get("exists", 0)) {
            this.pending.Push(Map("scope", scope, "flowId", newId, "name", name, "type", p.Get("type", "normal")
                , "content", p.Get("content", "")))
        }
        this._Variables(j + 1)
    }

    _SendVariables() {
        if (this.pending.Length = 0)
            return this._Autostart()
        globals := []
        statics := []
        for v in this.pending {
            item := Map("name", v["name"], "type", v["type"], "content", v["content"])
            if (v["scope"] = "static") {
                item["flowId"] := v["flowId"]
                statics.Push(item)
            } else {
                globals.Push(item)
            }
        }
        this.m.Command("cmd.import.v1.vars", Map("globals", globals, "statics", statics), (ans) => this._VarsDone(ans))
    }

    _VarsDone(ans) {
        if (!ans["ok"]) {
            for v in this.pending
                this._VarEntry(v["scope"], v["flowId"], v["name"], "failed", ans["message"])
        } else {
            p := ans["payload"]
            for item in p.Get("taken", [])
                this._VarEntry(item["scope"], item["flowId"], item["name"], "taken", "")
            for item in p.Get("kept", [])
                this._VarEntry(item["scope"], item["flowId"], item["name"], "kept", "")
            for item in p.Get("failed", [])
                this._VarEntry(item["scope"], item["flowId"], item["name"], "failed", item.Get("message", ""))
        }
        this._Autostart()
    }

    _Autostart() {
        if (this.startupDir = "")
            return this._Finish()
        this._Request("cmd.storage.autostart.check", Map("startupDir", this.startupDir, "v1Dir", this.dir)
            , (p) => this._AutostartChecked(p))
    }

    _AutostartChecked(p) {
        if (!p.Get("ok", 0)) {
            this.res["autostart"] := "error"
            this.res["autostartError"] := ManagerImport._Message(p)
            return this._Finish()
        }
        if (!p.Get("exists", 0)) {
            this.res["autostart"] := "none"
            return this._Finish()
        }
        if (!p.Get("v1", 0)) {
            this.res["autostart"] := "other"
            return this._Finish()
        }
        this._Confirm("autostartV1", [], (yes) => this._AutostartAnswer(yes))
    }

    _AutostartAnswer(yes) {
        if (!yes) {
            this.res["autostart"] := "kept"
            return this._Finish()
        }
        this._Request("cmd.storage.autostart.remove", Map("startupDir", this.startupDir, "v1Dir", this.dir)
            , (p) => this._AutostartRemoved(p))
    }

    _AutostartRemoved(p) {
        if (!p.Get("ok", 0)) {
            this.res["autostart"] := "error"
            this.res["autostartError"] := ManagerImport._Message(p)
        } else {
            this.res["autostart"] := p.Get("removed", 0) ? "removed" : "none"
        }
        this._Finish()
    }

    ; --- results ---------------------------------------------------------------------------------------------------

    ; One flow of the listing is done; the next one follows.
    _Entry(i, name, state, flowId, message, places, newName := "") {
        this.res["flows"].Push(Map("name", name, "state", state, "flowId", flowId, "message", message, "places", places
            , "as", newName))
        this._Flows(i + 1)
    }

    _VarEntry(scope, flowId, name, state, message) {
        this.res["vars"].Push(Map("scope", scope, "flowId", flowId, "name", name, "state", state, "message", message))
    }

    _Fail(text) {
        this.res["ok"] := 0
        this.res["error"] := text
        this._Finish()
    }

    _Finish() {
        this.running := false
        text := ManagerImport.Text(this.res)
        write := this.log              ; a function kept in a property is called through a local (no object argument)
        if (IsObject(write))
            write("a1", text)
        ManagerImport._Done(this.done, this.res)
    }

    ; The report as text, one line per item (the texts are Lang keys, so the report follows the language).
    static Text(res) {
        lines := []
        if (res["error"] != "")
            lines.Push(res["error"])
        counts := Map("created", 0, "copy", 0, "skipped", 0, "failed", 0, "taken", 0, "kept", 0)
        for f in res["flows"] {
            counts[f["state"]] += 1
            name := f["name"]
            switch f["state"] {
                case "created":
                    lines.Push(Lang("Import_flow_created", name, f["flowId"]))
                case "copy":
                    lines.Push(Lang("Import_flow_copy", name, f["flowId"]))
                case "skipped":
                    lines.Push(Lang("Import_flow_skipped", name, f["message"]))
                default:
                    lines.Push(Lang("Import_flow_failed", name, f["message"]))
            }
            for place in f["places"]
                lines.Push(Lang("Import_place", place["element"], place["par"], ManagerImport._Ids(place["ids"])))
        }
        for v in res["vars"] {
            if (v["state"] != "failed")
                if (v["state"] = "taken" || v["state"] = "kept")
                counts[v["state"]] += 1
            where := (v["scope"] = "static") ? Lang("Import_scope_static", v["flowId"]) : Lang("Import_scope_global")
            switch v["state"] {
                case "taken":
                    lines.Push(Lang("Import_var_taken", v["name"], where))
                case "kept":
                    lines.Push(Lang("Import_var_kept", v["name"], where))
                case "skipped":
                    lines.Push(Lang("Import_var_skipped", v["name"], where))
                default:
                    lines.Push(Lang("Import_var_failed", v["name"], where, v["message"]))
            }
        }
        if (res["autostart"] = "error")
            lines.Push(Lang("Import_autostart_error", res["autostartError"]))
        else
            lines.Push(Lang("Import_autostart_" res["autostart"]))
        created := counts["created"] + counts["copy"]
        lines.Push(Lang("Import_summary", created, counts["copy"], counts["skipped"], counts["failed"], counts["taken"]
            , counts["kept"]))
        out := ""
        for line in lines
            out .= (out = "" ? "" : "`r`n") line
        return out
    }

    static _Ids(ids) {
        if (!(ids is Array))
            return String(ids)
        out := ""
        for id in ids
            out .= (out = "" ? "" : ", ") id
        return out
    }

    _Request(type, payload, next) {
        try {
            this.m.peer.Request("storage", type, payload, (ans) => next(ans.payload), ManagerImport.STORAGE_MS)
        } catch as e {
            this._Fail(Lang("Import_source_error", e.Message))
        }
    }

    _Confirm(kind, args, done) {
        if (!IsObject(this.ask)) {
            done(false)
            return
        }
        this.ask.Confirm(kind, args, done)
    }

    static _Message(p) {
        err := p.Get("error", "")
        if (err is Map)
            return err.Get("message", "")
        return "no answer"
    }

    static _Done(done, answer) {
        if (IsObject(done))
            done(answer)
    }
}
