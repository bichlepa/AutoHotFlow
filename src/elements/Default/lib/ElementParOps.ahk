#Requires AutoHotkey v2.0

; The parameter list of Action_Set_element_parameter (WI-0129, v1 Set_element_parameter.ahk, CheckSettings): which value
; control shows the parameter of another element, and which choices it has. The control names are those of v1, so that the
; parameter IDs of v1 flows ("newParameterValueEdit/Text") keep their meaning. Pure functions: no context, no engine.
;
; A parameter choice is "<control>/<parameter ID>" (the enum value of the drop-down parameterID). A parameter of another
; element with a type that has no control of its own (v1: "not supported") is not in the list. v2 differences (M-0161):
; hotkey parameters get the text control (v1 offered a file picker), and the content type of a parameter (v1 "Type of
; parameter") is not offered: the value is stored with the content of its own control.
class ElementParOps {
    static CONTROLS := ["newParameterValueEdit", "newParameterValueCheckbox", "newParameterValueCheckboxGray"
        , "newParameterValueDropDown", "newParameterValueComboBox", "newParameterValueMultilineEdit"
        , "newParameterValueListBox", "newParameterValueFile", "newParameterValueFolder", "newParameterValueWeekdays"
        , "newParameterValueDateAndTime"]

    ; True if the name is one of the value controls.
    static IsControl(control) {
        for name in ElementParOps.CONTROLS {
            if (StrLower(name) = StrLower(control))
                return true
        }
        return false
    }

    ; The value control for a parameter of the given type (case-insensitive), "" if the type has none. gray: a checkbox
    ; that v1 showed grayed (its own control).
    static ControlOf(type, gray := false) {
        switch StrLower(String(type)) {
            case "edit", "slider", "hotkey":
                return "newParameterValueEdit"
            case "multilineedit":
                return "newParameterValueMultilineEdit"
            case "checkbox":
                return gray ? "newParameterValueCheckboxGray" : "newParameterValueCheckbox"
            case "radio", "dropdown":
                return "newParameterValueDropDown"
            case "combobox":
                return "newParameterValueComboBox"
            case "listbox":
                return "newParameterValueListBox"
            case "file":
                return "newParameterValueFile"
            case "folder":
                return "newParameterValueFolder"
            case "weekdays":
                return "newParameterValueWeekdays"
            case "dateandtime":
                return "newParameterValueDateAndTime"
            default:
                return ""
        }
    }

    ; The entries of the parameter list of a class (its Parameters(ctx) fields): one Map per parameter ID, in the order of
    ; the description, with id, control, name (the label before the field, or its own label for a checkbox), choices
    ; (an Array, or "" for a control without choices) and enum (the values of the choices, or ""). Labels and buttons are
    ; skipped. The enum of a drop-down follows the result of the field as v1 did: "enum" the given enum values, "string"
    ; the choices, "number" (or none) the 1-based indexes.
    static Entries(fields) {
        out := []
        if (!(fields is Array))
            return out
        lastLabel := ""
        for spec in fields {
            type := StrLower(String(ElementParOps.Field(spec, "type", "")))
            if (type = "label") {
                lastLabel := String(ElementParOps.Field(spec, "label", ""))
                continue
            }
            if (type = "button")
                continue
            control := ElementParOps.ControlOf(type, ElementParOps.Truthy(ElementParOps.Field(spec, "gray", 0)))
            if (control = "")
                continue
            ids := ElementParOps.Field(spec, "id", "")
            if (!(ids is Array))
                ids := (IsObject(ids) || ids = "") ? [] : [ids]
            name := (type = "checkbox") ? String(ElementParOps.Field(spec, "label", lastLabel)) : lastLabel
            choices := ""
            enum := ""
            if (control = "newParameterValueDropDown" || control = "newParameterValueComboBox"
                || control = "newParameterValueListBox") {
                choices := ElementParOps.Field(spec, "choices", [])
                if (!(choices is Array))
                    choices := []
                result := StrLower(String(ElementParOps.Field(spec, "result", "")))
                if (control = "newParameterValueComboBox" && result != "number") {
                    enum := choices.Clone()          ; a combo box holds the text: v1 "string" and the default
                } else if (result = "enum") {
                    enum := ElementParOps.Field(spec, "enum", [])
                } else if (result = "string") {
                    enum := choices.Clone()
                } else {
                    enum := []
                    loop choices.Length
                        enum.Push(A_Index)
                }
            }
            for id in ids
                out.Push(Map("id", String(id), "control", control, "name", name, "choices", choices, "enum", enum))
        }
        return out
    }

    ; The control and the parameter ID of a choice "<control>/<ID>": Array(control, ID); ["", ""] if it has no "/".
    static Split(choice) {
        pos := InStr(choice, "/")
        return pos ? [SubStr(choice, 1, pos - 1), SubStr(choice, pos + 1)] : ["", ""]
    }

    ; The text of a field of a field description (an object literal or a Map), default if it has none.
    static Field(spec, name, default) {
        if (spec is Map)
            return spec.Has(name) ? spec[name] : default
        if (IsObject(spec) && spec.HasProp(name))
            return spec.%name%
        return default
    }

    ; A checkbox value: on for 1, "1", "true" and any other true value.
    static Truthy(value) => !IsObject(value) && value != "" && value != 0 && value != "0" && StrLower(String(value)) != "false"
}
