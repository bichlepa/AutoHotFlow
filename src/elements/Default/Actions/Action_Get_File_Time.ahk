#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Get file time of the package Default (WI-0121): stores the modification, creation or last access time of a file
; as a text YYYYMMDDHH24MISS (local time, as FileGetTime gives it). Specification: the help text of v1
; (help/en/Actions/Get_File_Time.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Get_file_time.ahk).
;
; A missing file ends with an exception (v1 text); a folder has a time as well and gives it (as v1). Worker element (the file access, ARCHITECTURE 2.3).
class Action_Get_File_Time extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Get File Time")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output Variable name")},
        {type: "Edit", id: "varname", default: "FileTime", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("File path")},
        {type: "File", id: "file", label: Lang("Select a file")},
        {type: "Label", label: Lang("Which time")},
        {type: "Radio", id: "TimeType", result: "enum", default: 1, choices: [Lang("Modification time"), Lang("Creation time"), Lang("Last access time")], enum: ["Modification", "Creation", "Access"]}
    ]

    static GenerateName(ctx, params) => Lang("Get File Time") FileOps.TimeName(TextOps.Par(params, "TimeType")) " - " TextOps.Par(params, "varname") " - " TextOps.Par(params, "file")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        if (FileExist(p.file) = "")
            throw ElementError(Lang("%1% '%2%' does not exist.", Lang("Source file"), p.file))
        try stamp := FileGetTime(p.file, FileOps.TimeLetter(p.TimeType))
        catch as err
            throw FileOps.Fail(Lang("Couldn't get file time of file '%1%'", p.file), FileOps.Code(err))
        FileOps.SetOutput(ctx, p.varname, stamp)
        ctx.Finish("normal")
    }
}
