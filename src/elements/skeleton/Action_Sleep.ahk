#Requires AutoHotkey v2.0
#Include ..\base\AhfElement.ahk
#Include ..\base\ElementRegistry.ahk

; Walking-skeleton version of the v1 Action Sleep (doc/ELEMENT-API-V2.md section 4). Phase 2 only.
; Parameters arrive evaluated. Names are plain text: Lang() does not exist yet.
class Action_Sleep extends AhfElement {
    static Mode := "inline"
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "sleep.ico"

    static Name() => "Sleep"
    static Category() => "Flow_control"

    static Run(ctx, params) {
        ctx.After(Action_Sleep.ToMs(params), () => ctx.Finish("normal"))
    }

    ; Converts Duration and Unit to milliseconds. Unit defaults to "Seconds" as in v1 (Radio default 2).
    ; Throws ElementError for a missing, non-numeric or negative duration, or an unknown unit.
    static ToMs(params) {
        if (!params.HasProp("Duration") || !IsNumber(params.Duration) || params.Duration < 0)
            throw ElementError("Sleep: Duration must be a number >= 0")
        unit := params.HasProp("Unit") ? StrLower(params.Unit) : "seconds"
        switch unit {
            case "milliseconds": factor := 1
            case "seconds":      factor := 1000
            case "minutes":      factor := 60000
            default: throw ElementError("Sleep: unknown Unit '" unit "'")
        }
        return params.Duration * factor
    }
}

ElementRegistry.Register(Action_Sleep)
