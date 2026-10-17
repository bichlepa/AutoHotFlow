#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\ErrCode.ahk
#Include ..\core\Json.ahk
#Include ..\core\Lang.ahk
#Include ManagerModel.ahk
#Include ManagerOps.ahk
#Include ManagerImport.ahk

; Export and import of flows as .ahf files (WI-0081, PROTOCOL 4.8, REQ-MGR-050, REQ-SEC-060). The manager runs one chain, one
; request after the other; the file is read and written by storage (cmd.storage.ahf.*), the flows are checked by the engine
; (cmd.import.scan) and created by the engine (cmd.flow.create without flowId: every imported flow gets a new ID, disabled).
; The questions go through the seam `ask` (ManagerWindow or the test driver):
;   ask.Confirm("importWarning", [text], done)   yes: import; no (preselected): nothing is created
;   ask.Choose("importConflict", items, done, name) 1 next free number, 2 a name the user types, 3 skip, 4 cancel
;   ask.Input("importName", default, check, done)  the typed name ("" when cancelled: the flow is skipped)
;
; The result is a report (Map as ManagerImport: flows, vars, error), shown by the view as ManagerImport.Text does.
; Nothing is overwritten: a name that is taken gets a number or a name of the user, never the flow of v2.
class ManagerArchive {
    static STORAGE_MS := 30000
    static SCAN_MS := 30000
    ; A create writes a flow file (and a category list) in storage (as in ManagerImport).
    static WRITE_MS := 30000

    __New(model) {
        this.m := model
        this.ask := ""          ; the seam of the questions
        this.log := ""          ; fn(level, text): the log of the role
        this.running := false
    }

    ; Exports the flows (IDs) to the file path (absolute, .ahf). done(res): Map(ok, count, error, path).
    Export(flowIds, path, done) {
        if (flowIds.Length = 0) {
            ManagerArchive._Done(done, Map("ok", 0, "count", 0, "error", Lang("Archive_export_none"), "path", path))
            return
        }
        try {
            this.m.peer.Request("storage", "cmd.storage.ahf.pack", Map("flowIds", flowIds, "path", path)
                , (ans) => this._Exported(ans.payload, path, done), ManagerArchive.STORAGE_MS)
        } catch as e {
            ManagerArchive._Done(done, Map("ok", 0, "count", 0, "error", e.Message, "path", path))
        }
    }

    _Exported(p, path, done) {
        if (!p.Get("ok", 0)) {
            ManagerArchive._Done(done, Map("ok", 0, "count", 0, "error", ManagerArchive._Message(p), "path", path))
            return
        }
        ManagerArchive._Done(done, Map("ok", 1, "count", p.Get("count", 0), "error", "", "path", path))
    }

    ; Imports the .ahf file at path. done(res) runs once, when the import is over (the report, see ManagerImport.Text).
    Start(path, done) {
        if (this.running) {
            ManagerArchive._Done(done, Map("ok", 0, "error", Lang("Import_busy"), "flows", [], "vars", [], "autostart", "skip"))
            return
        }
        this.running := true
        this.done := done
        this.path := path
        this.items := []         ; the flows of the file that could be read: Map(key, name, defn, scanError, acting)
        this.varList := []
        this.created := Map()    ; key of the file -> flow ID of the created flow
        this.names := Map()      ; names of the flows created by this import (ignoring case)
        this.names.CaseSense := "Off"
        this.cats := Map()       ; category names of v2 (ignoring case); the import adds the missing ones
        this.cats.CaseSense := "Off"
        for c in this.m.CategoryNames()
            this.cats[c] := true
        this.res := Map("ok", 1, "error", "", "flows", [], "vars", [], "autostart", "skip", "autostartError", ""
            , "copies", 0, "dir", path)
        this._Request("cmd.storage.ahf.unpack", Map("path", path), (p) => this._Unpacked(p))
    }

    ; --- the chain -------------------------------------------------------------------------------------------------

    _Unpacked(p) {
        if (!p.Get("ok", 0))
            return this._Fail(Lang("Archive_read_error", ManagerArchive._Message(p)))
        this.varList := p.Get("vars", [])
        for f in p.Get("flows", []) {
            defn := ""
            try {
                defn := Json.Parse(f["text"])
            } catch as e {
                this._Listed(f["key"], "", "failed", Lang("Import_reason_json", e.Message))
                continue
            }
            if (!(defn is Map)) {
                this._Listed(f["key"], "", "failed", Lang("Import_reason_not_flow"))
                continue
            }
            name := defn.Get("name", "")
            name := IsObject(name) ? "" : String(name)
            this.items.Push(Map("key", f["key"], "name", name, "defn", defn, "scanError", "", "acting", []))
        }
        if (this.items.Length = 0)
            return this._Variables()
        defs := []
        for item in this.items
            defs.Push(item["defn"])
        this.m.Command("cmd.import.scan", Map("flows", defs), (ans) => this._Scanned(ans), ManagerArchive.SCAN_MS)
    }

    _Scanned(ans) {
        if (!ans["ok"])
            return this._Fail(Lang("Archive_scan_error", ans["message"]))
        scans := ans["payload"].Get("flows", [])
        if (!(scans is Array) || scans.Length != this.items.Length)
            return this._Fail(Lang("Archive_scan_error", "the answer does not match the flows"))
        lines := []
        for i, item in this.items {
            sc := scans[i]
            if (sc.Has("error")) {
                item["scanError"] := sc["error"]
                continue
            }
            names := []
            for a in sc.Get("acting", [])
                names.Push(a.Get("known", 0) ? a["id"] : Lang("Archive_warning_unknown", a["id"]))
            item["acting"] := names
            if (names.Length > 0)
                lines.Push(Lang("Archive_warning_flow", item["name"], ManagerArchive._Join(names)))
        }
        text := Lang("Archive_warning_intro") "`r`n`r`n"
        text .= (lines.Length = 0) ? Lang("Archive_warning_none") : ManagerArchive._Lines(lines)
        text .= "`r`n`r`n" Lang("Archive_warning_question")
        this._Confirm("importWarning", [text], (yes) => this._AfterWarning(yes))
    }

    _AfterWarning(yes) {
        if (!yes) {
            this.res["error"] := Lang("Archive_cancelled")
            return this._Finish()
        }
        this._Create(1)
    }

    ; One flow of the file: a name that is taken asks; a flow that failed to load is listed.
    _Create(i) {
        if (i > this.items.Length)
            return this._Variables()
        item := this.items[i]
        if (item["scanError"] != "")
            return this._Entry(i, item, "failed", "", Lang("Archive_reason_load", item["scanError"]), [])
        name := item["name"]
        if (name = "")
            return this._Entry(i, item, "failed", "", Lang("Archive_reason_name"), [])
        if (this._Taken(name))
            return this._Choose(i, item, name)
        this._Send(i, item, name, false)
    }

    _Choose(i, item, name) {
        items := [[1, Lang("Archive_rename_number")], [2, Lang("Archive_rename_typed")], [3, Lang("Archive_skip")]
            , [4, Lang("Archive_cancel")]]
        this._Ask("importConflict", items, (answer) => this._Conflict(i, item, name, answer), name)
    }

    _Conflict(i, item, name, answer) {
        if (answer = 1)
            return this._Send(i, item, name, true)
        if (answer = 2) {
            taken := this._TakenNames()
            this._AskInput("importName", name, (v) => ManagerOps.NameProblem(v, taken), (value) => this._Typed(i, item, value))
            return
        }
        if (answer = 3)
            return this._Entry(i, item, "skipped", "", Lang("Archive_reason_conflict"), [])
        ; cancel (4, or the close box): the flows created so far stay; the rest is not imported
        this.res["error"] := Lang("Archive_cancelled")
        this._Variables()
    }

    _Typed(i, item, value) {
        if (value = "")
            return this._Entry(i, item, "skipped", "", Lang("Archive_reason_conflict"), [])
        this._Send(i, item, value, false)
    }

    ; cmd.flow.create with the definition of the file. numberName: the engine gives the next free number (a copy); a typed
    ; name is given as the name (the engine checks it again).
    _Send(i, item, name, numberName) {
        defn := item["defn"]
        cat := defn.Get("category", "")
        cat := IsObject(cat) ? "" : String(cat)
        if (StrLower(cat) = "uncategorized") {          ; v1 names the uncategorized group so: none in v2
            defn["category"] := ""
            cat := ""
        }
        if (cat = "" || this.cats.Has(cat))
            return this._SendFlow(i, item, name, numberName)
        ; a category that v2 lacks is created first, as the import from v1 does (a failure shows in the flow's answer)
        this.m.Command("cmd.category.create", Map("name", cat), (ans) => this._CategoryAdded(i, item, name, numberName, cat, ans)
            , ManagerArchive.WRITE_MS)
    }

    _CategoryAdded(i, item, name, numberName, cat, ans) {
        if (ans["ok"])
            this.cats[cat] := true
        this._SendFlow(i, item, name, numberName)
    }

    _SendFlow(i, item, name, numberName) {
        payload := Map("definition", item["defn"])
        if (name != item["name"])
            payload["name"] := name
        if (numberName)
            payload["numberName"] := Json.True
        this.m.Command("cmd.flow.create", payload, (ans) => this._Created(i, item, name, ans), ManagerArchive.WRITE_MS)
    }

    _Created(i, item, name, ans) {
        if (!ans["ok"]) {
            state := (ans["code"] = ErrCode.CONFLICT || ans["code"] = ErrCode.BAD_PAYLOAD) ? "skipped" : "failed"
            return this._Entry(i, item, state, "", ans["message"], [])
        }
        p := ans["payload"]
        flowId := p.Get("flowId", "")
        newName := String(p.Get("name", name))
        this.names[newName] := true
        this.created[item["key"]] := flowId
        this._Entry(i, item, (newName = item["name"]) ? "created" : "copy", flowId, "", p.Get("places", []), newName)
    }

    ; A file entry that is listed without a chance to create it (it could not be read as a flow).
    _Listed(key, flowId, state, message) {
        this.res["flows"].Push(Map("name", key, "state", state, "flowId", flowId, "message", message, "places", []
            , "as", ""))
    }

    _Entry(i, item, state, flowId, message, places, newName := "") {
        this.res["flows"].Push(Map("name", item["name"], "state", state, "flowId", flowId, "message", message
            , "places", places, "as", newName))
        this._Create(i + 1)
    }

    ; The static variables of the flows that were created, one command; the others are listed as skipped.
    _Variables() {
        statics := []
        for ref in this.varList {
            if (!this.created.Has(ref["flowKey"])) {
                this.res["vars"].Push(Map("scope", "static", "flowId", ref["flowKey"], "name", ref["name"]
                    , "state", "skipped", "message", ""))
                continue
            }
            statics.Push(Map("flowId", this.created[ref["flowKey"]], "name", ref["name"], "type", ref["type"]
                , "content", ref["content"]))
        }
        if (statics.Length = 0)
            return this._Finish()
        this.m.Command("cmd.import.v1.vars", Map("globals", [], "statics", statics), (ans) => this._VarsDone(ans, statics))
    }

    _VarsDone(ans, sent) {
        if (!ans["ok"]) {
            for v in sent
                this.res["vars"].Push(Map("scope", "static", "flowId", v["flowId"], "name", v["name"], "state", "failed"
                    , "message", ans["message"]))
            return this._Finish()
        }
        p := ans["payload"]
        for item in p.Get("taken", [])
            this.res["vars"].Push(Map("scope", item["scope"], "flowId", item["flowId"], "name", item["name"], "state", "taken"
                , "message", ""))
        for item in p.Get("kept", [])
            this.res["vars"].Push(Map("scope", item["scope"], "flowId", item["flowId"], "name", item["name"], "state", "kept"
                , "message", ""))
        for item in p.Get("failed", [])
            this.res["vars"].Push(Map("scope", item["scope"], "flowId", item["flowId"], "name", item["name"], "state", "failed"
                , "message", item.Get("message", "")))
        this._Finish()
    }

    _Fail(text) {
        this.res["ok"] := 0
        this.res["error"] := text
        this._Finish()
    }

    _Finish() {
        this.running := false
        text := ManagerImport.Text(this.res)
        write := this.log
        if (IsObject(write))
            write("a1", text)
        ManagerArchive._Done(this.done, this.res)
    }

    ; --- helpers ----------------------------------------------------------------------------------------------------

    ; A name that a flow of v2 or of this import has (ignoring case).
    _Taken(name) {
        for flowId, rec in this.m.flows {
            if (StrLower(rec["name"]) = StrLower(name))
                return true
        }
        return this.names.Has(name)
    }

    _TakenNames() {
        out := []
        for flowId, rec in this.m.flows
            out.Push(rec["name"])
        for name in this.names
            out.Push(name)
        return out
    }

    _Ask(kind, items, done, name) {
        if (!IsObject(this.ask)) {
            done(0)
            return
        }
        this.ask.Choose(kind, items, done, name)
    }

    _AskInput(kind, default, check, done) {
        if (!IsObject(this.ask)) {
            done("")
            return
        }
        this.ask.Input(kind, default, check, done)
    }

    _Confirm(kind, args, done) {
        if (!IsObject(this.ask)) {
            done(false)
            return
        }
        this.ask.Confirm(kind, args, done)
    }

    _Request(type, payload, next) {
        try {
            this.m.peer.Request("storage", type, payload, (ans) => next(ans.payload), ManagerArchive.STORAGE_MS)
        } catch as e {
            this._Fail(Lang("Archive_read_error", e.Message))
        }
    }

    static _Message(p) {
        err := p.Get("error", "")
        if (err is Map)
            return err.Get("message", "")
        return "no answer"
    }

    static _Join(names) {
        out := ""
        for name in names
            out .= (out = "" ? "" : ", ") name
        return out
    }

    static _Lines(lines) {
        out := ""
        for line in lines
            out .= (out = "" ? "" : "`r`n") line
        return out
    }

    static _Done(done, answer) {
        if (IsObject(done))
            done(answer)
    }
}
