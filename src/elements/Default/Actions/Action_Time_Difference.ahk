#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TimeOps.ahk

; Action Time difference of the package Default (WI-0118): writes the time between two time stamps, in seconds, minutes,
; hours or days, into a variable. Specification: the help text of v1 (help/en/Actions/Time_Difference.md). Class ID,
; parameter IDs and language keys are those of v1 (Source_Elements/Default/Actions/Time_difference.ahk); the default of
; Unit is the value of the position that v1 wrote (2 = Minutes, MIGRATION M-0099).
;
;   Varname     the variable that gets the difference
;   InputTime   the first time stamp, an expression (default: the built-in variable a_now)
;   InputTime2  the second time stamp, an expression
;   Unit        Seconds, Minutes, Hours or Days
;
; The result is InputTime minus InputTime2 (the function DateDiff). Both time stamps must be valid (IsTime, MIGRATION
; M-0053), otherwise the element ends with exception.
class Action_Time_Difference extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Time_Difference")
    static Category() => Lang("Time")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "TimeDifference", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("First input time")},
        {type: "Edit", id: "InputTime", default: "a_now", content: "Expression", WarnIfEmpty: true},
        {type: "Label", label: Lang("Second input time")},
        {type: "Edit", id: "InputTime2", default: "InputTime", content: "Expression", WarnIfEmpty: true},
        {type: "Label", label: Lang("Which unit")},
        {type: "Radio", id: "Unit", default: "Minutes", choices: [Lang("Seconds"), Lang("Minutes"), Lang("Hours"),
            Lang("Days")], result: "enum", enum: ["Seconds", "Minutes", "Hours", "Days"]}
    ]

    static GenerateName(ctx, params) {
        unitText := params.HasProp("Unit") ? Lang(params.Unit) : ""
        return Lang("Time_Difference") " - " (params.HasProp("Varname") ? params.Varname : "") " = "
            . (params.HasProp("InputTime") ? params.InputTime : "") " - "
            . (params.HasProp("InputTime2") ? params.InputTime2 : "") " - " unitText
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        first := IsObject(p.InputTime) ? "" : String(p.InputTime)
        if (!IsTime(first))
            throw ElementError(Lang("First input time does not contain a time: '%1%'.", first))
        second := IsObject(p.InputTime2) ? "" : String(p.InputTime2)
        if (!IsTime(second))
            throw ElementError(Lang("Second input time does not contain a time: '%1%'.", second))
        if (!TimeOps.IsUnit(p.Unit))
            throw ElementError(Lang("Unit '%1%' is not known.", p.Unit))
        try {
            result := DateDiff(first, second, p.Unit)
        } catch as e {
            throw ElementError(Lang("Time calculation failed: %1%", e.Message))
        }
        if (!ctx.SetVar(p.Varname, result))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
