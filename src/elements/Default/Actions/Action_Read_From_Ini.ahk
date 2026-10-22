#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\IniOps.ahk
#Include ..\lib\TextOps.ahk

; Action Read from ini of the package Default (WI-0121): reads a key, a whole section or the section names of an ini file
; into a variable. Specification: the help text of v1 (help/en/Actions/Read_From_Ini.md). Class ID, parameter IDs, defaults
; and language keys are those of v1 (Source_Elements/Default/Actions/Read_From_Ini.ahk).
;
;   Key              the value of one key (WhenError: the default text, or an exception when the key is missing)
;   EntireSection    a Map of the keys and values of the section (keys are not case sensitive)
;   SectionNames     an Array of the section names (a Map with the keys 1..n in the variable)
;
; Worker element (the file access, ARCHITECTURE 2.3). IniRead reads a UTF-16 file and an ANSI file as the system does.
; A section that does not exist gives an empty Map (as v1), a missing file an exception (v1 text).
class Action_Read_From_Ini extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Read From Ini")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output Variable name")},
        {type: "Edit", id: "varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Path of .ini file")},
        {type: "File", id: "file", label: Lang("Select an .ini file")},
        {type: "Label", label: Lang("Action")},
        {type: "Radio", id: "Action", default: 1, choices: [Lang("Read a key"), Lang("Read the entire section"), Lang("Read the section names")], result: "enum", enum: ["Key", "EntireSection", "SectionNames"]},
        {type: "Label", label: Lang("Section")},
        {type: "Edit", id: "Section", default: "section", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Key")},
        {type: "Edit", id: "Key", default: "key", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Behavior on error")},
        {type: "Radio", id: "WhenError", default: 1, choices: [Lang("Insert default value in the variable"), Lang("Throw exception")], result: "enum", enum: ["Default", "Exception"]},
        {type: "Label", label: Lang("Default value on failure"), size: "small"},
        {type: "Edit", id: "Default", default: "ERROR", content: "String"}
    ]

    static GenerateName(ctx, params) {
        filePath := TextOps.Par(params, "file")
        varname := TextOps.Par(params, "varname")
        section := TextOps.Par(params, "Section")
        switch TextOps.Par(params, "Action") {
            case "Key":
                return Lang("Read From Ini") " - " Lang("Read a key") " - " varname " - " section " - " TextOps.Par(params, "Key") " - " filePath
            case "EntireSection":
                return Lang("Read From Ini") " - " Lang("Read the entire section") " - " varname " - " section " - " filePath
        }
        return Lang("Read From Ini") " - " Lang("Read the section names") " - " varname " - " filePath
    }

    static CheckSettings(form, params, staticValues) {
        action := TextOps.Par(params, "Action")
        isKey := (action = "Key")
        form.Disable("Section", !(isKey || action = "EntireSection"))
        form.Disable("Key", !isKey)
        form.Disable("WhenError", !isKey)
        form.Disable("Default", !(isKey && TextOps.Par(params, "WhenError") = "Default"))
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "section,key,Default,WhenError")
        IniOps.CheckFile(p.file)
        if (p.Action = "Key")
            value := this._Key(ctx, p, params)
        else if (p.Action = "EntireSection")
            value := this._Section(ctx, p, params)
        else
            value := this._SectionNames(p.file)
        FileOps.SetOutput(ctx, p.varname, value)
        ctx.Finish("normal")
    }

    ; One key. A missing key is the default text (WhenError Default) or an exception.
    static _Key(ctx, p, params) {
        p := ctx.EvalMoreParams(p, params, "section,Key,WhenError")
        IniOps.Require(p.section, Lang("Section name"))
        IniOps.Require(p.Key, Lang("Key name"))
        if (p.WhenError = "Default") {
            p := ctx.EvalMoreParams(p, params, "Default")
            ; An empty default gives the empty text. v1 passed a single space here; AutoHotkey v2 returns the empty text for
            ; it as well (checked), so the substitution is gone (MIGRATION M-0128).
            try value := IniRead(p.file, p.section, p.Key, p.Default)
            catch as err
                throw FileOps.Fail(Lang("File '%1%' could not be read", p.file), FileOps.Code(err))
            return value
        }
        marker := "E?R ROR"             ; the v1 marker of a key that is not there
        try value := IniRead(p.file, p.section, p.Key, marker)
        catch as err
            throw FileOps.Fail(Lang("File '%1%' could not be read", p.file), FileOps.Code(err))
        if (value = marker)
            throw ElementError(Lang("Section '%1%' and key '%2%' not found.", p.section, p.Key))
        return value
    }

    ; The keys and values of one section, as a Map (the section name is required, as v1).
    static _Section(ctx, p, params) {
        p := ctx.EvalMoreParams(p, params, "section")
        IniOps.Require(p.section, Lang("Section name"))
        try text := IniRead(p.file, p.section, , "")
        catch as err
            throw FileOps.Fail(Lang("File '%1%' could not be read", p.file), FileOps.Code(err))
        return IniOps.Pairs(text)
    }

    ; The section names of the file, as an Array (the variable gets the keys 1..n).
    static _SectionNames(file) {
        try text := IniRead(file, , , "")
        catch as err
            throw FileOps.Fail(Lang("File '%1%' could not be read", file), FileOps.Code(err))
        names := []
        for name in StrSplit(text, "`n", "`r")
            if (name != "")
                names.Push(name)
        return names
    }
}
