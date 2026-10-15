#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Condition Variable content is of the package Default (WI-0052): "yes" if the value of a variable (or of an expression)
; is of the chosen type. Specification: the help text of v1 (help/en/Conditions/Variable_content_is.html); the truth
; table that the v1 example flow "variable test" (tests/data/flows/v1_examples/Flow 1010290492.json) encodes agrees with
; it. Parameter IDs, defaults, enum values and language keys are those of v1
; (Source_Elements/Default/Conditions/Variable_content_is.ahk).
;
;   varname              a variable name or an expression, as chosen in varnameContent ("VariableName", default, or
;                        "Expression")
;   variableContentType  object (list), time, number, integer, float, digit, xdigit, alnum, alpha, upper, lower, space
;
; The type tests are those of AutoHotkey v2 (IsNumber, IsInteger, IsFloat, IsTime, IsDigit, ...) on the text form of
; the value, so a number that a variable holds (Integer 5, Float 5.5) is tested like the text "5" and "5.5". The
; types digit, xdigit, alnum, alpha, upper, lower and space are true for the empty text, as the help says (explicit
; here: v1 did so, and the empty text is also what a variable that does not exist gives). A Map is only an "object",
; every other value is never an "object". The details where AutoHotkey v2 differs from v1 are in MIGRATION M-0053.
class Condition_Variable_content_is extends AhfElement {
    static Mode := "inline"
    static Level := "Beginner"
    static Stability := "Stable"

    ; The values of the parameter variableContentType, in the order of its choices
    static TYPES := ["object", "time", "number", "integer", "float", "digit", "xdigit", "alnum", "alpha", "upper"
        , "lower", "space"]

    static Name() => Lang("Variable content is")
    static Category() => Lang("Variable")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Variable name or expression")},
        {type: "Edit", id: "varname", default: "myVariable", content: ["VariableName", "Expression"]
            , contentID: "varnameContent", contentDefault: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Expected content type")},
        {type: "Radio", id: "variableContentType", result: "enum", default: "object"
            , choices: [Lang("List"), Lang("Time"), Lang("Number"), Lang("Integer"), Lang("Floating point number")
                , Lang("Decimal digits"), Lang("Hexadecimal digits"), Lang("Alphanumeric string"), Lang("Alphabetic string")
                , Lang("String with only uppercase characters"), Lang("String with only lowercase characters")
                , Lang("Whitespaces")]
            , enum: ["object", "time", "number", "integer", "float", "digit", "xdigit", "alnum", "alpha", "upper"
                , "lower", "space"]}
    ]

    static GenerateName(ctx, params) {
        kind := params.HasProp("variableContentType") ? params.variableContentType : "object"
        switch kind {
            case "object": typeText := Lang("List")
            case "time": typeText := Lang("Time")
            case "number": typeText := Lang("Number")
            case "integer": typeText := Lang("Integer")
            case "float": typeText := Lang("Floating point number")
            case "digit": typeText := Lang("Decimal digits")
            case "xdigit": typeText := Lang("Hexadecimal digits")
            case "alnum": typeText := Lang("Alphanumeric string")
            case "alpha": typeText := Lang("Alphabetic string")
            case "upper": typeText := Lang("String with only uppercase characters")
            case "lower": typeText := Lang("String with only lowercase characters")
            case "space": typeText := Lang("Whitespaces")
            default: typeText := kind
        }
        return Lang("Variable content is %1%", typeText) " - " (params.HasProp("varname") ? params.varname : "")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        content := params.HasProp("varnameContent") ? params.varnameContent : "VariableName"
        if (content = "VariableName") {
            ; A variable that does not exist is the empty text (v1 as well). The type is asked first so that a big list
            ; is not copied just to see that it is a list.
            value := (ctx.GetVarType(p.varname) = "object") ? Map() : ctx.GetVar(p.varname, "")
        } else {
            value := p.varname
        }
        ctx.Finish(this.HasType(value, p.variableContentType) ? "yes" : "no")
    }

    ; True if value is of the type kind (one of TYPES, any case). Throws ElementError for another one.
    static HasType(value, kind) {
        kind := StrLower(kind)
        known := false
        for name in this.TYPES {
            if (name = kind)
                known := true
        }
        if (!known)
            throw ElementError("Variable content is: unknown content type '" kind "'")
        if (IsObject(value))
            return (value is Map) && kind = "object"
        if (kind = "object")
            return false
        text := String(value)
        switch kind {
            case "time": return IsTime(text) ? true : false
            case "number": return IsNumber(text) ? true : false
            case "integer": return IsInteger(text) ? true : false
            case "float": return IsFloat(text) ? true : false
        }
        if (text = "")
            return true
        switch kind {
            case "digit": return IsDigit(text) ? true : false
            case "xdigit": return IsXDigit(text) ? true : false
            case "alnum": return IsAlnum(text) ? true : false
            case "alpha": return IsAlpha(text) ? true : false
            case "upper": return IsUpper(text) ? true : false
            case "lower": return IsLower(text) ? true : false
        }
        return IsSpace(text) ? true : false
    }
}
