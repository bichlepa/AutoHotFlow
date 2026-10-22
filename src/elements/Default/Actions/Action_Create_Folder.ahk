#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Create folder of the package Default (WI-0120): creates a folder and the folders above it. Specification: the help
; text of v1 (help/en/Actions/Create_folder.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Create_folder.ahk).
;
; Worker element (the file access, ARCHITECTURE 2.3). An existing folder is not an error unless ErrorIfExists is set; an
; existing file with that name is always an error.
class Action_Create_Folder extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Create Folder")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Source folder")},
        {type: "File", id: "folder", label: Lang("Select a folder")},
        {type: "Label", label: Lang("Options")},
        {type: "Checkbox", id: "ErrorIfExists", default: 0, label: Lang("Throw exception if folder already exists")}
    ]

    static GenerateName(ctx, params) => Lang("Create Folder") " - " TextOps.Par(params, "folder")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        attr := FileOps.Attr(p.folder)
        if (attr != "") {
            if (!FileOps.IsFolder(attr))
                throw ElementError(Lang("%1% '%2%' exists and it is a file.", Lang("Destination folder"), p.folder))
            if (DialogOps.Truthy(p.ErrorIfExists))
                throw ElementError(Lang("%1% '%2%' already exists.", Lang("Destination folder"), p.folder))
            ctx.Finish("normal")
            return
        }
        try DirCreate(p.folder)
        catch as err
            throw FileOps.Fail(Lang("Folder '%1%' could not be created", p.folder), FileOps.Code(err))
        ctx.Finish("normal")
    }
}
