#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Write to file of the package Default (WI-0120): writes a text to a file, appended or overwriting it. Specification:
; the help text of v1 (help/en/Actions/Write_To_File.md). Class ID, parameter IDs, defaults and language keys are those of
; v1 (Source_Elements/Default/Actions/Write_To_File.ahk).
;
; Worker element (the file access, ARCHITECTURE 2.3). Overwrite deletes the file first, then appends (as v1). The byte
; order mark is written with UTF-8 or UTF-16 only when WithBOM is set (UTF-8-RAW, UTF-16-RAW otherwise; AutoHotkey writes
; a mark only into a new file). Linefeed: every LF becomes CR LF; a CR LF in the text stays one CR LF (MIGRATION M-0115).
class Action_Write_To_File extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Write To File")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Text to write")},
        {type: "multiLineEdit", id: "text", content: ["String", "Expression"], contentID: "Expression", contentDefault: "string", WarnIfEmpty: true},
        {type: "Label", label: Lang("File path")},
        {type: "File", id: "file", label: Lang("Select a file")},
        {type: "Label", label: Lang("Append or overwrite")},
        {type: "Radio", id: "Overwrite", default: 1, choices: [Lang("Append"), Lang("Overwrite")], result: "enum", enum: ["Append", "Overwrite"]},
        {type: "Label", label: Lang("Encoding")},
        {type: "Radio", id: "Encoding", default: "UTF-8", choices: [Lang("System default ANSI codepage"), Lang("Unicode UTF-8"), Lang("Unicode UTF-16"), Lang("Other")], result: "enum", enum: ["ansi", "UTF-8", "UTF-16", "other"]},
        {type: "Checkbox", id: "WithBOM", default: 0, label: Lang("Add byte order mark (BOM)")},
        {type: "Edit", id: "CodePageIdentifier", default: "", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Linefeed")},
        {type: "Checkbox", id: "Linefeed", default: 1, label: Lang("Replace single linefeeds with carriage return and linefeed")}
    ]

    static GenerateName(ctx, params) => Lang("Write To File") " - " TextOps.Par(params, "file") " - " TextOps.Par(params, "text")

    static CheckSettings(form, params, staticValues) {
        encoding := TextOps.Par(params, "Encoding")
        form.Enable("WithBOM", encoding = "UTF-8" || encoding = "UTF-16")
        form.Enable("CodePageIdentifier", encoding = "other")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "CodePageIdentifier")     ; the code page is needed only for "other" (as v1)
        file := p.file
        text := TextOps.Text(p.text, "text")
        if (p.Encoding = "other")
            p := ctx.EvalMoreParams(p, params, "CodePageIdentifier")
        opts := this._Options(p)
        if (DialogOps.Truthy(p.Linefeed))
            text := StrReplace(StrReplace(text, "`r`n", "`n"), "`n", "`r`n")
        if (p.Overwrite = "Overwrite" && FileOps.Attr(file) != "") {
            try FileDelete(file)
            catch as err
                throw FileOps.Fail(Lang("File '%1%' could not be deleted", file), FileOps.Code(err))
        }
        try FileAppend(text, file, opts)
        catch as err
            throw FileOps.Fail(Lang("File '%1%' could not be written", file), FileOps.Code(err))
        ctx.Finish("normal")
    }

    ; The encoding option of FileAppend for the chosen encoding.
    static _Options(p) {
        enc := p.Encoding
        if (enc = "UTF-8" || enc = "UTF-16")
            return DialogOps.Truthy(p.WithBOM) ? enc : enc "-RAW"
        if (enc = "ansi")
            return "CP0"
        if (enc = "other") {
            if (!IsInteger(p.CodePageIdentifier))
                throw ElementError(Lang("Unknown output encoding format: %1%", p.CodePageIdentifier))
            return "CP" p.CodePageIdentifier
        }
        throw ElementError(Lang("Unknown output encoding format: %1%", enc))
    }
}
