#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\IniOps.ahk
#Include ..\lib\TextOps.ahk

; Action Delete from ini of the package Default (WI-0121): deletes a key or a whole section of an ini file. Specification: the
; help text of v1 (help/en/Actions/Delete_From_Ini.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Delete_From_Ini.ahk).
;
; The file must exist (v1 text). Deliberate difference (MIGRATION M-0127): v1 tested the key the wrong way round and refused
; every non-empty key ("Key not specified"); v2 refuses an empty key. Worker element (the file access, ARCHITECTURE 2.3).
class Action_Delete_From_Ini extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Delete From Ini")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Path of an .ini file")},
        {type: "File", id: "file", label: Lang("Select an .ini file")},
        {type: "Label", label: Lang("Action")},
        {type: "Radio", id: "Action", result: "enum", default: 1, choices: [Lang("Delete a key"), Lang("Delete a section")], enum: ["DeleteKey", "DeleteSection"]},
        {type: "Label", label: Lang("Section")},
        {type: "Edit", id: "Section", default: "section", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Key")},
        {type: "Edit", id: "Key", default: "key", content: "String", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("Delete From Ini")

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "Key")
        IniOps.CheckFile(p.file)
        if (p.Section = "")
            throw ElementError(Lang("Section not specified"))
        if (p.Action = "DeleteKey") {
            p := ctx.EvalMoreParams(p, params, "Key")
            if (p.Key = "")
                throw ElementError(Lang("Key not specified"))
            this._Delete(p.file, p.Section, p.Key)
        } else if (p.Action = "DeleteSection") {
            this._Delete(p.file, p.Section)
        }
        ctx.Finish("normal")
    }

    ; IniDelete of a key, or of the whole section when key is "" (the caller refused an empty key before). A failure is the
    ; v1 text and the reason of the system.
    static _Delete(file, section, key := "") {
        try {
            if (key = "")
                IniDelete(file, section)
            else
                IniDelete(file, section, key)
        } catch as err
            throw FileOps.Fail(Lang("Error while deleting from ini"), FileOps.Code(err))
    }
}
