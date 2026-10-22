#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\IniOps.ahk
#Include ..\lib\TextOps.ahk

; Action Write to ini of the package Default (WI-0121): writes a value to a key of a section of an ini file. Specification:
; the help text of v1 (help/en/Actions/Write_to_ini.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Write_to_ini.ahk).
;
; A missing file is created (IniWrite creates it as UTF-16 with a byte order mark, as v1). A folder, an empty section or key
; name end with an exception. Worker element (the file access, ARCHITECTURE 2.3).
class Action_Write_to_ini extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Write to ini")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Value")},
        {type: "Edit", id: "Value", default: "value", content: "String"},
        {type: "Label", label: Lang("Path of .ini file")},
        {type: "File", id: "file", label: Lang("Select an .ini file")},
        {type: "Label", label: Lang("Section")},
        {type: "Edit", id: "Section", default: "section", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Key")},
        {type: "Edit", id: "Key", default: "key", content: "String", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("Write to ini") " - " TextOps.Par(params, "Section") " - " TextOps.Par(params, "Key") " - " TextOps.Par(params, "Value") " - " TextOps.Par(params, "file")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        IniOps.CheckNotFolder(p.file)
        IniOps.Require(p.Section, Lang("Section name"))
        IniOps.Require(p.Key, Lang("Key name"))
        try IniWrite(p.Value, p.file, p.Section, p.Key)
        catch as err
            throw FileOps.Fail(Lang("Could not write value '%1%' to ini file '%2%', section '%3%', key '%4%'", p.Value, p.file, p.Section, p.Key), FileOps.Code(err))
        ctx.Finish("normal")
    }
}
