#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Exponentiation of the package Default (WI-0118): writes Base ** Exponent into a variable. Specification: the help
; text of v1 (help/en/Actions/Exponentiation.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Exponentiation.ahk). The power of two integers is an Integer when it is exact (3 ** 2
; is 9), as in the expression language; a negative exponent gives a Float.
;
;   Varname   the variable that gets the result
;   VarValue  the base (content Number)
;   Exponent  the exponent (content Number)
;
; A result that is not defined (zero to a negative power, a negative base to a fractional power) ends the element with
; exception (MIGRATION M-0104): v1 wrote an empty text.
class Action_Exponentiation extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Exponentiation")
    static Category() => Lang("Maths")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output_Variable_name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Base")},
        {type: "Edit", id: "VarValue", default: 3, content: "Number", WarnIfEmpty: true},
        {type: "Label", label: Lang("Exponent")},
        {type: "Edit", id: "Exponent", default: 2, content: "Number", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        return Lang("Exponentiation") "`n" (params.HasProp("Varname") ? params.Varname : "") " = "
            . (params.HasProp("VarValue") ? params.VarValue : "") "^" (params.HasProp("Exponent") ? params.Exponent : "")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        try {
            result := p.VarValue ** p.Exponent
        } catch {
            throw ElementError(Lang("The result of '%1%' ^ '%2%' is not defined.", p.VarValue, p.Exponent))
        }
        if (!ctx.SetVar(p.Varname, result))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
