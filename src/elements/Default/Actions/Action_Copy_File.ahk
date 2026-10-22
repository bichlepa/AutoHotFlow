#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Copy file of the package Default (WI-0120): copies one file or the files of a wildcard pattern to a file or a
; folder. Specification: the help text of v1 (help/en/Actions/Copy_file.md). Class ID, parameter IDs, defaults and language
; keys are those of v1 (Source_Elements/Default/Actions/Copy_file.ahk).
;
; Worker element (the file access, ARCHITECTURE 2.3). A wildcard copies every matching file; the error counts the files
; that failed (AutoHotkey Error.Extra, v1 ErrorLevel). Without Overwrite an existing destination file is an error, as in v1.
class Action_Copy_File extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Copy File")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Source file")},
        {type: "File", id: "file", label: Lang("Select a file")},
        {type: "Label", label: Lang("Destination file or folder")},
        {type: "Folder", id: "destFile", label: Lang("Select a file or folder")},
        {type: "Label", label: Lang("Overwrite")},
        {type: "Checkbox", id: "Overwrite", default: 0, label: Lang("Overwrite existing files")}
    ]

    static GenerateName(ctx, params) => Lang("Copy File") " - " TextOps.Par(params, "file") " - " TextOps.Par(params, "destFile")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        FileOps.CheckFileSource(p.file)
        overwrite := DialogOps.Truthy(p.Overwrite)
        try FileCopy(p.file, p.destFile, overwrite ? 1 : 0)
        catch as err {
            code := FileOps.Code(err)
            if (!overwrite && FileOps.ExistsAsFile(p.destFile))
                throw ElementError(Lang("%1% '%2%' already exists.", Lang("Destination file"), p.destFile))
            throw FileOps.Fail(Lang("%1% files could not be copied from '%2%' to '%3%'", FileOps.Failures(err), p.file, p.destFile), code)
        }
        ctx.Finish("normal")
    }
}
