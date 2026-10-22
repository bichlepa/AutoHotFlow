#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Read from file of the package Default (WI-0120): reads a file into a variable. Specification: the help text of v1
; (help/en/Actions/Read_From_File.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Read_From_File.ahk).
;
; Worker element (the file access, ARCHITECTURE 2.3). Encodings:
;   raw            the bytes, one character per byte (ISO-8859-1). A variable holds no Buffer, so the bytes are kept
;                  as characters; a NUL byte ends the text (MIGRATION M-0113).
;   ANSI           the system default codepage (CP0). UTF-8 and UTF-16 as the file says (a byte order mark wins).
;   other          the code page with the number of the parameter CodePageIdentifier (CP<number>).
; Linefeed: CR LF becomes LF (v1 option *t). SizeLimit reads at most that many bytes (v1 option *m).
class Action_Read_From_File extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Read From File")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "varname", default: "FileText", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("File path")},
        {type: "File", id: "file", label: Lang("Select a file")},
        {type: "Label", label: Lang("Encoding")},
        {type: "Radio", id: "Encoding", default: "UTF-8", choices: [Lang("Raw data"), Lang("System default ANSI codepage"), Lang("Unicode UTF-8"), Lang("Unicode UTF-16"), Lang("Other")], result: "enum", enum: ["raw", "ANSI", "UTF-8", "UTF-16", "other"]},
        {type: "Edit", id: "CodePageIdentifier", default: "", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Size limit")},
        {type: "Checkbox", id: "EnableSizeLimit", default: 0, label: Lang("Enable size limit")},
        {type: "Edit", id: "SizeLimit", default: "1024", content: "Expression", WarnIfEmpty: true},
        {type: "Label", label: Lang("Linefeed")},
        {type: "Checkbox", id: "Linefeed", default: 1, label: Lang("Replace carriage return and linefeed with single linefeeds")}
    ]

    static GenerateName(ctx, params) => Lang("Read From File") " - " TextOps.Par(params, "varname") " - " TextOps.Par(params, "file")

    static CheckSettings(form, params, staticValues) {
        encoding := TextOps.Par(params, "Encoding")
        form.Disable("Linefeed", encoding = "raw")
        form.Enable("CodePageIdentifier", encoding = "other")
        form.Enable("SizeLimit", DialogOps.Truthy(TextOps.Par(params, "EnableSizeLimit")))
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "CodePageIdentifier")     ; the code page is needed only for "other" (as v1)
        file := p.file
        attr := FileOps.Attr(file)
        if (attr = "")
            throw ElementError(Lang("%1% '%2%' does not exist.", Lang("Source file"), file))
        if (FileOps.IsFolder(attr))
            throw ElementError(Lang("%1% '%2%' is a folder.", Lang("Source file"), file))
        if (p.Encoding = "other")
            p := ctx.EvalMoreParams(p, params, "CodePageIdentifier")
        text := this._Read(file, p)
        if (!ctx.SetVar(p.varname, text))
            throw ElementError("The variable '" p.varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }

    ; The text of the file in the chosen encoding (the options of FileRead, see its help).
    static _Read(file, p) {
        if (p.Encoding = "raw") {
            try buf := FileRead(file, "RAW")
            catch as err
                throw FileOps.Fail(Lang("File '%1%' could not be read", file), FileOps.Code(err))
            return StrGet(buf.Ptr, buf.Size, "CP28591")
        }
        opts := ""
        if (p.Encoding = "UTF-8" || p.Encoding = "UTF-16")
            opts := p.Encoding
        else if (p.Encoding = "ANSI")
            opts := "CP0"
        else if (p.Encoding = "other")
            opts := "CP" this._CodePage(p.CodePageIdentifier)
        else
            throw ElementError(Lang("Unknown output encoding format: %1%", p.Encoding))
        if (DialogOps.Truthy(p.Linefeed))
            opts .= " `n"
        if (DialogOps.Truthy(p.EnableSizeLimit))
            opts .= " m" this._Limit(p.SizeLimit)
        try text := FileRead(file, opts)
        catch as err
            throw FileOps.Fail(Lang("File '%1%' could not be read", file), FileOps.Code(err))
        return text
    }

    static _CodePage(id) {
        if (!IsInteger(id))
            throw ElementError(Lang("Unknown output encoding format: %1%", id))
        return id
    }

    static _Limit(value) {
        if (!IsInteger(value))
            throw ElementError(Lang("%1% is not an integer.", Lang("Size limit")))
        if (value <= 0)
            throw ElementError(Lang("%1% is not a positive number.", Lang("Size limit")))
        return value
    }
}
