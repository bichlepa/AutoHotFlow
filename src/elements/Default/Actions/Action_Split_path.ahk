#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Split path of the package Default (WI-0120): writes the parts of a file path to variables (file name, directory,
; extension, name without extension, drive). Specification: the help text of v1 (help/en/Actions/Split_path.md). Class ID,
; parameter IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Split_path.ahk).
;
; Inline element: AutoHotkey SplitPath computes the parts from the text, no file is accessed. A part whose output variable
; name is empty is not written (MIGRATION M-0118).
class Action_Split_path extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Split path")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("File path")},
        {type: "File", id: "file", label: Lang("Select a file"), WarnIfEmpty: true},
        {type: "Label", label: Lang("Output variables")},
        {type: "Label", label: Lang("File name"), size: "small"},
        {type: "Edit", id: "OutFileName", default: "fileName", content: "VariableName"},
        {type: "Label", label: Lang("Directory"), size: "small"},
        {type: "Edit", id: "OutDir", default: "directory", content: "VariableName"},
        {type: "Label", label: Lang("File extension"), size: "small"},
        {type: "Edit", id: "OutExtension", default: "fileExtension", content: "VariableName"},
        {type: "Label", label: Lang("File name without extension"), size: "small"},
        {type: "Edit", id: "OutNameNoExt", default: "fileNameNoExtension", content: "VariableName"},
        {type: "Label", label: Lang("Drive"), size: "small"},
        {type: "Edit", id: "OutDrive", default: "drive", content: "VariableName"}
    ]

    static GenerateName(ctx, params) => Lang("Split path") " - " TextOps.Par(params, "file")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        SplitPath(p.file, &fileName, &dir, &ext, &nameNoExt, &drive)
        outputs := [[p.OutFileName, fileName], [p.OutDir, dir], [p.OutExtension, ext], [p.OutNameNoExt, nameNoExt], [p.OutDrive, drive]]
        for output in outputs {
            if (output[1] = "")
                continue
            if (!ctx.SetVar(output[1], output[2]))
                throw ElementError("The variable '" output[1] "' could not be set (the reason is in the log).")
        }
        ctx.Finish("normal")
    }
}
