#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Set file attributes of the package Default (WI-0121): sets the attributes of the files of a path or of a wildcard
; pattern, folders and subfolders as the options say. Specification: the help text of v1 (help/en/Actions/Set_file_attributes.md).
; Class ID, parameter IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Set_file_attributes.ahk).
;
; Each attribute is a tri-state checkbox (1 sets it, 0 clears it, -1 leaves it alone, as v1). The attribute text is built
; in the v2 syntax of FileSetAttrib ("+R-A..."). Nothing is changed when no attribute is chosen (MIGRATION M-0125).
; Worker element (the file access, ARCHITECTURE 2.3).
class Action_Set_file_attributes extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Set file attributes")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("File path")},
        {type: "File", id: "file", label: Lang("Select a file")},
        {type: "Label", label: Lang("Attributes")},
        {type: "CheckBox", id: "ReadOnly", default: -1, label: Lang("Read only"), gray: true},
        {type: "CheckBox", id: "Archive", default: -1, label: Lang("Archive"), gray: true},
        {type: "CheckBox", id: "System", default: -1, label: Lang("System"), gray: true},
        {type: "CheckBox", id: "Hidden", default: -1, label: Lang("Hidden"), gray: true},
        {type: "CheckBox", id: "Offline", default: -1, label: Lang("Offline"), gray: true},
        {type: "CheckBox", id: "Temporary", default: -1, label: Lang("Temporary"), gray: true},
        {type: "Label", label: Lang("Options")},
        {type: "Radio", id: "OperateOnWhat", default: 1, choices: [Lang("Operate on files"), Lang("Operate on files and folders"), Lang("Operate on folders")], result: "enum", enum: ["Files", "FilesAndFolders", "Folders"]},
        {type: "Checkbox", id: "Recurse", default: 0, label: Lang("Recurse into subfolders")}
    ]

    static GenerateName(ctx, params) => Lang("Set file attributes")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        changes := this._Change("R", p.ReadOnly) this._Change("A", p.Archive)
        changes .= this._Change("S", p.System) this._Change("H", p.Hidden)
        changes .= this._Change("O", p.Offline) this._Change("T", p.Temporary)
        if (changes = "") {
            ctx.Finish("normal")
            return
        }
        ; FileSetAttrib throws only when a file it found could not be changed: a path without a match is checked here (v1 text)
        if (FileExist(p.file) = "")
            throw ElementError(Lang("File '%1%' does not exist", p.file))
        try FileSetAttrib(changes, p.file, FileOps.Mode(p.OperateOnWhat, DialogOps.Truthy(p.Recurse)))
        catch as err
            throw FileOps.Fail(Lang("Attributes of file '%1%' could not be changed", p.file), FileOps.Code(err))
        ctx.Finish("normal")
    }

    ; The part of the attribute text for one attribute: "+X" for 1, "-X" for 0, "" otherwise (left alone).
    static _Change(letter, value) {
        value := String(value)
        if (value = "1")
            return "+" letter
        if (value = "0")
            return "-" letter
        return ""
    }
}
