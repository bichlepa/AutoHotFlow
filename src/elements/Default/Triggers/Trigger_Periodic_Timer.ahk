#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Trigger Periodic Timer of the package Default (WI-0063, REQ-TRG-210): fires every Interval in the Unit (milliseconds,
; seconds or minutes). Parameters, GenerateName and language keys are those of v1
; (Source_Elements/Default/Triggers/Periodic_Timer.ahk). The timer is a SetTimer of the trigger context (ctx.Guard), so
; an error in a tick goes to evt.trigger.error and the trigger stays armed. A tick after the disarm does nothing.
; There is no minimum interval beyond the timer resolution: an interval below 1 ms runs every 1 ms, and a flood of
; instances is the job of the execution guard (WI-0066).
class Trigger_Periodic_Timer extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    ; The values of the parameter Unit, in the order of its choices (v1 enum).
    static UNITS := ["MilliSeconds", "Seconds", "Minutes"]

    static Name() => Lang("Periodic_Timer")
    static Category() => Lang("Time")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Time_interval")},
        {type: "edit", id: "Interval", default: 10, content: "Number", WarnIfEmpty: true},
        {type: "Radio", id: "Unit", default: "Seconds", result: "enum"
            , choices: [Lang("Milliseconds"), Lang("Seconds"), Lang("Minutes")]
            , enum: this.UNITS}
    ]

    ; "Periodic timer - 10 Seconds" (v1 Element_GenerateName_Trigger_Periodic_Timer).
    static GenerateName(ctx, params) {
        interval := params.HasProp("Interval") ? params.Interval : ""
        switch this.UnitOf(params.HasProp("Unit") ? params.Unit : "") {
            case "MilliSeconds": unitText := Lang("Milliseconds")
            case "Seconds":      unitText := Lang("Seconds")
            case "Minutes":      unitText := Lang("Minutes")
            default:             unitText := ""
        }
        return Lang("Periodic_Timer") " - " interval " " unitText
    }

    static CheckSettings(form, params, staticValues) {
    }

    ; Refuses an interval that is not above 0 and an unknown unit (ElementError with the v1 text). Otherwise a SetTimer
    ; of the context runs the ticks; the timer is the first tick after one interval (as v1).
    static Enable(ctx, params) {
        period := this.PeriodMs(params.HasProp("Interval") ? params.Interval : "", params.HasProp("Unit") ? params.Unit : "")
        tick := ctx.Guard(() => this._Tick(ctx))
        ctx.State.timer := tick          ; kept for Disable
        SetTimer(tick, period)
        return ""
    }

    ; Stops the timer. Also when Enable failed after the timer was set (the host calls Disable then).
    static Disable(ctx) {
        if (ctx.State.HasProp("timer"))
            SetTimer(ctx.State.timer, 0)
    }

    ; The thread variables: none (v1 Element_postTrigger_Trigger_Periodic_Timer sets nothing).
    static TriggerVariables(params, data) => Map()

    ; One tick: the trigger fires. A tick that runs after the disarm does nothing.
    static _Tick(ctx) {
        if (ctx.IsOpen)
            ctx.Fire()
    }

    ; The period in milliseconds, rounded, at least 1. Throws ElementError with the v1 text for an interval that is not
    ; a number above 0, for a unit that is none of UNITS, and for a period that SetTimer cannot take.
    static PeriodMs(interval, unit) {
        if (IsObject(interval) || !IsNumber(interval) || interval <= 0)
            throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "interval", interval))
        switch this.UnitOf(unit) {
            case "MilliSeconds": factor := 1
            case "Seconds":      factor := 1000
            case "Minutes":      factor := 60000
            default: throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "Unit", IsObject(unit) ? "" : unit))
        }
        ms := Max(1, Round(interval * factor))
        if (ms > 0x7FFFFFFF)            ; SetTimer takes at most 2^31 - 1 ms
            throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "interval", interval))
        return Integer(ms)
    }

    ; The value of UNITS for a unit text (any case, as the v1 switch); "" if it is none of them.
    static UnitOf(unit) {
        if (IsObject(unit))
            return ""
        for name in this.UNITS {
            if (name = unit)
                return name
        }
        return ""
    }
}
