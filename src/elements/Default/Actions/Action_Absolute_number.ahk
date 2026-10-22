#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Absolute number of the package Default (WI-0118): writes the absolute value of a number into a variable.
; Specification: the help text of v1 (help/en/Actions/Absolute_number.md). Class ID, parameter IDs, defaults and language
; keys are those of v1 (Source_Elements/Default/Actions/Absolute_Number.ahk).
;
;   Varname   the variable that gets the result
;   VarValue  the input number, an expression (the element checks that the value is a number)
;
; A value that is not a number ends the element with exception and the v1 text (the same in both type modes).
class Action_Absolute_number extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Absolute_number")
    static Category() => Lang("Maths")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output_Variable_name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input_number")},
        {type: "Edit", id: "VarValue", default: -2, content: "Expression", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        return Lang("Absolute_number") "`n" (params.HasProp("Varname") ? params.Varname : "") " = |"
            . (params.HasProp("VarValue") ? params.VarValue : "") "|"
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        value := p.VarValue
        if (!IsNumber(value))
            throw ElementError(Lang("Value is not a number: %1%", IsObject(value) ? Type(value) : value))
        if (!ctx.SetVar(p.Varname, Abs(value)))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
