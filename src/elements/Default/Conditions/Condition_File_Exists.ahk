#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Condition File exists of the package Default (WI-0120): "yes" when a file or a folder exists at the path, else "no".
; Specification: the help text of v1 (help/en/Conditions/File_Exists.md). Class ID, parameter IDs, defaults and language
; keys are those of v1 (Source_Elements/Default/Conditions/File_Exists.ahk). A wildcard is "yes" when one file matches.
;
; Worker element (the file access, ARCHITECTURE 2.3).
class Condition_File_Exists extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("File Exists")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("File path")},
        {type: "File", id: "file", label: Lang("Select a file")}
    ]

    static GenerateName(ctx, params) => Lang("File Exists") " - " TextOps.Par(params, "file")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        ctx.Finish(FileOps.Attr(p.file) != "" ? "yes" : "no")
    }
}
