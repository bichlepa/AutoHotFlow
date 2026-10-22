#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Random number of the package Default (WI-0118): writes a random number between MinValue and MaxValue into a
; variable. Specification: the help text of v1 (help/en/Actions/Random_number.md). Class ID, parameter IDs, defaults and
; language keys are those of v1 (Source_Elements/Default/Actions/Random_Number.ahk). The element has no seed, as in v1.
;
;   Varname   the variable that gets the number
;   MinValue  the lower limit, a number (two integers give an Integer, a float one of them a Float)
;   MaxValue  the upper limit, a number; AutoHotkey v2 takes the two limits in either order (v1 too)
;
; Checked against the AutoHotkey v2 function Random: Random(5, 1) gives values from 1 to 5 (verified, WI-0118).
class Action_Random_number extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Random_number")
    static Category() => Lang("Variable") "|" Lang("Maths")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Variable_name")},
        {type: "Edit", id: "Varname", default: "NewVariable", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Minimum value")},
        {type: "Edit", id: "MinValue", default: 0, content: "Number", WarnIfEmpty: true},
        {type: "Label", label: Lang("Maximum value")},
        {type: "Edit", id: "MaxValue", default: 100, content: "Number", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        return Lang("Random_number") " - " (params.HasProp("Varname") ? params.Varname : "") " - "
            . (params.HasProp("MinValue") ? params.MinValue : "") "-" (params.HasProp("MaxValue") ? params.MaxValue : "")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        result := Random(p.MinValue, p.MaxValue)
        if (!ctx.SetVar(p.Varname, result))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
