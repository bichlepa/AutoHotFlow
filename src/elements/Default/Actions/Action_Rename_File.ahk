#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Rename file of the package Default (WI-0120): gives one file a new name in its folder. Specification: the help text
; of v1 (help/en/Actions/Rename_file.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Rename_file.ahk).
;
; Worker element (the file access, ARCHITECTURE 2.3). The new name is a name, not a path: the file stays in its folder.
; A wildcard is an error (one file is renamed). An existing file with the new name is never overwritten (as v1).
class Action_Rename_File extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Rename File")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Source file")},
        {type: "File", id: "file", label: Lang("Select a file")},
        {type: "Label", label: Lang("New file name")},
        {type: "Edit", id: "newName", default: Lang("Renamed") ".txt", content: "String", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("Rename File") " - " TextOps.Par(params, "file") " - " TextOps.Par(params, "newName")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        FileOps.Guard(Lang("Source file"), TextOps.Par(params, "file"), p.file)
        if (FileOps.IsWild(p.file))
            throw FileOps.NoWildcard(p.file)
        FileOps.CheckFileSource(p.file)
        if (p.newName = "")
            throw ElementError(Lang("%1% is not specified.", Lang("New file name")))
        if (FileOps.IsWild(p.newName))
            throw FileOps.NoWildcard(p.newName)
        SplitPath(p.file, , &folderFrom)
        newPath := folderFrom "\" p.newName
        try FileMove(p.file, newPath)
        catch as err {
            code := FileOps.Code(err)
            if (FileOps.ExistsAsFile(newPath))
                throw ElementError(Lang("%1% '%2%' already exists.", Lang("Destination file"), newPath))
            throw FileOps.Fail(Lang("%1% files could not be renamed from '%2%' to '%3%'", FileOps.Failures(err), p.file, newPath), code)
        }
        ctx.Finish("normal")
    }
}
