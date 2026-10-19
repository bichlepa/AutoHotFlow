#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\SettingsModel.ahk
#Include ..\core\Lang.ahk

; The model of the settings dialog (WI-0078, REQ-SET-010, REQ-SET-020, REQ-SET-050, REQ-SET-070, REQ-LNG-020): which keys
; the dialog shows, on which tab, and the check of the values the user typed or chose. It has no GUI code and sends nothing:
; the window (SettingsWindow) reads its controls into a Map key -> raw value, Collect checks them with the checks of
; SettingsModel (the same checks as the engine uses), and the manager sends the checked set with cmd.settings.set.
;
; Not in the dialog: the window positions (UI state). Start with Windows and run as administrator are on the General tab (WI-0079):
; switching the second one on asks the manager whether to restart now (ManagerModel, the question of the settings event).
;
; A field: Map("key", key, "tab", "general"|"flow"|"debug", "kind", "language"|"list"|"number"|"check"|"folder",
;   "label", Lang key, "items", Array of [value, Lang key] for "list", "note", Lang key of the hint or "").
class SettingsForm {
    static TABS := [Map("id", "general", "label", "General"), Map("id", "flow", "label", "Flow_settings")
        , Map("id", "debug", "label", "Debugging")]

    ; The items of the drop-down list of a log level: 0 to 3 (the v1 names, REQ-SET-050).
    static LOG_ITEMS := [[0, "Only_errors"], [1, "Some_logs"], [2, "Many_logs"], [3, "All_logs"]]

    static FIELDS := [
        Map("key", "language", "tab", "general", "kind", "language", "label", "Language", "note", ""),
        Map("key", "userLevel", "tab", "general", "kind", "list", "label", "Shown_elements", "note", ""
            , "items", [["Beginner", "Beginner_level"], ["Advanced", "Advanced_level"], ["Programmer", "Programmer_level"]]),
        Map("key", "workingDir", "tab", "general", "kind", "folder", "label", "Working_directory", "note", ""),
        Map("key", "notifyUnhandledErrors", "tab", "general", "kind", "check", "label", "Notify_unhandled_errors", "note", ""),
        Map("key", "startWithWindows", "tab", "general", "kind", "check", "label", "Start_with_windows"
            , "note", "Start_with_windows_note"),
        Map("key", "runAsAdmin", "tab", "general", "kind", "check", "label", "Run_as_admin", "note", "Run_as_admin_note"),

        Map("key", "executionPolicy", "tab", "flow", "kind", "list", "label", "Flow_execution_policy", "note", ""
            , "items", [["parallel", "Parallel_execution_of_multiple_instances"]
                , ["skip", "Skip_execution_when_an_instance_is_already_executing"]
                , ["wait", "Wait_until_the_currently_executing_instance_has_finished"]
                , ["stop", "Stop_the_currently_executing_instance_and_execute_afterwards"]]),
        Map("key", "workers", "tab", "flow", "kind", "number", "label", "Elements_waiting_at_once", "note", "From_1_to_16"),
        Map("key", "maxExecutionsPerMinute", "tab", "flow", "kind", "number", "label", "Max_executions_per_minute"
            , "note", "Zero_means_no_limit"),
        Map("key", "maxWaitingInstances", "tab", "flow", "kind", "number", "label", "Max_waiting_instances"
            , "note", "Zero_means_no_limit"),
        Map("key", "maxParallelInstances", "tab", "flow", "kind", "number", "label", "Max_parallel_instances"
            , "note", "Zero_means_no_limit"),

        Map("key", "logLevelApp", "tab", "debug", "kind", "list", "label", "App", "note", "", "items", SettingsForm.LOG_ITEMS),
        Map("key", "logLevelFlow", "tab", "debug", "kind", "list", "label", "Flow", "note", "", "items", SettingsForm.LOG_ITEMS),
        Map("key", "logLevelThread", "tab", "debug", "kind", "list", "label", "Thread", "note", "", "items", SettingsForm.LOG_ITEMS)]

    ; The keys the dialog shows, in the order of the fields.
    static Keys() {
        keys := []
        for field in SettingsForm.FIELDS
            keys.Push(field["key"])
        return keys
    }

    ; The fields of one tab, in order.
    static FieldsOf(tab) {
        out := []
        for field in SettingsForm.FIELDS {
            if (field["tab"] = tab)
                out.Push(field)
        }
        return out
    }

    ; The field of a key, or "" when the dialog does not show it.
    static FieldOf(key) {
        for field in SettingsForm.FIELDS {
            if (field["key"] = key)
                return field
        }
        return ""
    }

    ; The checked set of raw values (key -> the text or number of a control, or a value of a test). Only the keys of the dialog
    ; are taken; any other key is refused with its name. Returns Map(ok, partial, errors): partial is the Map of the checked
    ; values (key -> value, the form of SettingsModel), errors is a Map key -> the message of the check. Nothing is changed.
    ; ok is false when any value is refused; the partial is then not used.
    static Collect(raw) {
        out := Map("ok", true, "partial", Map(), "errors", Map())
        if (!(raw is Map)) {
            out["ok"] := false
            out["errors"]["settings"] := "settings must be an object"
            return out
        }
        for key, value in raw {
            if (SettingsForm.FieldOf(key) = "") {
                out["ok"] := false
                out["errors"][key] := "'" key "' is not a setting of the dialog"
                continue
            }
            try {
                out["partial"][key] := SettingsModel.Check(key, value)
            } catch as e {
                if (!(e is AhfError))
                    throw e
                out["ok"] := false
                out["errors"][key] := SettingsForm._Reason(e)     ; translated; the label names the key
            }
        }
        return out
    }

    ; The text of the refusal: one line per refused value, "<label>: <message>", the labels as given (the caller translates
    ; them). labelOf(key) returns the label of a key.
    ; The text of a refusal of a check: the translated reason when the check gave one (AhfError.reason, SettingsModel), the
    ; message without its "setting '<key>': " prefix otherwise.
    static _Reason(e) {
        if (!e.HasProp("reason"))
            return RegExReplace(e.Message, "^setting '[^']*': ", "")
        reason := e.reason
        if (reason.Length = 1)
            return Lang(reason[1])
        if (reason.Length = 2)
            return Lang(reason[1], reason[2])
        return Lang(reason[1], reason[2], reason[3])
    }

    ; The lines follow the order of the dialog (the fields), so that the first refused value of the screen is the first line.
    static ErrorText(errors, labelOf) {
        text := ""
        for key in SettingsForm.Keys() {
            if (errors.Has(key))
                text .= (text = "" ? "" : "`n") labelOf(key) ": " errors[key]
        }
        for key, message in errors {          ; a value that is not a field of the dialog comes last, under its own name
            if (SettingsForm.FieldOf(key) = "")
                text .= (text = "" ? "" : "`n") key ": " message
        }
        return text
    }
}
