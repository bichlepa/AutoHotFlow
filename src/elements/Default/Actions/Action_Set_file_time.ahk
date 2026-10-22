#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Set file time of the package Default (WI-0121): sets the modification, creation or last access time of the files
; of a path or of a wildcard pattern. Specification: the help text of v1 (help/en/Actions/Set_file_time.md). Class ID,
; parameter IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Set_file_time.ahk).
;
; The new time is a text YYYYMMDDHH24MISS (a part of it is allowed, as in v2 IsTime); a text that is not a time ends with
; an exception before anything is changed. Worker element (the file access, ARCHITECTURE 2.3).
class Action_Set_file_time extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Set file time")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("File path")},
        {type: "File", id: "file", label: Lang("Select a file"), options: 8},
        {type: "Label", label: Lang("New Time")},
        {type: "Edit", id: "time", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Which time")},
        {type: "Radio", id: "TimeType", result: "enum", default: 1, choices: [Lang("Modification time"), Lang("Creation time"), Lang("Last access time")], enum: ["Modification", "Creation", "Access"]},
        {type: "Label", label: Lang("Options")},
        {type: "Radio", id: "OperateOnWhat", default: 1, choices: [Lang("Operate on files"), Lang("Operate on files and folders"), Lang("Operate on folders")], result: "enum", enum: ["Files", "FilesAndFolders", "Folders"]},
        {type: "Checkbox", id: "Recurse", default: 0, label: Lang("Recurse into subfolders")}
    ]

    static GenerateName(ctx, params) => Lang("Set file time") FileOps.TimeName(TextOps.Par(params, "TimeType")) " - " TextOps.Par(params, "time") " - " TextOps.Par(params, "file")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        FileOps.Guard(Lang("File path"), TextOps.Par(params, "file"), p.file)     ; a drive or the whole drive is refused
        FileOps.GuardWorkingDir(p.file, ctx.GetVar("A_WorkingDir"))
        if (!IsTime(p.time))
            throw ElementError(Lang("Timestamp '%1%' is not valid.", p.time))
        ; FileSetTime throws only when a file it found could not be changed: a path without a match is checked here (v1 text)
        if (FileExist(p.file) = "")
            throw ElementError(Lang("File '%1%' does not exist", p.file))
        try FileSetTime(p.time, p.file, FileOps.TimeLetter(p.TimeType), FileOps.Mode(p.OperateOnWhat, DialogOps.Truthy(p.Recurse)))
        catch as err
            throw FileOps.Fail(Lang("Attributes of file '%1%' could not be changed", p.file), FileOps.Code(err))
        ctx.Finish("normal")
    }
}
