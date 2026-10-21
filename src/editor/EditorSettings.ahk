#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Lang.ahk
#Include ..\core\Log.ahk
#Include ..\elements\base\ElementRegistry.ahk
#Include ..\elements\base\ParamEvaluator.ahk
#Include form\ElementForm.ahk
#Include NewElementCatalog.ahk
#Include assist\AssistantValues.ahk
#Include assist\AssistantSource.ahk
#Include assist\WindowAssistant.ahk
#Include assist\MouseAssistant.ahk
#Include assist\ColorAssistant.ahk
#Include ..\ui_common\HelpRequest.ahk

; The settings of one element in the editor (WI-0106, REQ-EDT-120, PROTOCOL 4.11): the form of the element (ElementForm,
; the headless model of WI-0105) is opened for an element of the flow (mode "edit") or for a class chosen for a new element
; (mode "new"). OK sends one patch (edit: element.update with the fields the user changed, one undo step; nothing changed
; sends nothing). Cancel sends nothing. A new element is added by EditorAdd.Create after OK; Cancel adds nothing.
;
; One settings window is open at a time (Busy). The canvas keeps working meanwhile: the live states of the engine go on, and
; the element of an edit may be gone or changed when OK comes; then OK says so in the status bar and changes nothing (decision
; of WI-0106, MIGRATION M-0095). window: the settings window (form/ElementSettingsWindow.ahk, not with --headless); the
; headless driver answers with cmd.test.form. Both read the state through State() and change the form through Set*.
;
; The expressions of the form are checked for their syntax CHECK_DELAY ms after the last change of a value (WI-0108); the
; warnings then go to the window. OK is not refused by a warning.
;
; An element whose class is not in the registry (not installed, or unknown) has no form: its parameters are shown read only
; and OK only closes the settings (REQ-MIG-070). A class with the flag Experimental gets its note in the window (REQ-USE-020).
class EditorSettings {
    __New(model) {
        this.model := model
        this.window := ""             ; ElementSettingsWindow: Show(this) and Hide(); "" with --headless
        this.adder := ""              ; EditorAdd: Create(...) adds the new element after OK
        this.session := ""            ; Map of the open settings (see _Show), or "" when none is open
        this.checkFn := () => this._CheckTyped()   ; the one-shot timer of the syntax check (CHECK_DELAY)
        this.assist := ""             ; the running assistant (WindowAssistant or MouseAssistant), "" when none (WI-0110)
        this.assistSource := AssistantSource()   ; the window, mouse and pixel source; the tests replace it
    }

    ; The syntax check of the expressions runs this many ms after the last change of a value (WI-0108): a check at every
    ; key would parse the text again and again.
    static CHECK_DELAY := 300

    ; True while a settings window (or its test answer) is open.
    Busy => IsObject(this.session)

    ; Opens the settings of an element of the flow. Returns false when nothing opens: another settings window is open, the
    ; flow is not loaded, or the element does not exist.
    Open(elementId) {
        if (this.Busy) {
            this.model.Notice("Settings_busy")
            return false
        }
        root := this.model.draft.root
        if (!(root is Map) || !(root.Get("allElements", "") is Map))
            return false
        el := root["allElements"].Get(elementId, "")
        if (!(el is Map))
            return false
        package := EditorSettings._Text(el.Get("package", ""))
        qid := ElementRegistry.QualifiedId(package, EditorSettings._Text(el.Get("class", "")))
        cls := ElementRegistry.Get(qid)
        session := Map("mode", "edit", "id", elementId, "kind", EditorSettings._Text(el.Get("type", ""))
            , "classId", qid, "origClassId", qid, "cls", cls, "migration", EditorSettings._List(el.Get("migration", ""))
            , "x", 0, "y", 0, "connect", "", "done", "", "placeholder", "", "unknown", !IsObject(cls))
        pars := el.Get("pars", Map())
        if (!IsObject(cls)) {
            session["placeholder"] := ElementRegistry.MissingText(qid)
            session["stored"] := (pars is Map) ? pars : Map()
            session["form"] := ""
            session["initial"] := Map()
        } else {
            form := ElementForm(cls, pars, EditorSettings._Text(el.Get("name", "")),
                ParamEvaluator.Truthy(el.Get("StandardName", 0)))
            session["form"] := form
            session["initial"] := form.Result()
        }
        return this._Show(session)
    }

    ; Opens the settings of a new element of the class (a qualified ID) of the kind, at the flow position x, y. The defaults
    ; of the class are filled in; connect and done are EditorAdd's (see EditorAdd.Add). Returns false (done(false) is called)
    ; when nothing opens.
    OpenNew(kind, classId, x, y, connect, done) {
        if (this.Busy) {
            this.model.Notice("Settings_busy")
            if (IsObject(done))
                done(false)
            return false
        }
        cls := ElementRegistry.Get(classId)
        if (!IsObject(cls)) {
            if (IsObject(done))
                done(false)
            return false
        }
        d := NewElementCatalog.Defaults(classId)
        form := ElementForm(cls, d["pars"], d["name"], true)
        session := Map("mode", "new", "id", "", "kind", kind, "classId", classId, "cls", cls, "migration", []
            , "x", x, "y", y, "connect", connect, "done", done, "placeholder", "", "unknown", false
            , "form", form, "initial", form.Result())
        return this._Show(session)
    }

    _Show(session) {
        this.session := session
        if (IsObject(session["form"]))
            session["form"].CheckExpressions()          ; the values as they are: no typing before this
        if (IsObject(this.window))
            this.window.Show(this)
        return true
    }

    ; OK: the changes go out as one patch (edit) or the new element is added (new). Answers Map("ok", bool, "changed", bool,
    ; "code", "message" on a refusal). The settings close in every case: a refused patch is said in the status bar.
    Ok() {
        if (!this.Busy)
            return Map("ok", false, "changed", false, "code", ErrCode.BUSY, "message", "no settings are open")
        s := this.session
        if (s["unknown"])
            return this._Close(Map("ok", true, "changed", false))
        final := s["form"].Result()
        if (s["mode"] = "new") {
            this._Close(Map("ok", true, "changed", true))
            this.adder.Create(s["kind"], s["classId"], s["x"], s["y"], s["connect"], s["done"], final)
            return Map("ok", true, "changed", true)
        }
        draft := this.model.draft
        if (!(draft.root is Map) || !(draft.root.Get("allElements", "") is Map) || !draft.root["allElements"].Has(s["id"])) {
            this.model.Notice("Settings_gone")
            return this._Close(Map("ok", false, "changed", false, "code", ErrCode.BAD_PAYLOAD
                , "message", "the element does not exist"))
        }
        if (s["classId"] != s["origClassId"])
            fields := this._ClassFields(s, final, draft.root["allElements"][s["id"]])
        else
            fields := EditorSettings.Changes(s["initial"], final)
        if (fields.Count = 0)
            return this._Close(Map("ok", true, "changed", false))
        res := draft.Commit([Map("op", "element.update", "id", s["id"], "fields", fields)], true)
        if (!res["ok"]) {
            this.model.Notice("Settings_refused")
            return this._Close(Map("ok", false, "changed", false, "code", res["code"], "message", res["message"]))
        }
        return this._Close(Map("ok", true, "changed", true))
    }

    ; Cancel: nothing is sent; a new element is not added (its done gets false).
    Cancel() {
        if (!this.Busy)
            return Map("ok", false, "changed", false, "code", ErrCode.BUSY, "message", "no settings are open")
        return this.Discard()
    }

    ; Closes the settings without a patch (also at the end of the editor). A new element's done gets false.
    Discard() {
        if (!this.Busy)
            return Map("ok", true, "changed", false)
        s := this.session
        this._Close(Map("ok", true, "changed", false))
        if (s["mode"] = "new" && IsObject(s["done"]))
            s["done"](false)
        return Map("ok", true, "changed", false)
    }

    _Close(answer) {
        SetTimer(this.checkFn, 0)
        this._EndAssistant()
        this.session := ""
        if (IsObject(this.window))
            this.window.Hide()
        return answer
    }

    ; (Re)starts the syntax check: it runs CHECK_DELAY ms after the last call (a one-shot timer, WI-0108).
    _Typed() {
        SetTimer(this.checkFn, -EditorSettings.CHECK_DELAY)
    }

    ; The timer of _Typed: checks the expressions of the form, and shows the warnings when they changed.
    _CheckTyped() {
        if (!this._Editable())
            return
        if (this.session["form"].CheckExpressions())
            this._Sync()
    }

    ; --- the form, as the window and the test change it -----------------------------------------------------------------

    ; Sets the value of a parameter (a content ID too). False when no form is open (none, or a read-only element).
    SetValue(id, value) {
        if (!this._Editable())
            return false
        this.session["form"].SetValue(id, value)
        this._Typed()
        this._Sync()
        return true
    }

    ; Sets the name (the standard name switched on or off with SetStandardName).
    SetName(text) {
        if (!this._Editable())
            return false
        this.session["form"].SetName(text)
        this._Sync()
        return true
    }

    SetStandardName(flag) {
        if (!this._Editable())
            return false
        this.session["form"].SetStandardName(flag)
        this._Sync()
        return true
    }

    ; The Help button of the settings (WI-0111): the help page of the class of the element being set (PROTOCOL 4.12).
    Help() {
        s := this.session
        if (!(s is Map) || !IsObject(s["cls"]))
            return
        HelpRequest.Open(this.model.peer, HelpPageId.ElementId(s["cls"].Name))
    }

    ; Changes the class of the element being set (v1: the type button, WI-0106). The class keeps the kind; the form is built
    ; again from the defaults of the new class (the name stays standard). Nothing is sent until OK. False when refused.
    ChangeClass(classId) {
        if (!this._Editable())
            return false
        s := this.session
        cls := ElementRegistry.Get(classId)
        if (!IsObject(cls) || NewElementCatalog.KindOf(classId) != s["kind"])
            return false
        if (classId = s["classId"])
            return true
        d := NewElementCatalog.Defaults(classId)
        s["form"] := ElementForm(cls, d["pars"], d["name"], true)
        s["form"].CheckExpressions()
        s["classId"] := classId
        s["cls"] := cls
        this._Sync()
        return true
    }

    ; Starts the assistant of a Button field (WI-0110): "window" (the window under the mouse), "mouse" (the mouse tracker) or
    ; "color" (the colour dialog). The values that the assistant takes go into the form when it ends (_AssistDone), by the
    ; map of the field. One assistant at a time, and only while the settings are open. The settings window is disabled
    ; meanwhile. False when nothing starts (no settings open, an assistant runs, an unknown kind, a failed start).
    StartAssistant(field) {
        if (!this._Editable() || IsObject(this.assist))
            return false
        kind := field.assistant
        if (!AssistantValues.IsKnown(kind)) {
            Log.Write("a0", "editor", "assistant: unknown kind '" kind "'")
            return false
        }
        form := this.session["form"]
        mapping := field.assistMap
        initial := Map()
        for key, id in mapping {
            if (form.Has(id))
                initial[key] := form.GetValue(id)
        }
        owner := IsObject(this.window) ? this.window.owner : 0
        show := IsObject(this.window) ? this.window.showWindows : false
        done := (values) => this._AssistDone(mapping, values)
        if (kind = "color") {
            current := initial.Get("color", "")
            picked := ColorAssistant.Pick.Call(IsObject(current) ? "" : String(current), owner)
            if (picked != "")
                this._AssistDone(mapping, Map("color", picked))
            return true
        }
        assist := (kind = "window") ? WindowAssistant(this.assistSource, done)
            : MouseAssistant(this.assistSource, mapping, initial, done)
        this.assist := assist
        try {
            assist.Open(show)
        } catch as e {
            this.assist := ""
            assist.Close()
            Log.Write("a0", "editor", "assistant '" kind "' does not open: " e.Message)
            return false
        }
        if (IsObject(this.window))
            this.window.AssistantBusy(true)
        return true
    }

    ; The end of an assistant: its values go into the form (by the map; ids the form lacks are skipped), then the checks run.
    _AssistDone(mapping, values) {
        this._EndAssistant()
        if (!this._Editable() || values.Count = 0)
            return
        for id, value in AssistantValues.ToIds(values, mapping) {
            if (this.session["form"].Has(id))
                this.SetValue(id, value)
        }
    }

    ; Closes the running assistant (its window and timer) and enables the settings window again. Idempotent.
    _EndAssistant() {
        a := this.assist
        this.assist := ""
        if (IsObject(a))
            a.Close()
        if (IsObject(this.window))
            this.window.AssistantBusy(false)
    }

    ; The fields of an element.update that changes the class: the class, its package and version, the name and the standard
    ; name, and every parameter of the form. A parameter that the element had and the new class does not has null (removed).
    _ClassFields(s, final, el) {
        package := ElementRegistry.PackageOf(s["classId"])
        fields := Map("class", ElementRegistry.ClassOf(s["classId"]), "package", package
            , "packageVersion", ElementRegistry.PackageVersion(package), "name", final["name"]
            , "StandardName", final["standardName"] ? 1 : 0)
        pars := Map()
        for key, value in final["pars"]
            pars[key] := value
        if (el is Map && el.Get("pars", "") is Map) {
            for key, value in el["pars"] {
                if (!final["pars"].Has(key))
                    pars[key] := Json.Null
            }
        }
        fields["pars"] := pars
        return fields
    }

    _Editable() => this.Busy && IsObject(this.session["form"])

    _Sync() {
        if (IsObject(this.window))
            this.window.Sync()
    }

    ; The form of the open settings (ElementForm) or "" (the window reads its fields from it).
    Form => this.Busy ? this.session["form"] : ""

    ; The changes of the form against its first state, as the fields of an element.update: "pars" (a Map of the changed
    ; parameters), "name" and "StandardName" (1 or 0), only the ones that changed. Pure.
    static Changes(initial, final) {
        fields := Map()
        pars := Map()
        for key, value in final["pars"] {
            if (!initial["pars"].Has(key) || !EditorSettings.Same(initial["pars"][key], value))
                pars[key] := value
        }
        if (pars.Count)
            fields["pars"] := pars
        if (initial["name"] != final["name"])
            fields["name"] := final["name"]
        if (initial["standardName"] != final["standardName"])
            fields["StandardName"] := final["standardName"] ? 1 : 0
        return fields
    }

    ; Two values of parameters are the same: lists and maps by their JSON text, the rest by their text.
    static Same(a, b) {
        if (IsObject(a) || IsObject(b))
            return IsObject(a) && IsObject(b) && Json.Stringify(a) = Json.Stringify(b)
        return String(a) = String(b)
    }

    ; The state for cmd.test.state and the tests: open, the mode, the element, the class, the name, the warnings and the
    ; fields (their type, label, value, enabled state, choices, warnings and migration places).
    State() {
        if (!this.Busy)
            return Map("open", Json.False)
        s := this.session
        cls := s["cls"]
        experimental := false
        if (IsObject(cls)) {
            try experimental := (cls.Stability = "Experimental")
        }
        st := Map("open", Json.True, "mode", s["mode"], "id", s["id"], "kind", s["kind"], "classId", s["classId"]
            , "unknown", Json.Bool(s["unknown"]), "placeholder", s["placeholder"], "experimental", Json.Bool(experimental)
            , "migration", this.Migration())
        if (s["unknown"]) {
            st["changed"] := Json.False
            st["name"] := ""
            st["standardName"] := Json.False
            st["warnings"] := []
            st["fields"] := EditorSettings._StoredText(s["stored"])
            return st
        }
        form := s["form"]
        final := form.Result()
        st["name"] := final["name"]
        st["standardName"] := Json.Bool(final["standardName"])
        st["changed"] := Json.Bool(s["mode"] = "new" || EditorSettings.Changes(s["initial"], final).Count > 0)
        st["warnings"] := form.Warnings()
        st["fields"] := EditorSettings._FieldsText(form, this.Migration())
        return st
    }

    ; The migration places of the element now, as _MigrationText gives them: read from the draft for an edit, so that a
    ; place that the engine resolved (WI-0093) is gone. A new element has none.
    Migration() {
        if (!this.Busy)
            return []
        s := this.session
        if (s["mode"] = "edit") {
            root := this.model.draft.root
            if (root is Map && root.Get("allElements", "") is Map) {
                el := root["allElements"].Get(s["id"], "")
                if (el is Map)
                    return EditorSettings._MigrationText(EditorSettings._List(el.Get("migration", "")))
            }
            return []
        }
        return EditorSettings._MigrationText(s["migration"])
    }

    static _FieldsText(form, migration) {
        out := []
        for field in form.fields {
            value := (field.isValue && field.ids.Length) ? form.GetValue(field.ids[1]) : ""
            texts := []
            for warning in form.FieldWarnings(field)
                texts.Push(warning)
            out.Push(Map("type", field.kind, "label", field.label, "ids", field.ids, "contentId", field.contentId
                , "content", field.content, "enabled", Json.Bool(field.isEnabled), "value", value
                , "choices", field.choices, "values", field.isValue ? EditorSettings._ValuesOf(form, field) : []
                , "warnings", texts, "migration", EditorSettings._MigrationFor(migration, field.ids)))
        }
        return out
    }

    static _ValuesOf(form, field) {
        if (!field.ids.Length)
            return []
        return form.ChoiceValues(field.ids[1])
    }

    ; The places of the migration list that name one of the ids: each Map("par", id, "ids", Array, "v1", text).
    static _MigrationFor(migration, ids) {
        out := []
        for entry in migration {
            if (!(entry is Map))
                continue
            for id in ids {
                if (StrLower(String(entry.Get("par", ""))) = StrLower(id)) {
                    out.Push(EditorSettings._MigrationEntry(entry))
                    break
                }
            }
        }
        return out
    }

    static _MigrationText(migration) {
        out := []
        for entry in migration {
            if (entry is Map)
                out.Push(EditorSettings._MigrationEntry(entry))
        }
        return out
    }

    static _MigrationEntry(entry) {
        ids := EditorSettings._List(entry.Get("ids", []))
        return Map("par", EditorSettings._Text(entry.Get("par", "")), "ids", ids, "v1", EditorSettings._Text(entry.Get("v1", "")))
    }

    ; The stored parameters of an element without a class (read only): Array of Map("id", name, "value", text).
    static _StoredText(stored) {
        out := []
        for key, value in stored
            out.Push(Map("id", key, "value", IsObject(value) ? "" : String(value)))
        return out
    }

    ; The text of a value that is a text (an object gives "").
    static _Text(v) => IsObject(v) ? "" : String(v)

    ; A list as an Array (a text or an object as an empty list, an Array copied).
    static _List(v) {
        out := []
        if (v is Array) {
            for item in v
                out.Push(item)
        }
        return out
    }
}
