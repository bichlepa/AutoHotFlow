#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ListOps.ahk
#Include ..\lib\ListFormats.ahk
#Include ..\lib\TextOps.ahk

; Action Convert list to string of the package Default (WI-0119): writes a list as a JSON text to a variable. The
; format YAML is not part of this version (REQ-ELM-310 is later): the element ends with exception (MIGRATION M-0110).
; Specification: the help text of v1 (help/en/Actions/Convert_list_to_string.md). Class ID, parameter IDs, enum values,
; defaults and language keys are those of v1 (Source_Elements/Default/Actions/Convert_list_to_string.ahk).
;
; Compact mode writes one line; otherwise the indentation length is the number of spaces per level. The JSON writer
; is Json.Stringify (keys sorted, as v1 Jxon_Dump wrote its keys in its own order; MIGRATION M-0110).
class Action_Convert_list_to_string extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Convert list to string")
    static Category() => Lang("List")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "MyString", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input list")},
        {type: "Edit", id: "ListName", default: "MyList", content: "expression", WarnIfEmpty: true},
        {type: "Label", label: Lang("Output format")},
        {type: "Radio", id: "listToStringOutputFormat", result: "enum", default: "JSON", choices: ["JSON", "YAML"], enum: ["JSON", "YAML"]},
        {type: "Label", label: Lang("Options")},
        {type: "Checkbox", id: "compactMode", default: 0, label: Lang("Compact mode")},
        {type: "Label", label: Lang("Indentation length"), size: "small"},
        {type: "Edit", id: "indentationLength", default: 2, content: "PositiveInteger", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        return Lang("Convert list '%1%' to %2%-string", TextOps.Par(params, "ListName"), TextOps.Par(params, "listToStringOutputFormat"))
            . " - " TextOps.Par(params, "Varname")
    }

    static CheckSettings(form, params, staticValues) {
        isJson := (params.listToStringOutputFormat = "JSON")
        form.Enable("compactMode", isJson)
        form.Enable("indentationLength", isJson && !params.compactMode)
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "indentationLength")
        list := ListOps.Require(p.ListName, Lang("Expression '%1%' does not contain a list.", params.ListName))
        switch p.listToStringOutputFormat {
            case "JSON":
                if (p.compactMode) {
                    indent := 0
                } else {
                    p := ctx.EvalMoreParams(p, params, "indentationLength")
                    indent := TextOps.Count(p.indentationLength)
                }
                try
                    text := Json.Stringify(ListFormats.ToPlain(list), indent)
                catch as e
                    throw ElementError(Lang("Error converting list to string") " - " e.Message)
            case "YAML":
                throw ElementError(Lang("The format YAML is not supported in this version."))
            default:
                throw ElementError("Convert list to string: unknown format '" p.listToStringOutputFormat "'")
        }
        if (!ctx.SetVar(p.Varname, text))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
