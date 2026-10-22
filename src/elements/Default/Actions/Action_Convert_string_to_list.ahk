#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ListOps.ahk
#Include ..\lib\ListFormats.ahk
#Include ..\lib\TextOps.ahk

; Action Convert string to list of the package Default (WI-0119): reads a JSON text and writes the list to a variable.
; The text must hold a JSON object or array (a list, as the v1 element wrote it); a JSON text with another value is an
; exception (MIGRATION M-0110). The format YAML is not part of this version: exception (MIGRATION M-0110).
; Specification: the help text of v1 (help/en/Actions/Convert_string_to_list.md). Class ID, parameter IDs, enum values,
; defaults and language keys are those of v1 (Source_Elements/Default/Actions/Convert_string_to_list.ahk).
class Action_Convert_string_to_list extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Convert string to list")
    static Category() => Lang("List")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output list name")},
        {type: "Edit", id: "Varname", default: "MyList", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input string")},
        {type: "Edit", id: "VarValue", default: "myString", content: ["String", "Expression"], contentID: "expression", contentDefault: "Expression", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input format")},
        {type: "Radio", id: "listToStringOutputFormat", result: "enum", default: "JSON", choices: ["JSON", "YAML"], enum: ["JSON", "YAML"]}
    ]

    static GenerateName(ctx, params) {
        return Lang("Convert %1%-string to list '%2%'", TextOps.Par(params, "listToStringOutputFormat"), TextOps.Par(params, "VarValue"))
            . " - " TextOps.Par(params, "Varname")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        text := TextOps.Text(p.VarValue, params.VarValue)
        switch p.listToStringOutputFormat {
            case "JSON":
                try
                    parsed := Json.Parse(text)
                catch as e
                    throw ElementError(Lang("Error converting string to list") " - " e.Message)
                if (!(parsed is Map || parsed is Array))
                    throw ElementError(Lang("The text does not contain a JSON object or array."))
                list := ListFormats.FromPlain(parsed)
            case "YAML":
                throw ElementError(Lang("The format YAML is not supported in this version."))
            default:
                throw ElementError("Convert string to list: unknown format '" p.listToStringOutputFormat "'")
        }
        if (!ctx.SetVar(p.Varname, list))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
