#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Encode string of the package Default (WI-0119): writes a string in an encoded form to a variable. The only
; format is URL (the URI encoding of v1: unreserved characters stay, every other byte of the UTF-8 form becomes %XX).
; Specification: the help text of v1 (help/en/Actions/Encode_string.md, written for v2). Class ID, parameter IDs, enum
; values, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Encode_string.ahk). No DllCall:
; the UTF-8 bytes come from StrPut (TextOps.UriEncode), so the element is inline.
class Action_Encode_string extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Advanced"
    static Stability := "Stable"

    static Name() => Lang("Encode string")
    static Category() => Lang("Text")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable_name")},
        {type: "Edit", id: "Varname", default: "EncodedString", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input string")},
        {type: "Edit", id: "VarValue", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Output format")},
        {type: "Radio", id: "outputEncodingFormat", result: "enum", default: "URL", choices: [Lang("URL")], enum: ["URL"]}
    ]

    static GenerateName(ctx, params) {
        return Lang("Encode string") " - " TextOps.Par(params, "Varname") " - " TextOps.Par(params, "VarValue")
            . " - " TextOps.Par(params, "outputEncodingFormat")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        text := TextOps.Text(p.VarValue, params.VarValue)
        switch p.outputEncodingFormat {
            case "URL":
                result := TextOps.UriEncode(text)
            default:
                throw ElementError(Lang("Unknown output encoding format: %1%", p.outputEncodingFormat))
        }
        if (!ctx.SetVar(p.Varname, result))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
