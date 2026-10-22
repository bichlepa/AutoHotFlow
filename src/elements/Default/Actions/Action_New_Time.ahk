#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action New time of the package Default (WI-0118): writes the current time or a given time stamp into a variable.
; Specification: the help text of v1 (help/en/Actions/New_Time.md). Class ID, parameter IDs, defaults and language keys
; are those of v1 (Source_Elements/Default/Actions/New_Time.ahk).
;
;   Varname   the variable that gets the time stamp (YYYYMMDDHH24MISS, a shorter form is allowed as in AutoHotkey)
;   WhichTime Current (the value of A_Now) or Specified (the time of the field Time)
;   Time      the time stamp of Specified; the default is the time when the element is created (MIGRATION M-0107)
;
; A specified time that is not a valid time stamp ends the element with exception; v1 did the same (the check is the
; AutoHotkey v2 function IsTime, see MIGRATION M-0053).
class Action_New_Time extends AhfElement {
    static Mode := "inline"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("New_Time")
    static Category() => Lang("Time")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Variable_name")},
        {type: "Edit", id: "Varname", default: "NewTime", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Time")},
        {type: "Radio", id: "WhichTime", default: "Specified", choices: [Lang("Current time"), Lang("Specified time")],
            result: "enum", enum: ["Current", "Specified"]},
        {type: "DateAndTime", id: "Time", default: A_Now}
    ]

    static GenerateName(ctx, params) {
        timeText := (params.HasProp("WhichTime") && params.WhichTime = "Current") ? Lang("Current time")
            : (params.HasProp("Time") ? params.Time : "")
        return Lang("New_Time") " - " (params.HasProp("Varname") ? params.Varname : "") " - " timeText
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        if (p.WhichTime = "Current") {
            value := A_Now
        } else {
            value := IsObject(p.Time) ? "" : String(p.Time)
            if (!IsTime(value))
                throw ElementError(Lang("%1% is not valid.", Lang("Value '%1%'", value)))
        }
        if (!ctx.SetVar(p.Varname, value))
            throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
        ctx.Finish("normal")
    }
}
