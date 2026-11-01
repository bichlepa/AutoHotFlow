#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\WindowIdent.ahk

; Trigger Hotstring of the package Default (WI-0131, REQ-TRG-230, M-0162, M-0163): fires when the user types the text,
; and optionally types a replacement for it. Parameters, GenerateName and language keys are those of v1
; (Source_Elements/Default/Triggers/Hotstring.ahk). Runs in the trigger host (Mode trigger).
;
; The hotstring is a callback (Hotstring with a function object). The replacement is not a hotstring option: the trigger
; sends it itself, through SystemOps.Send with the send mode of the element (M-0162), before it fires. With automatic
; backspacing the ending character is sent again after the replacement, unless it is omitted, as in v1.
;
; The registrations are shared as the hotkeys are (Trigger_Hotkey): the hotstring text with its options, the window
; condition and the window identification name one registration with the armed triggers on it. A press runs every armed
; trigger, each sends its own replacement; the last Disable turns the hotstring off (M-0163).
class Trigger_Hotstring extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"

    ; The values of UseWindow and SendMode, in the order of their choices (v1 enums).
    static WINDOW_MODES := ["Everywhere", "WindowIsActive", "WindowExists", "WindowIsNotActive", "WindowNotExists"]
    static SEND_MODES := ["Input", "Event", "Play"]

    ; The window parameters that the element shows only when a window is used (v1 CheckSettings).
    static WINDOW_PARAMS := ["TitleMatchMode", "Wintitle", "excludeTitle", "FindHiddenText", "winText", "ExcludeText"
        , "ahk_class", "ahk_exe", "ahk_id", "ahk_pid", "FindHiddenWindow", "GetWindowInformation"]

    ; Registrations in this host: key -> Map("full", text, "hotIf", criterion or "", "entries", Array of Map("ctx", ctx,
    ; "fire", function of the press), "cb", callback). See Trigger_Hotkey for the same structure.
    static _regs := Map()

    static Name() => Lang("Hotstring")
    static Category() => Lang("User_interaction")

    static Parameters(ctx) {
        list := [
            {type: "Label", label: Lang("Hotstring")},
            {type: "Edit", id: "hotstring", default: "btw", content: ["RawString", "String"], contentID: "IsRaw"
                , contentDefault: "string", WarnIfEmpty: true},
            {type: "Label", label: Lang("Options")},
            {type: "Checkbox", id: "RequireEndingCharacter", default: 1, label: Lang("Require an ending character")},
            {type: "Checkbox", id: "OmitEndingCharacter", default: 0
                , label: Lang("Omit the ending character after replacemenet")},
            {type: "Checkbox", id: "TriggerInsideAnotherWord", default: 0, label: Lang("Trigger inside another word")},
            {type: "Checkbox", id: "CaseSensitive", default: 0, label: Lang("Case sensitive")},
            {type: "Checkbox", id: "AutomaticBackspacing", default: 1
                , label: Lang("Backspace automatically the entered hotstring")},
            {type: "Checkbox", id: "ResetRecognizer", default: 0
                , label: Lang("Reset hotstring recognizer after each triggering")},
            {type: "Label", label: Lang("Replace text")},
            {type: "Checkbox", id: "RawMode", default: 0, label: Lang("Raw mode")},
            {type: "Edit", id: "KeysToSend", default: "by the way", content: ["RawString", "String"]
                , contentID: "KeysToSendContentType", ContentDefault: "String"},
            {type: "Label", label: Lang("Send mode")},
            {type: "Radio", id: "SendMode", default: "Input", choices: [Lang("Input mode"), Lang("Event mode"), Lang("Play mode")]
                , result: "enum", enum: this.SEND_MODES},
            {type: "Label", label: Lang("Scope")},
            {type: "Label", size: "small", label: Lang("Where should the hotstring be active?")},
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

    ; "Hotstring - btw - by the way" (v1 Element_GenerateName_Trigger_Hotstring).
    static GenerateName(ctx, params) {
        hotstring := params.HasProp("hotstring") ? params.hotstring : ""
        keys := params.HasProp("KeysToSend") ? params.KeysToSend : ""
        return Lang("Hotstring") " - " (IsObject(hotstring) ? "" : hotstring) " - " (IsObject(keys) ? "" : keys)
    }

    ; v1 Element_CheckSettings_Trigger_Hotstring: the omit option needs an ending character, the recognizer reset is
    ; forced with automatic backspacing, and the window parameters are shown only for a window condition.
    static CheckSettings(form, params, staticValues) {
        form.Enable("OmitEndingCharacter", this._Truthy(params.HasProp("RequireEndingCharacter") ? params.RequireEndingCharacter : 0))
        auto := this._Truthy(params.HasProp("AutomaticBackspacing") ? params.AutomaticBackspacing : 0)
        form.Disable("ResetRecognizer", auto)
        if (auto)
            form.SetValue("ResetRecognizer", 1)
        useWindow := params.HasProp("UseWindow") ? params.UseWindow : ""
        showWindow := useWindow = "WindowIsActive" || useWindow = "WindowExists" || useWindow = "WindowIsNotActive"
            || useWindow = "WindowNotExists"
        for id in this.WINDOW_PARAMS
            form.Enable(id, showWindow)
    }

    ; Arms the trigger: the hotstring text with its options and the window condition name the registration. The first
    ; trigger with them sets the hotstring; the trigger joins the list. An invalid hotstring or one the system refuses is
    ; an ElementError with the v1 text. The state is kept before the registration, so Disable can cope with a failed Enable.
    static Enable(ctx, params) {
        full := this.FullText(params)
        mode := this.ModeOf(params)
        spec := (mode = "Everywhere") ? "" : WindowIdent.Spec(params)
        key := full "`n" mode "`n" (spec = "" ? "" : this._SpecKey(spec))
        ctx.State.regKey := key
        ctx.State.full := full
        sendMode := this.SendModeOf(params)
        keys := this.KeysOf(params)
        sendEnding := !this._Truthy(params.HasProp("OmitEndingCharacter") ? params.OmitEndingCharacter : 0)
            && this._Truthy(params.HasProp("AutomaticBackspacing") ? params.AutomaticBackspacing : 0)
        fire := ctx.Guard((endChar) => this._Fire(ctx, keys, sendMode, sendEnding, endChar))
        reg := this._regs.Has(key) ? this._regs[key] : this._Register(key, full, mode, spec)
        reg["entries"].Push(Map("ctx", ctx, "fire", fire))
        return Lang("The hotkey %1% was set.", full)
    }

    ; Removes the trigger from its registration. The hotstring is turned off when no trigger is left on it, with the same
    ; criterion as when it was set. Also called after a failed Enable: then nothing happens.
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
            Hotstring(reg["full"], , "Off")
        } finally {
            HotIf()
        }
    }

    ; The thread variables after the event: A_EndChar (the ending character) and A_Hotstring (the text of the hotstring),
    ; as the v1 code sets them. Pure function.
    static TriggerVariables(params, data) {
        endChar := (IsObject(data) && data.Has("endChar")) ? data["endChar"] : ""
        return Map("A_EndChar", endChar, "A_Hotstring", params.HasProp("hotstring") ? params.hotstring : "")
    }

    ; The hotstring with its options, as AutoHotkey v2 writes it: ":" options ":" text (v1 options: * for no ending
    ; character, ? inside a word, C case sensitive, B0 no backspacing, Z reset). Throws ElementError for an empty text.
    static FullText(params) {
        text := params.HasProp("hotstring") ? params.hotstring : ""
        if (IsObject(text) || text = "")
            throw ElementError(Lang("The hotstring %1% cannot be set!", IsObject(text) ? "" : text))
        opts := ""
        if (!this._Truthy(params.HasProp("RequireEndingCharacter") ? params.RequireEndingCharacter : 0))
            opts .= "*"
        if (this._Truthy(params.HasProp("TriggerInsideAnotherWord") ? params.TriggerInsideAnotherWord : 0))
            opts .= "?"
        if (this._Truthy(params.HasProp("CaseSensitive") ? params.CaseSensitive : 0))
            opts .= "C"
        if (!this._Truthy(params.HasProp("AutomaticBackspacing") ? params.AutomaticBackspacing : 0))
            opts .= "B0"
        if (this._Truthy(params.HasProp("ResetRecognizer") ? params.ResetRecognizer : 0))
            opts .= "Z"
        return ":" opts ":" String(text)
    }

    ; The text the trigger sends before it fires: "" for none; {Raw} in front in raw mode (v1 wrote {raw} for AHK v1).
    static KeysOf(params) {
        keys := params.HasProp("KeysToSend") ? params.KeysToSend : ""
        if (IsObject(keys) || keys = "")
            return ""
        if (this._Truthy(params.HasProp("RawMode") ? params.RawMode : 0))
            return "{Raw}" String(keys)
        return String(keys)
    }

    ; The send mode of the replacement: one of SEND_MODES. Throws ElementError with the v1 text for another value.
    static SendModeOf(params) {
        value := params.HasProp("SendMode") ? params.SendMode : "Input"
        for name in this.SEND_MODES {
            if (name = value)
                return name
        }
        throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "SendMode", IsObject(value) ? "" : value))
    }

    ; The window condition of the parameters: "Everywhere" or one of the four window values (as Trigger_Hotkey: a
    ; radio index is accepted, as v1 stores it). Throws ElementError for an unknown value.
    static ModeOf(params) {
        value := params.HasProp("UseWindow") ? params.UseWindow : "Everywhere"
        if (!IsObject(value) && IsInteger(value) && value >= 1 && value <= this.WINDOW_MODES.Length)
            return this.WINDOW_MODES[Integer(value)]
        for name in this.WINDOW_MODES {
            if (name = value)
                return name
        }
        throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "UseWindow", IsObject(value) ? "" : value))
    }

    ; The criterion function of a window condition (HotIf form), or "" for Everywhere (as Trigger_Hotkey).
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

    ; Sets the hotstring with its criterion and keeps the registration. The criterion in effect is reset afterwards.
    static _Register(key, full, mode, spec) {
        criterion := (mode = "Everywhere") ? "" : this.Condition(mode, spec)
        reg := Map("full", full, "hotIf", criterion, "entries", [], "cb", "")
        reg["cb"] := (*) => this._Press(key)
        this._SetCriterion(criterion)
        try {
            Hotstring(full, reg["cb"], "On")
        } catch {
            throw ElementError(Lang("The hotstring %1% cannot be set!", full))
        } finally {
            HotIf()
        }
        this._regs[key] := reg
        return reg
    }

    ; A press: the ending character is read first (A_EndChar is valid only in this thread); every armed trigger of the
    ; registration runs in its own guard. The list is copied, because a trigger can be disarmed meanwhile.
    static _Press(key) {
        if (!this._regs.Has(key))
            return
        endChar := A_EndChar
        for entry in this._regs[key]["entries"].Clone()
            entry["fire"](endChar)
    }

    ; One trigger of a press: sends its replacement (with the ending character when it is kept), then fires.
    static _Fire(ctx, keys, sendMode, sendEnding, endChar) {
        if (keys != "")
            SystemOps.Send(sendEnding ? keys endChar : keys, sendMode)
        ctx.Fire(Map("endChar", endChar))
    }

    static _SetCriterion(criterion) {
        if (criterion = "")
            HotIf()
        else
            HotIf(criterion)
    }

    ; The identity of a window condition for the registrations (as Trigger_Hotkey).
    static _SpecKey(spec) {
        return spec["winString"] "`n" spec["winText"] "`n" spec["excludeTitle"] "`n" spec["ExcludeText"] "`n"
            . spec["TitleMatchMode"] "`n" spec["FindHiddenText"] "`n" spec["FindHiddenWindow"]
    }

    ; A checkbox value as a truth value (as Trigger_Hotkey).
    static _Truthy(value) => !IsObject(value) && value != "" && value != 0 && value != "0" && value != "false"
}
