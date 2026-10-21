#Requires AutoHotkey v2.0
#Include ..\..\..\core\ElementError.ahk
#Include ..\..\..\core\Lang.ahk

; Window identification of the package Default (WI-0064, E0060): the parameters of a window as v1 has them
; (Source_Elements/Default/common/Window functions.ahk), the match against them, and the conditions of a window
; that a hotkey or a window element uses. Shared by the trigger Trigger_Hotkey and the window elements and triggers of
; S0008. No hotkey code in it.
;
; The parameters of a window (names as in v1):
;   TitleMatchMode (1 start, 2 contains, 3 exact), Wintitle, excludeTitle, winText, ExcludeText,
;   ahk_class, ahk_exe, ahk_id, ahk_pid, FindHiddenText (0/1), FindHiddenWindow (0/1).
; The window is found by WinExist (or WinActive) with these, so the excludes are checked by the OS call itself.
class WindowIdent {
    ; The parameter list of the window identification, appended to p. opts.noExcludes leaves out the two excludes
    ; (v1 option of the same name). The button that imports a window (GetWindowInformation) is the editor's job (S0007).
    static AddIdentificationParameters(p, opts := {}) {
        noExcludes := opts.HasProp("noExcludes") && opts.noExcludes
        p.Push({type: "Label", label: Lang("Window identification")})
        p.Push({type: "Label", label: Lang("Title_of_Window"), size: "small"})
        p.Push({type: "Radio", id: "TitleMatchMode", default: 1, result: "enum"
            , choices: [Lang("Start with"), Lang("Contain anywhere"), Lang("Exactly")], enum: [1, 2, 3]})
        p.Push({type: "Edit", id: "Wintitle", content: "String"})
        if (!noExcludes) {
            p.Push({type: "Label", label: Lang("Exclude title"), size: "small"})
            p.Push({type: "Edit", id: "excludeTitle", content: "String"})
        }
        p.Push({type: "Label", label: Lang("Text_of_a_control_in_Window"), size: "small"})
        p.Push({type: "Edit", id: "winText", content: "String"})
        p.Push({type: "Checkbox", id: "FindHiddenText", default: 0, label: Lang("Detect hidden text")})
        if (!noExcludes) {
            p.Push({type: "Label", label: Lang("Exclude text of a control in window"), size: "small"})
            p.Push({type: "Edit", id: "ExcludeText", content: "String"})
        }
        p.Push({type: "Label", label: Lang("Window Class"), size: "small"})
        p.Push({type: "Edit", id: "ahk_class", content: "String"})
        p.Push({type: "Label", label: Lang("Process Name"), size: "small"})
        p.Push({type: "Edit", id: "ahk_exe", content: "String"})
        p.Push({type: "Label", label: Lang("Unique window ID"), size: "small"})
        p.Push({type: "Edit", id: "ahk_id", content: "String"})
        p.Push({type: "Label", label: Lang("Unique Process ID"), size: "small"})
        p.Push({type: "Edit", id: "ahk_pid", content: "String"})
        p.Push({type: "Label", label: Lang("Hidden window"), size: "small"})
        p.Push({type: "Checkbox", id: "FindHiddenWindow", default: 0, label: Lang("Detect hidden window")})
        p.Push({type: "Label", label: Lang("Assistant"), size: "small"})
        ; the assistant "window" takes the window under the mouse (WI-0110); its keys go to these parameters (the excludes
        ; are skipped when the element has none)
        p.Push({type: "Button", id: "GetWindowInformation", label: Lang("Import window identification"), assistant: "window"
            , map: {Wintitle: "Wintitle", ahk_class: "ahk_class", ahk_exe: "ahk_exe", excludeTitle: "excludeTitle"
                , ExcludeText: "ExcludeText", ahk_id: "ahk_id", ahk_pid: "ahk_pid"}})
        return p
    }

    ; The evaluated parameters as a window spec (a Map): the WinExist arguments and the settings of the match.
    ; Throws ElementError with the v1 texts: no window specified, an invalid hidden-detection value.
    static Spec(params) {
        winString := WindowIdent._Field(params, "Wintitle")
        for key in ["ahk_class", "ahk_id", "ahk_pid", "ahk_exe"] {
            value := WindowIdent._Field(params, key)
            if (value != "")
                winString .= " " key " " value
        }
        winText := WindowIdent._Field(params, "winText")
        if (winString = "" && winText = "")
            throw ElementError(Lang("No window specified"))
        mode := WindowIdent._Field(params, "TitleMatchMode", 1)
        if !(mode = 1 || mode = 2 || mode = 3)
            throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "TitleMatchMode", mode))
        return Map("winString", winString, "winText", winText, "TitleMatchMode", Integer(mode)
            , "excludeTitle", WindowIdent._Field(params, "excludeTitle")
            , "ExcludeText", WindowIdent._Field(params, "ExcludeText")
            , "FindHiddenText", WindowIdent._Flag(params, "FindHiddenText", "findhiddentext")
            , "FindHiddenWindow", WindowIdent._Flag(params, "FindHiddenWindow", "findhiddenwindow"))
    }

    ; The window that the spec identifies, as a window ID, or 0 when there is none. Sets the title match mode and the
    ; hidden detection first (global settings of the thread, set again for every call).
    static Find(spec) {
        WindowIdent._SetMatch(spec)
        return WinExist(spec["winString"], spec["winText"], spec["excludeTitle"], spec["ExcludeText"])
    }

    ; True when the identified window is the active one (WinActive with the same arguments).
    static IsActive(spec) {
        WindowIdent._SetMatch(spec)
        return WinActive(spec["winString"], spec["winText"], spec["excludeTitle"], spec["ExcludeText"]) != 0
    }

    static _SetMatch(spec) {
        SetTitleMatchMode(spec["TitleMatchMode"])
        DetectHiddenText(spec["FindHiddenText"])
        DetectHiddenWindows(spec["FindHiddenWindow"])
    }

    ; A text parameter, "" when missing; an object value is "".
    static _Field(params, key, default := "") {
        if (!params.HasProp(key))
            return default
        value := params.%key%
        if (IsObject(value))
            return default
        return String(value)
    }

    ; A checkbox as 0 or 1 (v1 checkbox values); any other value is refused like v1.
    static _Flag(params, key, v1Name) {
        value := WindowIdent._Field(params, key, 0)
        if (value = "" || value = "0" || value = "false")
            return 0
        if (value = "1" || value = "true")
            return 1
        throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", v1Name, value))
    }
}
