#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include ..\core\Lang.ahk
#Include ..\core\SettingsModel.ahk

; The flow settings of the editor (WI-0109, REQ-EDT-140, PROTOCOL 4.2 flow settings, 4.11): the dialog of the keys of
; flowSettings that the engine reads (execution policy, working directory, type mode, the three limits of the runaway guard,
; the notices of unhandled errors). The window (form/FlowSettingsWindow.ahk, not with --headless) and the headless driver
; both change the form through Set and read it through State; OK sends one flow.settings operation with the changed keys
; (one undo step, EditorDraft.Commit), Cancel sends nothing.
;
; The form holds normalized values, the same ones the engine reads: policy (a word of POLICIES), useGlobalDir (1 or 0; the
; engine uses the flow's own folder when DefaultWorkingDir is not true and the folder is not empty), workingDir (text),
; strict (1 or 0), limits (Map key -> "default" or a whole number text, 0 means no limit) and notify ("default", "on" or
; "off"). A missing key has the default of the engine; "default" means the global setting, which the dialog shows from the
; settings it was given (globals).
;
; OK refuses (nothing changes, the dialog stays open) an invalid limit or an invalid own folder. A warning does not block: the
; switch of a migrated flow (no strictTypes key yet) to strict says what it means.
class EditorFlowSettings {
    static POLICIES := ["default", "parallel", "skip", "wait", "stop"]
    static LIMITS := ["maxExecutionsPerMinute", "maxWaitingInstances", "maxParallelInstances"]
    static LIMIT_LABEL := Map("maxExecutionsPerMinute", "Flow_settings_limit_per_minute"
        , "maxWaitingInstances", "Flow_settings_limit_waiting", "maxParallelInstances", "Flow_settings_limit_parallel")
    static NOTIFY := ["default", "on", "off"]
    static POLICY_LABEL := Map("parallel", "Parallel execution of multiple instances"
        , "skip", "Skip execution when an instance is already executing"
        , "wait", "Wait until the currently executing instance has finished"
        , "stop", "Stop the currently executing instance and execute afterwards")

    __New(model, peer, flowId) {
        this.model := model
        this.peer := peer
        this.flowId := flowId
        this.window := ""             ; FlowSettingsWindow: Show(this), Hide() and Sync(); "" with --headless
        this.globals := Map()         ; the global settings (policy, limits, notices), for the "default" labels
        this.session := ""            ; Map("initial", state, "form", state, "migrated", bool), or "" when none is open
    }

    ; True while the flow settings (or their test answer) are open.
    Busy => IsObject(this.session)

    ; Opens the dialog for the flow of the draft. globals: the global settings (a Map) or "" to keep the last ones.
    ; Returns false when nothing opens: another settings dialog is open, or the flow is not loaded.
    Open(globals := "") {
        if (this.Busy) {
            this.model.Notice("Settings_busy")
            return false
        }
        root := this.model.draft.root
        if (!(root is Map))
            return false
        if (globals is Map)
            this.globals := globals
        settings := root.Get("flowSettings", "")
        initial := EditorFlowSettings.Read(settings)
        this.session := Map("initial", initial, "form", EditorFlowSettings.Copy(initial)
            , "migrated", EditorFlowSettings.Migrated(settings), "name", EditorFlowSettings._Text(root.Get("name", "")))
        if (IsObject(this.window))
            this.window.Show(this)
        return true
    }

    ; Sets one field of the form: policy, useGlobalDir (1 or 0), workingDir, strict (1 or 0), notify (default, on, off), or
    ; limit:<key> (one of LIMITS, the value is the text as typed). False when no dialog is open or the field is unknown.
    Set(field, value) {
        if (!this.Busy)
            return false
        form := this.session["form"]
        switch field {
            case "policy":
                form["policy"] := StrLower(EditorFlowSettings._Text(value))
            case "useGlobalDir":
                form["useGlobalDir"] := EditorFlowSettings._Truthy(value) ? 1 : 0
            case "workingDir":
                form["workingDir"] := EditorFlowSettings._Text(value)
            case "strict":
                form["strict"] := EditorFlowSettings._Truthy(value) ? 1 : 0
            case "notify":
                form["notify"] := StrLower(EditorFlowSettings._Text(value))
            default:
                if (SubStr(field, 1, 6) != "limit:")
                    return false
                key := SubStr(field, 7)
                if (!form["limits"].Has(key))
                    return false
                text := Trim(EditorFlowSettings._Text(value))
                form["limits"][key] := (IsInteger(text) && Integer(text) >= 0) ? String(Integer(text)) : text
        }
        this._Sync()
        return true
    }

    ; OK: the changed keys go out as one flow.settings operation (one undo step). Answers Map("ok", bool, "changed", bool,
    ; "code", "message" on a refusal). An invalid form (Check) changes nothing and the dialog stays open.
    Ok() {
        if (!this.Busy)
            return Map("ok", false, "changed", false, "code", ErrCode.BUSY, "message", "no flow settings are open")
        s := this.session
        checks := EditorFlowSettings.Check(s["form"], s["initial"], s["migrated"])
        if (checks["errors"].Length)
            return Map("ok", false, "changed", false, "code", ErrCode.BAD_PAYLOAD, "message", checks["errors"][1])
        fields := EditorFlowSettings.Changes(s["initial"], s["form"])
        if (fields.Count = 0)
            return this._Close(Map("ok", true, "changed", false))
        res := this.model.draft.Commit([Map("op", "flow.settings", "settings", fields)], true)
        if (!res["ok"]) {
            this.model.Notice("Flow_settings_refused")
            return this._Close(Map("ok", false, "changed", false, "code", res["code"], "message", res["message"]))
        }
        return this._Close(Map("ok", true, "changed", true))
    }

    ; Cancel: nothing is sent.
    Cancel() {
        if (!this.Busy)
            return Map("ok", false, "changed", false, "code", ErrCode.BUSY, "message", "no flow settings are open")
        return this.Discard()
    }

    ; Closes the dialog without a patch (also at the end of the editor).
    Discard() {
        if (!this.Busy)
            return Map("ok", true, "changed", false)
        return this._Close(Map("ok", true, "changed", false))
    }

    _Close(answer) {
        this.session := ""
        if (IsObject(this.window))
            this.window.Hide()
        return answer
    }

    _Sync() {
        if (IsObject(this.window))
            this.window.Sync()
    }

    ; "Show log" (WI-0109, PROTOCOL 4.11): asks the supervisor for the log window of the manager, filtered to this flow. The
    ; dialog stays open; a refusal is a text in the status bar.
    ShowLog() {
        try {
            this.peer.Request("supervisor", "cmd.manager.showLog", Map("flowId", this.flowId)
                , (ans) => this._OnLog(ans), 3000)
        } catch as e {
            this.model.Notice("Flow_settings_log_refused")
        }
    }

    _OnLog(ans) {
        if (!(ans.payload.Get("ok", false)))
            this.model.Notice("Flow_settings_log_refused")
    }

    ; The state for cmd.test.state and the window tests: open, the form, the changes, the checks (texts) and the migration.
    State() {
        if (!this.Busy)
            return Map("open", Json.False)
        s := this.session
        form := s["form"]
        checks := EditorFlowSettings.Check(form, s["initial"], s["migrated"])
        limits := Map()
        for key in EditorFlowSettings.LIMITS
            limits[key] := form["limits"][key]
        return Map("open", Json.True, "name", s["name"], "policy", form["policy"]
            , "useGlobalDir", Json.Bool(form["useGlobalDir"]), "workingDir", form["workingDir"]
            , "strict", Json.Bool(form["strict"]), "limits", limits, "notify", form["notify"]
            , "changed", Json.Bool(EditorFlowSettings.Changes(s["initial"], form).Count > 0)
            , "migrated", Json.Bool(s["migrated"]), "errors", checks["errors"], "warnings", checks["warnings"])
    }

    ; --- pure parts (no window, no draft) ------------------------------------------------------------------------------

    ; The normalized state of a flowSettings Map (or "" for none), as the engine reads it (see the file comment).
    static Read(settings) {
        state := Map("policy", "default", "useGlobalDir", 1, "workingDir", "", "strict", 0
            , "limits", Map(), "notify", "default")
        if (!(settings is Map))
            settings := Map()
        policy := StrLower(EditorFlowSettings._Text(settings.Get("ExecutionPolicy", "default")))
        if (EditorFlowSettings._Contains(EditorFlowSettings.POLICIES, policy))
            state["policy"] := policy
        own := EditorFlowSettings._Text(settings.Get("WorkingDir", ""))
        state["workingDir"] := own
        useDefault := EditorFlowSettings._Truthy(settings.Get("DefaultWorkingDir", ""))
        state["useGlobalDir"] := (useDefault || Trim(own) = "") ? 1 : 0
        state["strict"] := EditorFlowSettings._Truthy(settings.Get("strictTypes", "")) ? 1 : 0
        for key in EditorFlowSettings.LIMITS
            state["limits"][key] := EditorFlowSettings._Limit(settings.Get(key, "default"))
        state["notify"] := EditorFlowSettings._Notify(settings)
        return state
    }

    ; A copy of a state (the limits Map is copied too).
    static Copy(state) {
        out := state.Clone()
        out["limits"] := state["limits"].Clone()
        return out
    }

    ; True when the flow has no strictTypes key: a flow from v1, or a file that v2 saved before the option existed (ARCHITECTURE 7).
    static Migrated(settings) => !(settings is Map && settings.Has("strictTypes"))

    ; The checks of a form: errors refuse OK (the text of the first is the answer), warnings are shown. Pure.
    static Check(form, initial, migrated) {
        errors := []
        warnings := []
        for key in EditorFlowSettings.LIMITS {
            text := form["limits"][key]
            if (text != "default" && !(IsInteger(text) && Integer(text) >= 0))
                errors.Push(Format(Lang("Flow_settings_limit_bad"), Lang(EditorFlowSettings.LIMIT_LABEL[key])))
        }
        if (!form["useGlobalDir"]) {
            try {
                SettingsModel.Check("workingDir", form["workingDir"])
            } catch {
                errors.Push(Lang("Flow_settings_dir_bad"))
            }
        }
        if (form["strict"] && !initial["strict"] && migrated)
            warnings.Push(Lang("Flow_settings_strict_warning"))
        return Map("errors", errors, "warnings", warnings)
    }

    ; The changed keys of the form against the initial state, as the settings of one flow.settings operation (wire values:
    ; JSON true and false, the words, whole numbers). A key that did not change is not in the result.
    static Changes(initial, form) {
        out := Map()
        if (initial["policy"] != form["policy"])
            out["ExecutionPolicy"] := form["policy"]
        if (initial["useGlobalDir"] != form["useGlobalDir"])
            out["DefaultWorkingDir"] := form["useGlobalDir"] ? Json.True : Json.False
        if (initial["workingDir"] != form["workingDir"])
            out["WorkingDir"] := form["workingDir"]
        if (initial["strict"] != form["strict"])
            out["strictTypes"] := form["strict"] ? Json.True : Json.False
        for key in EditorFlowSettings.LIMITS {
            if (initial["limits"][key] != form["limits"][key]) {
                text := form["limits"][key]
                out[key] := (text = "default") ? "default" : (IsInteger(text) ? Integer(text) : text)
            }
        }
        if (initial["notify"] != form["notify"]) {
            switch form["notify"] {
                case "on": out["notifyUnhandledErrors"] := Json.True
                case "off": out["notifyUnhandledErrors"] := Json.False
                default: out["notifyUnhandledErrors"] := "default"
            }
        }
        return out
    }

    ; One limit as the engine reads it: "default" or a whole number text (anything else is the default, as the engine).
    static _Limit(v) {
        if (IsObject(v))
            return "default"
        if (IsInteger(v) && Integer(v) >= 0)
            return String(Integer(v))
        return "default"
    }

    ; The notices of the flow as "default", "on" or "off" (the rule of FlowNotify, engine/core).
    static _Notify(settings) {
        if (!settings.Has("notifyUnhandledErrors"))
            return "default"
        v := settings["notifyUnhandledErrors"]
        if (v == Json.True || (!IsObject(v) && (v = 1 || v = "1" || v = "true")))
            return "on"
        if (v == Json.False || (!IsObject(v) && (v = 0 || v = "0" || v = "false")))
            return "off"
        return "default"
    }

    static _Contains(list, word) {
        for item in list {
            if (item = word)
                return true
        }
        return false
    }

    ; True for JSON true, 1, "1" and "true" (the rule of the engine's strictTypes and DefaultWorkingDir).
    static _Truthy(v) => (v == Json.True || (!IsObject(v) && (v = 1 || v = "1" || v = "true")))

    static _Text(v) => IsObject(v) ? "" : String(v)
}
