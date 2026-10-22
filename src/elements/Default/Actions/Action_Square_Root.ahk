#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Square root of the package Default (WI-0118): writes the square root of a number into a variable. Specification:
; the help text of v1 (help/en/Actions/Square_Root.md). Class ID, parameter IDs, defaults and language keys are those of
; v1 (Source_Elements/Default/Actions/Square_Root.ahk).
;
;   Varname   the variable that gets the result
;   VarValue  the input number (content Number)
;
; A negative input ends the element with exception (MIGRATION M-0104): v1 wrote an empty text. The root of an Integer
; that is exact is an Integer (the root of 16 is 4, not 4.0), as 3 ** 2 is 9 in the expression language; any other root
; is a Float. AutoHotkey v2 gives 4.0 for Sqrt(16), so this rule is ours (decision of WI-0118, to be confirmed).
class Action_Square_Root extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Square_Root")
    static Category() => Lang("Maths")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input number")},
        {type: "Edit", id: "VarValue", default: 16, content: "Number", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        return Lang("Square_Root") " - " (params.HasProp("Varname") ? params.Varname : "") " - "
            . (params.HasProp("VarValue") ? params.VarValue : "")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        x := p.VarValue
        if (x < 0)
            throw ElementError(Lang("Square root of a negative number is not defined: '%1%'.", x))
        result := Sqrt(x)
        if (IsInteger(x) && result = Floor(result))
            result := Integer(result)
        if (!ctx.SetVar(p.Varname, result))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
