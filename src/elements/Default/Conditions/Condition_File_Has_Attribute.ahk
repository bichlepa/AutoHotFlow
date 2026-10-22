#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Condition File has attribute of the package Default (WI-0121): yes when the file has the chosen attribute, no otherwise.
; Specification: the help text of v1 (help/en/Conditions/File_Has_Attribute.md). Class ID, parameter IDs, defaults and
; language keys are those of v1 (Source_Elements/Default/Conditions/File_Has_Attribute.ahk).
;
; The attributes are the letters of FileGetAttrib (N normal, R read only, A archive, S system, H hidden, D folder, O
; offline, C compressed, T temporary). A file that does not exist ends with an exception (v1 text). Worker element (the file
; access, ARCHITECTURE 2.3).
class Condition_File_Has_Attribute extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("File Has Attribute")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("File path")},
        {type: "File", id: "file", label: Lang("Select a file")},
        {type: "Label", label: Lang("Which attribute")},
        {type: "Radio", id: "Attribute", default: 1, choices: [Lang("Normal"), Lang("Read only"), Lang("Archive"), Lang("System"), Lang("Hidden"), Lang("Directory"), Lang("Offline"), Lang("Compressed"), Lang("Temporary")], result: "enum", enum: ["N", "R", "A", "S", "H", "D", "O", "C", "T"]}
    ]

    static GenerateName(ctx, params) => Lang("File Has Attribute") " - " this._Label(TextOps.Par(params, "Attribute")) " - " TextOps.Par(params, "file")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        if (FileExist(p.file) = "")
            throw ElementError(Lang("File '%1%' does not exist", p.file))
        try attr := FileGetAttrib(p.file)
        catch as err
            throw FileOps.Fail(Lang("Attributes of file '%1%' could not be read", p.file), FileOps.Code(err))
        ctx.Finish(InStr(attr, p.Attribute) ? "yes" : "no")
    }

    ; The name of an attribute letter, as the editor shows it (the v1 texts).
    static _Label(letter) {
        switch letter {
            case "N": return Lang("Normal")
            case "R": return Lang("Read only")
            case "A": return Lang("Archive")
            case "S": return Lang("System")
            case "H": return Lang("Hidden")
            case "D": return Lang("Directory")
            case "O": return Lang("Offline")
            case "C": return Lang("Compressed")
            case "T": return Lang("Temporary")
        }
        return letter
    }
}
