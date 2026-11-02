#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\TextOps.ahk

; Action Select file of the package Default (WI-0128, REQ-ELM-270): shows the standard file dialog and sets the output
; variable to the chosen file, or to a list of the chosen files (Allow to select multiple files). Specification: the help
; text of v1 (help/en/Actions/Select_file.md), the parameters, defaults and language keys of v1
; (Source_Elements/Default/Actions/Select_file.ahk). Class ID and parameter IDs are those of v1.
;
; Worker element (ARCHITECTURE 2.3): the dialog blocks until the user answers. Options (FileSelect, ELEMENT-API-V2 3.3):
; the letter M (several files, the result is an Array of the full paths), the letter S (a Save button instead of Open),
; and the numbers 1 (file must exist), 2 (path must exist), 8 (prompt to create), 16 (prompt to overwrite) and 32 (do not
; resolve shortcuts), added up as in v1. A cancelled dialog ends the element with an exception, as in v1.
class Action_Select_file extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Select_file")
    static Category() => Lang("User_interaction")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "selectedFiles", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Prompt")},
        {type: "Edit", id: "title", default: Lang("Select a file"), content: "String"},
        {type: "Label", label: Lang("Root directory")},
        {type: "Folder", id: "folder"},
        {type: "Label", label: Lang("Filter")},
        {type: "Edit", id: "filter", default: Lang("Any files") " (*.*)", content: "String"},
        {type: "Label", label: Lang("Options")},
        {type: "Checkbox", id: "MultiSelect", default: 0, label: Lang("Allow to select multiple files")},
        {type: "Checkbox", id: "SaveButton", default: 0, label: Lang("'Save' button instead of an 'Open' button")},
        {type: "Checkbox", id: "fileMustExist", default: 0, label: Lang("File must exist")},
        {type: "Checkbox", id: "PathMustExist", default: 0, label: Lang("Path must exist")},
        {type: "Checkbox", id: "PromptNewFile", default: 0, label: Lang("Prompt to create new file")},
        {type: "Checkbox", id: "PromptOverwriteFile", default: 0, label: Lang("Prompt to overwrite file")},
        {type: "Checkbox", id: "NoShortcutTarget", default: 0, label: Lang("Don't resolve shortcuts to their targets")}
    ]

    ; "Select file - name - root directory" (v1 Element_GenerateName_Action_Select_file)
    static GenerateName(ctx, params) => Lang("Select_file") " - " TextOps.Par(params, "Varname") " - " TextOps.Par(params, "folder")

    ; v1 Element_CheckSettings_Action_Select_file: several files exclude the Save button, and the Save button does not need
    ; an existing file.
    static CheckSettings(form, params, staticValues) {
        multi := DialogOps.Truthy(TextOps.Par(params, "MultiSelect"))
        save := DialogOps.Truthy(TextOps.Par(params, "SaveButton"))
        form.Disable("SaveButton", multi)
        if (multi)
            form.SetValue("SaveButton", 0)
        form.Disable("fileMustExist", save)
        if (save)
            form.SetValue("fileMustExist", 0)
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        options := this.Options(p)
        chosen := Dialogs.FileSelect(options, p.folder, p.title, p.filter)
        if (!IsObject(chosen) && chosen = "")     ; cancelled, or the system refused to show the dialog (as v1)
            throw ElementError(Lang("User dismissed the dialog without selecting a file or system refused to show the dialog."))
        if (!ctx.SetVar(p.Varname, chosen))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }

    ; The options text of FileSelect for the flags of the parameters (v1 numbers and letters).
    static Options(p) {
        flags := 0
        if (DialogOps.Truthy(p.fileMustExist))
            flags += 1
        if (DialogOps.Truthy(p.PathMustExist))
            flags += 2
        if (DialogOps.Truthy(p.PromptNewFile))
            flags += 8
        if (DialogOps.Truthy(p.PromptOverwriteFile))
            flags += 16
        if (DialogOps.Truthy(p.NoShortcutTarget))
            flags += 32
        text := ""
        if (DialogOps.Truthy(p.SaveButton))
            text .= "S"
        if (DialogOps.Truthy(p.MultiSelect))
            text .= "M"
        return text flags
    }
}
