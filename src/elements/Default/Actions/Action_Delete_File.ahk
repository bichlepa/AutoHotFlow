#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Delete file of the package Default (WI-0120): deletes one file or the files of a wildcard pattern, or sends them to
; the recycle bin. Specification: the help text of v1 (help/en/Actions/Delete_file.md). Class ID, parameter IDs, defaults
; and language keys are those of v1 (Source_Elements/Default/Actions/Delete_file.ahk).
;
; Worker element (the file access, ARCHITECTURE 2.3). Recycle goes through the seam SystemOps (E0103): the recycle bin is
; not touched by a test. Recycle sends a file to the recycle bin where AutoHotkey finds one, and deletes it otherwise
; (the AutoHotkey function FileRecycle). A read-only file is not deleted (as v1); it needs its attribute changed first.
class Action_Delete_File extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Delete File")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Source file")},
        {type: "File", id: "file", label: Lang("Select a file")},
        {type: "Label", label: Lang("Delete method")},
        {type: "Radio", id: "deleteFileMethod", default: "Recycle", result: "enum", choices: [Lang("Delete"), Lang("Recycle")], enum: ["Delete", "Recycle"]}
    ]

    static GenerateName(ctx, params) => Lang("Delete File") " - " TextOps.Par(params, "file")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        FileOps.CheckFileSource(p.file)
        if (p.deleteFileMethod = "Recycle") {
            try SystemOps.FileRecycle(p.file)
            catch as err
                throw FileOps.Fail(Lang("Some files could not be recycled (File path: '%1%')", p.file), FileOps.Code(err))
        } else {
            try FileDelete(p.file)
            catch as err
                throw FileOps.Fail(Lang("%1% files could not be deleted (File path: '%2%')", FileOps.Failures(err), p.file), FileOps.Code(err))
        }
        ctx.Finish("normal")
    }
}
