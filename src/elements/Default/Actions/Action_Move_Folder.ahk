#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Move folder of the package Default (WI-0120): moves a folder with its subfolders and files. Specification: the help
; text of v1 (help/en/Actions/Move_Folder.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Move_Folder.ahk).
;
; Worker element (the file access, ARCHITECTURE 2.3). The same checks as Action_Copy_Folder. Overwrite is AutoHotkey DirMove
; mode 1. Known limit of AutoHotkey (its help): when the destination is an existing folder on the same drive, the source
; is moved into it instead of replacing it (not checked here; MIGRATION M-0116).
class Action_Move_Folder extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Move Folder")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Source folder")},
        {type: "Folder", id: "folder", label: Lang("Select a folder")},
        {type: "Label", label: Lang("Destination file or folder")},
        {type: "Folder", id: "destFolder", label: Lang("Select a folder")},
        {type: "Label", label: Lang("Overwrite")},
        {type: "Checkbox", id: "Overwrite", default: 0, label: Lang("Overwrite existing files")}
    ]

    static GenerateName(ctx, params) => Lang("Move Folder") " - " TextOps.Par(params, "folder") " - " TextOps.Par(params, "destFolder")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        FileOps.CheckFolderSource(p.folder)
        overwrite := DialogOps.Truthy(p.Overwrite)
        attr := FileOps.Attr(p.destFolder)
        if (attr != "") {
            if (!overwrite)
                throw ElementError(Lang("%1% '%2%' already exists.", Lang("Destination folder"), p.destFolder))
            if (!FileOps.IsFolder(attr))
                throw ElementError(Lang("%1% '%2%' exists and is not a folder.", Lang("Destination folder"), p.destFolder))
        }
        try DirMove(p.folder, p.destFolder, overwrite ? 1 : 0)
        catch as err
            throw FileOps.Fail(Lang("Folder '%1%' could not be moved to '%2%'", p.folder, p.destFolder), FileOps.Code(err))
        ctx.Finish("normal")
    }
}
