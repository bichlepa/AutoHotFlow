#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Rename folder of the package Default (WI-0120): gives a folder a new name in its parent folder. Specification: the
; help text of v1 (help/en/Actions/Rename_Folder.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Rename_Folder.ahk).
;
; Worker element (the file access, ARCHITECTURE 2.3). The new name is a name, not a path. AutoHotkey DirMove mode "R"
; renames the folder: all or nothing, when a file in it is in use nothing changes.
class Action_Rename_Folder extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Rename Folder")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Source folder")},
        {type: "Folder", id: "folder", label: Lang("Select a folder")},
        {type: "Label", label: Lang("Destination file or folder")},
        {type: "Edit", id: "newName", default: Lang("Renamed"), content: "String", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("Rename Folder") " - " TextOps.Par(params, "folder") " - " TextOps.Par(params, "newName")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        FileOps.Guard(Lang("Source folder"), TextOps.Par(params, "folder"), p.folder)
        FileOps.CheckFolderSource(p.folder)
        if (p.newName = "")
            throw ElementError(Lang("%1% is not specified.", Lang("New folder name")))
        if (FileOps.IsWild(p.newName))
            throw FileOps.NoWildcard(p.newName)
        SplitPath(p.folder, , &parent)
        newPath := parent "\" p.newName
        try DirMove(p.folder, newPath, "R")
        catch as err
            throw FileOps.Fail(Lang("Folder '%1%' could not be renamed to '%2%'", p.folder, newPath), FileOps.Code(err))
        ctx.Finish("normal")
    }
}
