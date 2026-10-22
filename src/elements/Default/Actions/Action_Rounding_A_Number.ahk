#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Rounding a number of the package Default (WI-0118): writes a number rounded to some places after the decimal
; point into a variable. Specification: the help text of v1 (help/en/Actions/Rounding_A_Number.md). Class ID, parameter
; IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Rounding_a_number.ahk).
;
;   Varname      the variable that gets the result
;   VarValue     the input number
;   Places       the number of places after the decimal point (negative: places before it); a fraction is cut off
;                (AutoHotkey Round takes a whole number; v1 did the same)
;   Roundingtype round (the nearest value), roundUp (towards plus infinity), roundDown (towards minus infinity)
;
; The up and down rounding are the v1 algorithm: round, then step one unit of the last place in the direction and round
; again (the trailing zeros go).
class Action_Rounding_A_Number extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Rounding_A_Number")
    static Category() => Lang("Maths")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input number")},
        {type: "Edit", id: "VarValue", default: "1.2345", content: "Number", WarnIfEmpty: true},
        {type: "Label", label: Lang("Places after comma")},
        {type: "Edit", id: "Places", default: 0, content: "Number", WarnIfEmpty: true},
        {type: "Label", label: Lang("Operation")},
        {type: "Radio", id: "Roundingtype", default: "round", choices: [Lang("Round normally"), Lang("Round up"),
            Lang("Round down")], result: "enum", enum: ["round", "roundUp", "roundDown"]}
    ]

    static GenerateName(ctx, params) {
        return Lang("Rounding_A_Number") " - " (params.HasProp("Varname") ? params.Varname : "") " - "
            . (params.HasProp("VarValue") ? params.VarValue : "") " - " (params.HasProp("Places") ? params.Places : "")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        value := p.VarValue
        places := Integer(p.Places)
        ; Round gives a text for places above zero ("1.20"); Number() makes it a number, so "1.2" has no trailing zero
        ; (MIGRATION M-0106)
        result := Number(Round(value, places))
        switch p.Roundingtype {
            case "round":
                ; the nearest value, already done
            case "roundUp":
                if (result < value)
                    result := Number(Round(result + 10 ** -places, places))
            case "roundDown":
                if (result > value)
                    result := Number(Round(result - 10 ** -places, places))
            default:
                throw ElementError(Lang("Operation '%1%' is not known.", p.Roundingtype))
        }
        if (!ctx.SetVar(p.Varname, result))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
