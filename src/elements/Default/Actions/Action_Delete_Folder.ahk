#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Delete folder of the package Default (WI-0120): deletes a folder, with its contents or only when it is empty.
; Specification: the help text of v1 (help/en/Actions/Delete_folder.md). Class ID, parameter IDs, defaults and language keys
; are those of v1 (Source_Elements/Default/Actions/Delete_folder.ahk).
;
; Worker element (the file access, ARCHITECTURE 2.3). The checkbox "Remove only if the folder is empty" (parameter ifEmpty)
; decides between DirDelete without and with the recurse flag. v1 read another parameter name (OnlyIfEmpty) and so always
; deleted the contents; v2 honours the checkbox (MIGRATION M-0114).
; A missing folder is an exception, unless ExceptionIfNotExist is off: then the element ends normal with a message.
class Action_Delete_Folder extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Delete Folder")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Folder path")},
        {type: "File", id: "Folder", label: Lang("Select a folder")},
        {type: "Label", label: Lang("Delete method")},
        {type: "Checkbox", id: "ifEmpty", default: 0, label: Lang("Remove only if the folder is empty")},
        {type: "Label", label: Lang("Error handling")},
        {type: "Checkbox", id: "ExceptionIfNotExist", default: 1, label: Lang("Throw exception if folder does not exist")}
    ]

    static GenerateName(ctx, params) => Lang("Delete Folder") " - " TextOps.Par(params, "Folder")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        FileOps.Guard(Lang("Destination folder"), TextOps.Par(params, "Folder"), p.Folder)
        FileOps.GuardWorkingDir(p.Folder, ctx.GetVar("A_WorkingDir"))
        attr := FileOps.Attr(p.Folder)
        if (attr = "") {
            if (DialogOps.Truthy(p.ExceptionIfNotExist))
                throw ElementError(Lang("%1% '%2%' does not exist.", Lang("Destination folder"), p.Folder))
            ctx.Finish("normal", Lang("%1% '%2%' does not exist.", Lang("Destination folder"), p.Folder))
            return
        }
        if (!FileOps.IsFolder(attr))
            throw ElementError(Lang("%1% '%2%' is not a folder.", Lang("Destination folder"), p.Folder))
        try DirDelete(p.Folder, !DialogOps.Truthy(p.ifEmpty))
        catch as err
            throw FileOps.Fail(Lang("Folder could not be deleted (File path: '%1%')", p.Folder), FileOps.Code(err))
        ctx.Finish("normal")
    }
}
