#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Sleep of the package Default (WI-0047, doc/ELEMENT-API-V2.md section 4): waits for Duration (an expression)
; in the Unit, then finishes "normal". Parameters, GenerateName and language keys are those of v1
; (Source_Elements/Default/Actions/Sleep.ahk). It never blocks the engine: it waits with a timer of the context
; (ctx.After), which the context removes when the instance is stopped, so it needs no Stop.
class Action_Sleep extends AhfElement {
    static Mode      := "inline"
    static ActsOnSystem := false
    static Level     := "Beginner"
    static Stability := "Stable"
    static Icon      := "Sleep.ico"

    ; The values of the parameter Unit, in the order of its choices (the default 2 is an index into this list).
    static UNITS := ["Milliseconds", "Seconds", "Minutes"]

    static Name()     => Lang("Sleep")
    static Category() => Lang("Flow_control")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Duration")},
        {type: "edit", id: "Duration", default: 2, content: "Expression", WarnIfEmpty: true},
        {type: "Radio", id: "Unit", default: 2, result: "enum"
            , choices: [Lang("Milliseconds"), Lang("Seconds"), Lang("Minutes")]
            , enum: ["Milliseconds", "Seconds", "Minutes"]}
    ]

    ; "Sleep: 2 s" (v1 Element_GenerateName_Action_Sleep). params are the stored parameters.
    static GenerateName(ctx, params) {
        duration := params.HasProp("Duration") ? params.Duration : 2
        switch this.UnitOf(params.HasProp("Unit") ? params.Unit : 2) {
            case "Milliseconds": d := duration " " Lang("ms #Milliseconds")
            case "Seconds":      d := duration " " Lang("s #Seconds")
            case "Minutes":      d := duration " " Lang("m #Minutes")
            default:             d := duration
        }
        return Lang("Sleep") ": " d
    }

    static CheckSettings(form, params, staticValues) {
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)          ; throws on error -> result "exception"
        ctx.After(this.ToMs(p.Duration, p.Unit), () => ctx.Finish("normal"))
    }

    ; The duration in milliseconds. duration: the evaluated Duration; unit: a value of UNITS (any case) or its index (the
    ; default of the parameter, which v1 stores as the index when a flow does not have the parameter). Throws
    ; ElementError for a duration that is not a number of 0 or more, or an unknown unit.
    static ToMs(duration, unit) {
        if (IsObject(duration) || !IsNumber(duration) || duration < 0)
            throw ElementError("Sleep: Duration must be a number >= 0, not '" (IsObject(duration) ? Type(duration) : duration) "'")
        switch this.UnitOf(unit) {
            case "Milliseconds": factor := 1
            case "Seconds":      factor := 1000
            case "Minutes":      factor := 60000
            default: throw ElementError("Sleep: unknown Unit '" (IsObject(unit) ? Type(unit) : unit) "'")
        }
        return duration * factor
    }

    ; The value of UNITS for a stored Unit (a text in any case, or an index 1 to 3); "" if it is none of them.
    static UnitOf(unit) {
        if (IsObject(unit))
            return ""
        if (IsInteger(unit))
            return (unit >= 1 && unit <= this.UNITS.Length) ? this.UNITS[Integer(unit)] : ""
        for name in this.UNITS {
            if (name = unit)
                return name
        }
        return ""
    }
}
