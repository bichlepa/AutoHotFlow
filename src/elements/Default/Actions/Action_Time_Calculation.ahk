#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TimeOps.ahk

; Action Time calculation of the package Default (WI-0118): adds an amount of seconds, minutes, hours or days to a time
; stamp and writes the result into a variable. Specification: the help text of v1 (help/en/Actions/Time_Calculation.md).
; Class ID, parameter IDs and language keys are those of v1 (Source_Elements/Default/Actions/Time_calculation.ahk); the
; default of Unit is the value of the position that v1 wrote (2 = Minutes, MIGRATION M-0099).
;
;   Varname    the variable that gets the result (YYYYMMDDHH24MISS)
;   InputTime  the time stamp, an expression; it must be a valid time stamp (IsTime, MIGRATION M-0053)
;   Units      the amount to add (a whole number; a fraction is cut off by AutoHotkey)
;   Unit       Seconds, Minutes, Hours or Days (the function DateAdd)
class Action_Time_Calculation extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Time_Calculation")
    static Category() => Lang("Time")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "CalculatedTime", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Input time")},
        {type: "Edit", id: "InputTime", default: "InputTime", content: "Expression", WarnIfEmpty: true},
        {type: "Label", label: Lang("Time to add")},
        {type: "Edit", id: "Units", default: 10, content: "Number", WarnIfEmpty: true},
        {type: "Label", label: Lang("Which unit"), size: "small"},
        {type: "Radio", id: "Unit", default: "Minutes", choices: [Lang("Seconds"), Lang("Minutes"), Lang("Hours"),
            Lang("Days")], result: "enum", enum: ["Seconds", "Minutes", "Hours", "Days"]}
    ]

    static GenerateName(ctx, params) {
        unitText := params.HasProp("Unit") ? Lang(params.Unit) : ""
        return Lang("Time_Calculation") " - " (params.HasProp("Varname") ? params.Varname : "") " = "
            . (params.HasProp("InputTime") ? params.InputTime : "") " + " (params.HasProp("Units") ? params.Units : "")
            . " " unitText
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        input := IsObject(p.InputTime) ? "" : String(p.InputTime)
        if (!IsTime(input))
            throw ElementError(Lang("Input time is not a time: '%1%'.", input))
        if (!TimeOps.IsUnit(p.Unit))
            throw ElementError(Lang("Unit '%1%' is not known.", p.Unit))
        try {
            result := DateAdd(input, p.Units, p.Unit)
        } catch as e {
            throw ElementError(Lang("Time calculation failed: %1%", e.Message))
        }
        if (!ctx.SetVar(p.Varname, result))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
