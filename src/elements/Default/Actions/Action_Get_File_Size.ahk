#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Get file size of the package Default (WI-0121): stores the size of a file in bytes, kilobytes or megabytes.
; Specification: the help text of v1 (help/en/Actions/Get_File_Size.md). Class ID, parameter IDs, defaults and language keys
; are those of v1 (Source_Elements/Default/Actions/Get_file_size.ahk).
;
; FileGetSize rounds down to whole units ("K" and "M" in v2, as in v1). A folder and a missing file end with an exception.
; Worker element (the file access, ARCHITECTURE 2.3).
class Action_Get_File_Size extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Get File Size")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output Variable name")},
        {type: "Edit", id: "varname", default: "FileSize", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("File path")},
        {type: "File", id: "file", label: Lang("Select a file")},
        {type: "Label", label: Lang("Unit")},
        {type: "Radio", id: "Unit", result: "enum", default: 1, choices: [Lang("Bytes"), Lang("Kilobytes"), Lang("Megabytes")], enum: ["Bytes", "Kilobytes", "Megabytes"]}
    ]

    static GenerateName(ctx, params) => Lang("Get File Size") " - " TextOps.Par(params, "varname") " - " TextOps.Par(params, "file")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        attr := FileExist(p.file)
        if (attr = "")
            throw ElementError(Lang("%1% '%2%' does not exist.", Lang("Source file"), p.file))
        if (FileOps.IsFolder(attr))
            throw ElementError(Lang("%1% '%2%' is a folder.", Lang("Source file"), p.file))
        units := (p.Unit = "Kilobytes") ? "K" : (p.Unit = "Megabytes") ? "M" : ""
        try size := FileGetSize(p.file, units)
        catch as err
            throw FileOps.Fail(Lang("Couldn't get file size of file '%1%'", p.file), FileOps.Code(err))
        FileOps.SetOutput(ctx, p.varname, size)
        ctx.Finish("normal")
    }
}
