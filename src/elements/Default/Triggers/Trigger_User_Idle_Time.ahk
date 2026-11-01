#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Trigger User idle time of the package Default (WI-0131, REQ-TRG-250): fires once when the user has been idle for the
; period, and again after the user was active and idle for the period once more. Parameters, GenerateName and language
; keys are those of v1 (Source_Elements/Default/Triggers/User_Idle_Time.ahk).
;
; The idle time comes through SystemOps (E0103), so a test answers it from a script. The state machine is the one of v1:
; a tick reads the idle time; while the user is not idle, the trigger fires when the idle time reaches the period and then
; checks again after half the period; while the user is idle, it checks again when the idle time is below the period
; (then the next idle period starts) or after half the period. Each tick schedules its next round before it fires.
class Trigger_User_Idle_Time extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    ; The values of Unit and Method, in the order of their choices (v1 enums).
    static UNITS := ["MilliSeconds", "Seconds", "Minutes", "Hours"]
    static METHODS := ["TimeIdle", "TimeIdlePhysical"]

    static Name() => Lang("User_Idle_Time")
    static Category() => Lang("User_interaction") "|" Lang("Time")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Period of time")},
        {type: "edit", id: "Interval", default: 10, content: "PositiveNumber", WarnIfEmpty: true},
        {type: "Radio", id: "Unit", default: "Seconds", result: "enum"
            , choices: [Lang("Milliseconds"), Lang("Seconds"), Lang("Minutes"), Lang("Hours")]
            , enum: this.UNITS},
        {type: "Label", label: Lang("Method")},
        {type: "Radio", id: "Method", default: "TimeIdle", result: "enum"
            , choices: [Lang("Method: %1%", Lang("Default")), Lang("Method: %1%", Lang("Physical"))]
            , enum: this.METHODS}
    ]

    ; "User idle time - 10 s" (v1 Element_GenerateName_Trigger_User_Idle_Time).
    static GenerateName(ctx, params) {
        interval := params.HasProp("Interval") ? params.Interval : ""
        switch this.UnitOf(params.HasProp("Unit") ? params.Unit : "") {
            case "MilliSeconds": unitText := Lang("ms #Milliseconds")
            case "Seconds":      unitText := Lang("s #Seconds")
            case "Minutes":      unitText := Lang("m #Minutes")
            case "Hours":        unitText := Lang("h #Hours")
            default:             unitText := ""
        }
        return Lang("User_Idle_Time") " - " interval " " unitText
    }

    static CheckSettings(form, params, staticValues) {
    }

    ; Starts the state machine: the first tick comes at once (v1: a timer of -1). Refuses an interval that is not above 0,
    ; an unknown unit and an unknown method with the v1 texts.
    static Enable(ctx, params) {
        period := this.PeriodMs(params.HasProp("Interval") ? params.Interval : "", params.HasProp("Unit") ? params.Unit : "")
        method := this.MethodOf(params.HasProp("Method") ? params.Method : "")
        ctx.State.period := period
        ctx.State.method := method
        ctx.State.idle := false
        ctx.After(0, () => this._Tick(ctx))
        return ""
    }

    ; The timers are cancelled with the context (CancelTimers); nothing else to release.
    static Disable(ctx) {
    }

    ; The thread variables: none (v1 Element_postTrigger_Trigger_User_Idle_Time sets nothing).
    static TriggerVariables(params, data) => Map()

    ; One tick of the state machine (see the header). A failing idle time read ends the tick with the error after the next
    ; round is scheduled, so the trigger stays armed (ELEMENT-API-V2 3.5).
    static _Tick(ctx) {
        period := ctx.State.period
        try {
            idle := this._IdleTime(ctx.State.method)
        } catch as e {
            ctx.After(period / 2, () => this._Tick(ctx))
            throw e
        }
        remaining := period - idle
        if (ctx.State.idle) {
            if (remaining > 0) {
                ctx.State.idle := false
                ctx.After(remaining, () => this._Tick(ctx))
            } else {
                ctx.After(period / 2, () => this._Tick(ctx))
            }
        } else if (remaining > 0) {
            ctx.After(remaining, () => this._Tick(ctx))
        } else {
            ctx.State.idle := true
            ctx.After(period / 2, () => this._Tick(ctx))
            ctx.Fire()
        }
    }

    ; The idle time in milliseconds of the method: TimeIdle counts the keyboard and mouse input of the user and of the
    ; simulated input; TimeIdlePhysical only the physical input.
    static _IdleTime(method) {
        if (method = "TimeIdlePhysical")
            return SystemOps.TimeIdlePhysical()
        return SystemOps.TimeIdle()
    }

    ; The period in milliseconds for an interval and a unit. Throws ElementError with the v1 texts.
    static PeriodMs(interval, unit) {
        if (IsObject(interval) || !IsNumber(interval) || interval <= 0)
            throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "interval", interval))
        switch this.UnitOf(unit) {
            case "MilliSeconds": factor := 1
            case "Seconds":      factor := 1000
            case "Minutes":      factor := 60000
            case "Hours":        factor := 3600000
            default: throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "Unit", IsObject(unit) ? "" : unit))
        }
        return interval * factor
    }

    ; The value of METHODS for a method text (any case). Throws ElementError with the v1 text for another one.
    static MethodOf(method) {
        if (!IsObject(method))
            for name in this.METHODS {
                if (name = method)
                    return name
            }
        throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "method", IsObject(method) ? "" : method))
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
