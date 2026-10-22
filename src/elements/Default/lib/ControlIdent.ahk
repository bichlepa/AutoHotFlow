#Requires AutoHotkey v2.0
#Include ..\..\..\core\ElementError.ahk
#Include ..\..\..\core\Lang.ahk
#Include WindowIdent.ahk

; Control identification of the package Default (WI-0125, E0060): a control of a window is named by its text, its class
; (ClassNN) or its window handle, as v1 has it (Source_Elements/Default/common/Window functions.ahk,
; windowFunctions_getWindowAndControlID). The window part is WindowIdent. The window and control elements (Get and Set
; control text) use this file; their parameter names are those of v1.
;
; Parameters (names as in v1):
;   IdentifyControlBy: "Text" (the text of the control, matched with ControlTextMatchMode), "Class" (ClassNN, matched
;   exactly) or "ID" (the window handle of the control; no window parameters are needed, and the window parameters are
;   disabled in the settings), Control_identifier (the identifier), ControlTextMatchMode (1 start, 2 contains, 3 exact).
;
; Deliberate difference to v1 (MIGRATION M-0131): v1 applied ControlTextMatchMode only for the value "name", which the
; settings never store, so the match mode of the window was used for the text of a control. Here the text of a control
; uses ControlTextMatchMode, as the setting says.
class ControlIdent {
    ; The parameter list of a control identification, appended to p: the control fields, then the window fields with the
    ; control assistant (WindowIdent, opts.control).
    static AddIdentificationParameters(p, opts := {}) {
        p.Push({type: "Label", label: Lang("Control Identification")})
        p.Push({type: "Label", label: Lang("Method for control Identification"), size: "small"})
        p.Push({type: "Radio", id: "IdentifyControlBy", result: "enum", default: "Class"
            , choices: [Lang("Text in control"), Lang("Classname and instance number of the control"), Lang("Unique control ID")]
            , enum: ["Text", "Class", "ID"]})
        p.Push({type: "Label", label: Lang("Control Identification"), size: "small"})
        p.Push({type: "Radio", id: "ControlTextMatchMode", default: 2
            , choices: [Lang("Start with"), Lang("Contain anywhere"), Lang("Exactly")]})
        p.Push({type: "Edit", id: "Control_identifier", content: "String", WarnIfEmpty: true})
        WindowIdent.AddIdentificationParameters(p, {control: true, noExcludes: opts.HasProp("noExcludes") && opts.noExcludes})
        return p
    }

    ; The name part of an element with a control identification (v1 windowFunctions_generateWindowIdentificationName with
    ; the control lines first): the control, then the window (WindowIdent.Name).
    static Name(params) {
        text := ""
        ident := WindowIdent._Field(params, "Control_identifier")
        by := WindowIdent._Field(params, "IdentifyControlBy", "Class")
        if (by = "Text")
            text .= "`n" Lang("Control text %1%", ident)
        else if (by = "Class")
            text .= "`n" Lang("Control class %1%", ident)
        else if (by = "ID")
            text .= "`n" Lang("Control ID %1%", ident)
        return text WindowIdent.Name(params)
    }

    ; The window fields that the settings disable when the control is identified by its handle, and the checks of the
    ; settings (v1 windowFunctions_CheckSettings). params: the stored parameters.
    static CheckSettings(form, params) {
        by := ControlIdent.Mode(params)
        byId := (by = "ID")
        for id in ["TitleMatchMode", "Wintitle", "excludeTitle", "winText", "FindHiddenText", "ExcludeText"
            , "ahk_class", "ahk_exe", "ahk_id", "ahk_pid", "FindHiddenWindow"]
            form.Disable(id, byId)
        form.Enable("ControlTextMatchMode", by = "Text")
    }

    ; The identification of the parameters: "Text", "Class" or "ID" (the default of the setting is "Class").
    static Mode(params) {
        value := WindowIdent._Field(params, "IdentifyControlBy", "Class")
        if (value = "Text" || value = "Class" || value = "ID")
            return value
        throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "IdentifyControlBy", value))
    }

    ; Finds the window and the control of the evaluated parameters. Returns a Map: windowID (0 when there is no window of
    ; the identification, always 0 for the ID mode) and controlID (0 when the control is not there). Throws ElementError
    ; for a missing window specification (not for the ID mode) and an invalid parameter.
    static Find(params) {
        by := ControlIdent.Mode(params)
        ident := WindowIdent._Field(params, "Control_identifier")
        if (by = "ID") {
            ctl := ControlIdent._Handle(ident)
            return Map("windowID", 0, "controlID", ctl)
        }
        spec := WindowIdent.Spec(params)
        win := WindowIdent.Find(spec)
        if (win = 0)
            return Map("windowID", 0, "controlID", 0)
        if (by = "Text")
            SetTitleMatchMode(ControlIdent._MatchMode(params))
        else
            SetTitleMatchMode(3)                    ; a ClassNN is matched exactly, so "Edit1" does not find "Edit10"
        ctl := 0
        try {
            ctl := ControlGetHwnd(ident, "ahk_id " win)
        } catch TargetError {
            ctl := 0                                ; not in the window: the caller reports it
        }
        return Map("windowID", win, "controlID", ctl)
    }

    ; The match mode of the control text: 1 start, 2 contains, 3 exact (v1 radio without a result: the position).
    static _MatchMode(params) {
        mode := WindowIdent._Field(params, "ControlTextMatchMode", 2)
        if (mode = 1 || mode = 2 || mode = 3)
            return Integer(mode)
        throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "ControlTextMatchMode", mode))
    }

    ; Throws the v1 text when the control was not found: by ID, a missing window, or a missing control in the window.
    static RequireControl(p, found) {
        if (found["controlID"] != 0)
            return
        if (ControlIdent.Mode(p) = "ID")
            throw ElementError(Lang("Error! Seeked control does not exist"))
        if (found["windowID"] = 0)
            throw ElementError(Lang("Error! Seeked window does not exist"))
        throw ElementError(Lang("Error! Seeked control does not exist in the specified window"))
    }

    ; A window handle of the ID mode: the text must be a number, and the handle must belong to a window that exists.
    static _Handle(text) {
        if (!IsInteger(text))
            return 0
        hwnd := Integer(text)
        return DllCall("user32\IsWindow", "Ptr", hwnd, "Int") ? hwnd : 0
    }
}
