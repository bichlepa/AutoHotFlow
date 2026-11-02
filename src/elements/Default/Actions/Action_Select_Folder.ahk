#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\TextOps.ahk

; Action Select folder of the package Default (WI-0128, REQ-ELM-270): shows the standard folder dialog and sets the output
; variable to the chosen folder. Specification: the help text of v1 (help/en/Actions/Select_Folder.md), the parameters,
; defaults and language keys of v1 (Source_Elements/Default/Actions/Select_folder.ahk). Class ID and parameter IDs are
; those of v1.
;
; Worker element (ARCHITECTURE 2.3): the dialog blocks until the user answers. DirSelect (ELEMENT-API-V2 3.3) gets the
; options 1 (a button to create a folder) and 2 (an edit field for the folder name), and the starting folder with a leading
; asterisk when the user may navigate upward (v1 "Permit to navigate upward"). A cancelled dialog ends the element with an
; exception, as in v1. v1 had a check of the settings that tested the fields of the file dialog; it changed nothing here,
; so this class has no CheckSettings.
class Action_Select_Folder extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Select_Folder")
    static Category() => Lang("User_interaction")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "selectedFolder", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Prompt")},
        {type: "Edit", id: "title", default: Lang("Select a folder"), content: "String"},
        {type: "Label", label: Lang("Root directory")},
        {type: "Folder", id: "folder"},
        {type: "Label", label: Lang("Options")},
        {type: "Checkbox", id: "AllowUpward", default: 1, label: Lang("Permit to navigate upward")},
        {type: "Checkbox", id: "ButtonNewFolder", default: 0, label: Lang("Show a button to create a new folder")},
        {type: "Checkbox", id: "EditField", default: 0, label: Lang("Show an edit field to type in the folder name")}
    ]

    ; "Select folder - name - root directory" (v1 Element_GenerateName_Action_Select_Folder)
    static GenerateName(ctx, params) => Lang("Select_Folder") " - " TextOps.Par(params, "Varname") " - " TextOps.Par(params, "folder")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        options := (DialogOps.Truthy(p.ButtonNewFolder) ? 1 : 0) + (DialogOps.Truthy(p.EditField) ? 2 : 0)
        root := DialogOps.Truthy(p.AllowUpward) ? "*" p.folder : p.folder
        chosen := Dialogs.DirSelect(root, options, p.title)
        if (chosen = "")                          ; cancelled, or the system refused to show the dialog (as v1)
            throw ElementError(Lang("User dismissed the dialog without selecting a folder or system refused to show the dialog."))
        if (!ctx.SetVar(p.Varname, chosen))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
