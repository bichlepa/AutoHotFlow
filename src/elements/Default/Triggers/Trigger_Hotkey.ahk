#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\WindowIdent.ahk

; Trigger Hotkey of the package Default (WI-0064, REQ-TRG-230, ELEMENT-API-V2 5, M-0003): fires when the hotkey is
; pressed, optionally only while a window is active or exists (UseWindow). Parameters, GenerateName and language keys
; are those of v1 (Source_Elements/Default/Triggers/Hotkey.ahk). Runs in the trigger host (Mode trigger).
;
; Shared registration (task 4): the hotkey text and the window condition together name one registration in the host,
; with the list of the armed triggers on it. A press fires every armed trigger of the list; the last Disable of the
; list turns the hotkey off. Two flows with the same hotkey and the same window condition both fire (v1 replaced the
; first one; see MIGRATION M-0003).
class Trigger_Hotkey extends AhfElement {
    static Mode := "trigger"
    static Level := "Beginner"
    static Stability := "Stable"

    ; The values of UseWindow, in the order of its choices (v1 enum).
    static WINDOW_MODES := ["Everywhere", "WindowIsActive", "WindowExists", "WindowIsNotActive", "WindowNotExists"]

    ; The window parameters that the element shows only when a window is used (v1 CheckSettings).
    static WINDOW_PARAMS := ["TitleMatchMode", "Wintitle", "excludeTitle", "FindHiddenText", "winText", "ExcludeText"
        , "ahk_class", "ahk_exe", "ahk_id", "ahk_pid", "FindHiddenWindow", "GetWindowInformation"]

    ; Registrations in this host: key (hotkey text, a line break, window condition) -> Map("full", text, "hotIf",
    ; criterion function or "", "entries", Array of Map("ctx", ctx, "fire", function), "cb", callback).
    static _regs := Map()

    static Name() => Lang("Hotkey")
    static Category() => Lang("User_interaction")

    static Parameters(ctx) {
        list := [
            {type: "Label", label: Lang("Hotkey")},
            {type: "Hotkey", id: "hotkey"},
            {type: "Label", label: Lang("Options")},
            {type: "Checkbox", id: "BlockKey", default: 1, label: Lang("Block_key")},
            {type: "Checkbox", id: "Wildcard", default: 0, label: Lang("Trigger even if other keys are already held down")},
            {type: "Checkbox", id: "WhenRelease", default: 0, label: Lang("Trigger on release rather than press")},
            {type: "Label", label: Lang("Scope")},
            {type: "Label", size: "small", label: Lang("Where should the hotkey be active?")},
            {type: "Radio", id: "UseWindow", default: 1, result: "enum"
                , choices: [Lang("Everywhere"), Lang("Only active when the specified window is active")
                    , Lang("Only active whe the specified window exists")
                    , Lang("Only active when the specified window is not active")
                    , Lang("Only active whe the specified window does not exist")]
                , enum: this.WINDOW_MODES}
        ]
        WindowIdent.AddIdentificationParameters(list, {noExcludes: true})
        return list
    }

    ; "Hotkey - <hotkey>" (v1 Element_GenerateName_Trigger_Hotkey).
    static GenerateName(ctx, params) => Lang("Hotkey") " - " (params.HasProp("hotkey") ? params.hotkey : "")

    ; v1 Element_CheckSettings_Trigger_Hotkey: the two checkboxes exclude each other, and the window parameters are
    ; shown only for a window condition.
    static CheckSettings(form, params, staticValues) {
        blockKey := this._Truthy(params.HasProp("BlockKey") ? params.BlockKey : 0)
        whenRelease := this._Truthy(params.HasProp("WhenRelease") ? params.WhenRelease : 0)
        form.Disable("WhenRelease", blockKey)
        form.Disable("BlockKey", whenRelease)
        useWindow := params.HasProp("UseWindow") ? params.UseWindow : ""
        showWindow := useWindow = "WindowIsActive" || useWindow = "WindowExists" || useWindow = "WindowIsNotActive"
            || useWindow = "WindowNotExists"
        for id in this.WINDOW_PARAMS
            form.Enable(id, showWindow)
    }

    ; Arms the trigger: the hotkey text and the window condition name the registration. The first trigger with them sets
    ; the hotkey (Hotkey, with the criterion in effect); the trigger joins the list. An invalid hotkey or a hotkey the
    ; system refuses is an ElementError with the v1 text. The state is kept before the registration, so Disable can
    ; cope with a failed Enable.
    static Enable(ctx, params) {
        full := this.FullText(params)
        mode := this.ModeOf(params)
        spec := (mode = "Everywhere") ? "" : WindowIdent.Spec(params)
        key := full "`n" mode "`n" (spec = "" ? "" : this._SpecKey(spec))
        ctx.State.regKey := key
        ctx.State.full := full
        reg := this._regs.Has(key) ? this._regs[key] : this._Register(key, full, mode, spec)
        entry := Map("ctx", ctx, "fire", ctx.Guard(() => ctx.Fire()))
        reg["entries"].Push(entry)
        return Lang("The hotkey %1% was set.", full)
    }

    ; Removes the trigger from its registration. The hotkey is turned off when no trigger is left on it, with the same
    ; criterion as when it was set (v1 forgets it: a context-bound hotkey could stay active). Also called after a failed
    ; Enable: then there is no registration or no entry, and nothing happens.
    static Disable(ctx) {
        if (!ctx.State.HasProp("regKey"))
            return
        key := ctx.State.regKey
        if (!this._regs.Has(key))
            return
        reg := this._regs[key]
        entries := reg["entries"]
        for i, entry in entries {
            if (entry["ctx"] == ctx) {
                entries.RemoveAt(i)
                break
            }
        }
        if (entries.Length > 0)
            return
        this._regs.Delete(key)
        this._SetCriterion(reg["hotIf"])
        try {
            Hotkey(reg["full"], "Off")
        } finally {
            HotIf()
        }
    }

    ; The thread variables after the event: A_Hotkey (v1 Element_postTrigger_Trigger_Hotkey). Pure function.
    static TriggerVariables(params, data) => Map("A_Hotkey", params.HasProp("hotkey") ? params.hotkey : "")

    ; The hotkey text of the parameters as AutoHotkey needs it, in the order of v1: "~" for the pass-through, " UP" for
    ; release, "*" for the wildcard. Throws ElementError when the hotkey is not set.
    static FullText(params) {
        keyText := params.HasProp("hotkey") ? params.hotkey : ""
        if (IsObject(keyText) || keyText = "")
            throw ElementError(Lang("The_Hotkey_is_not_set!"))
        full := String(keyText)
        if (!this._Truthy(params.HasProp("BlockKey") ? params.BlockKey : 0))
            full := "~" full
        if (this._Truthy(params.HasProp("WhenRelease") ? params.WhenRelease : 0))
            full := full " UP"
        if (this._Truthy(params.HasProp("Wildcard") ? params.Wildcard : 0))
            full := "*" full
        return full
    }

    ; The window condition of the parameters: "Everywhere" or one of the four window values. Throws ElementError for an
    ; unknown value (the v1 text for an invalid parameter value).
    static ModeOf(params) {
        value := params.HasProp("UseWindow") ? params.UseWindow : "Everywhere"
        ; v1 stores the index of a radio when a flow does not have the parameter (1 is Everywhere).
        if (!IsObject(value) && IsInteger(value) && value >= 1 && value <= this.WINDOW_MODES.Length)
            return this.WINDOW_MODES[Integer(value)]
        for name in this.WINDOW_MODES {
            if (name = value)
                return name
        }
        throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "UseWindow", IsObject(value) ? "" : value))
    }

    ; The criterion function of a window condition (HotIf form), or "" for Everywhere. Its argument is the hotkey name
    ; (AutoHotkey passes it); it returns true or false. The window is looked up at every key event.
    static Condition(mode, spec) {
        switch mode {
            case "WindowIsActive":    return (*) => WindowIdent.IsActive(spec)
            case "WindowExists":      return (*) => WindowIdent.Find(spec) != 0
            case "WindowIsNotActive": return (*) => !WindowIdent.IsActive(spec)
            case "WindowNotExists":   return (*) => WindowIdent.Find(spec) = 0
            default:                  return ""
        }
    }

    ; --- the registrations ------------------------------------------------------------------------

    ; Sets the hotkey with its criterion and keeps the registration. The criterion in effect is reset afterwards in
    ; any case (HotIf() without a parameter), so other hotkeys of the host are not affected.
    static _Register(key, full, mode, spec) {
        criterion := (mode = "Everywhere") ? "" : this.Condition(mode, spec)
        reg := Map("full", full, "hotIf", criterion, "entries", [], "cb", "")
        reg["cb"] := (*) => this._Press(key)
        this._SetCriterion(criterion)
        try {
            Hotkey(full, reg["cb"], "On")
        } catch {
            throw ElementError(Lang("The hotkey %1% cannot be set!", full))
        } finally {
            HotIf()
        }
        this._regs[key] := reg
        return reg
    }

    ; A press: every armed trigger of the registration fires, each in its own guard, so an error of one does not stop
    ; the others. The list is copied first, because a trigger can be disarmed while the others fire.
    static _Press(key) {
        if (!this._regs.Has(key))
            return
        for entry in this._regs[key]["entries"].Clone()
            entry["fire"]()
    }

    static _SetCriterion(criterion) {
        if (criterion = "")
            HotIf()
        else
            HotIf(criterion)
    }

    ; The identity of a window condition for the registrations: the same window in the same match settings.
    static _SpecKey(spec) {
        return spec["winString"] "`n" spec["winText"] "`n" spec["excludeTitle"] "`n" spec["ExcludeText"] "`n"
            . spec["TitleMatchMode"] "`n" spec["FindHiddenText"] "`n" spec["FindHiddenWindow"]
    }

    ; A checkbox value as a truth value (1, a text other than "", "0" or "false"; an object is false).
    static _Truthy(value) => !IsObject(value) && value != "" && value != 0 && value != "0" && value != "false"
}
