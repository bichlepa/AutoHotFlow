#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Copy folder of the package Default (WI-0120): copies a folder with its subfolders and files. Specification: the help
; text of v1 (help/en/Actions/Copy_folder.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Copy_folder.ahk).
;
; Worker element (the file access, ARCHITECTURE 2.3). Without Overwrite an existing destination folder is an error; with
; Overwrite the files are copied into it and replace the files of the same name (AutoHotkey DirCopy, overwrite 1).
class Action_Copy_Folder extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Copy Folder")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Source folder")},
        {type: "Folder", id: "folder", label: Lang("Select a folder")},
        {type: "Label", label: Lang("Destination file or folder")},
        {type: "Folder", id: "destFolder", label: Lang("Select a folder")},
        {type: "Label", label: Lang("Overwrite")},
        {type: "Checkbox", id: "Overwrite", default: 0, label: Lang("Overwrite existing files")}
    ]

    static GenerateName(ctx, params) => Lang("Copy Folder") " - " TextOps.Par(params, "folder") " - " TextOps.Par(params, "destFolder")

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
        try DirCopy(p.folder, p.destFolder, overwrite ? 1 : 0)
        catch as err
            throw FileOps.Fail(Lang("Folder '%1%' could not be copied to '%2%'", p.folder, p.destFolder), FileOps.Code(err))
        ctx.Finish("normal")
    }
}
