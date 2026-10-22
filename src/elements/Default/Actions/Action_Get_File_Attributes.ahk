#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Get file attributes of the package Default (WI-0121): stores the attributes of a file or folder in a variable.
; Specification: the help text of v1 (help/en/Actions/Get_File_Attributes.md). Class ID, parameter IDs, defaults and language
; keys are those of v1 (Source_Elements/Default/Actions/Get_file_attributes.ahk).
;
; The attribute text is FileExist's: a subset of RASHNDOCTL (R read only, A archive, S system, H hidden, D folder, ...),
; "" when the file does not exist. Worker element (the file access, ARCHITECTURE 2.3).
; Deliberate differences (MIGRATION M-0124): v1 ended with an exception when the file DID exist (the test was inverted)
; and stored the value in a variable named Varname that was never set; v2 does what the help says.
class Action_Get_File_Attributes extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Get File Attributes")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output Variable name")},
        {type: "Edit", id: "varname", default: "FileAttributes", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("File path")},
        {type: "File", id: "file", label: Lang("Select a file")}
    ]

    static GenerateName(ctx, params) => Lang("Get File Attributes") " - " TextOps.Par(params, "varname") " - " TextOps.Par(params, "file")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        attr := FileExist(p.file)
        if (attr = "")
            throw ElementError(Lang("%1% '%2%' does not exist.", Lang("File"), p.file))
        FileOps.SetOutput(ctx, p.varname, attr)
        ctx.Finish("normal")
    }
}
