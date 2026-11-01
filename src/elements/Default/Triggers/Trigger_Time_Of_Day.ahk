#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Trigger Time of day of the package Default (WI-0131, REQ-TRG-210): fires at the given time of day on the selected week
; days. Parameters, GenerateName and language keys are those of v1 (Source_Elements/Default/Triggers/Time_of_Day.ahk).
;
; The week days are digits as in v1: 1 is Sunday (A_WDay) up to 7 is Saturday. The next time is computed from A_Now and
; waited for with one timer (ctx.After). When the timer fires, A_Now is checked again: a timer that runs early (the
; clock was set back) waits for the rest, and a time that comes late (the clock was set forward, or the computer was
; in standby) still fires. A time missed that way is not repeated: the next time is the first one after A_Now.
; The delay counts whole seconds less the milliseconds of the current second, so the timer fires at the time itself.
class Trigger_Time_Of_Day extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Time_Of_Day")
    static Category() => Lang("Time")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Weekdays")},
        {type: "Weekdays", id: "WeekDays", default: "1234567", WarnIfEmpty: true},
        {type: "Label", label: Lang("Time of day")},
        {type: "DateAndTime", id: "Time", default: A_Now, format: "Time"}
    ]

    ; "Time of day - 10:00:00 - Weekdays: '1234567'" (v1 Element_GenerateName_Trigger_Time_Of_Day).
    static GenerateName(ctx, params) {
        weekDays := params.HasProp("WeekDays") ? params.WeekDays : ""
        timeText := ""
        digits := this._Digits(params.HasProp("Time") ? params.Time : "")
        if (StrLen(digits) >= 6)
            timeText := SubStr(digits, -6, 2) ":" SubStr(digits, -4, 2) ":" SubStr(digits, -2)
        return Lang("Time_Of_Day") " - " timeText " - " Lang("Weekdays: '%1%'", IsObject(weekDays) ? "" : weekDays)
    }

    static CheckSettings(form, params, staticValues) {
    }

    ; Arms the trigger: the first time after A_Now on the week days (an Enable error is the v1 text, the trigger stays
    ; disarmed). The host calls Disable after an error, and the timer is cancelled with the context.
    static Enable(ctx, params) {
        ctx.State.weekDays := this.WeekDaysOf(params)
        ctx.State.hhmmss := this.TimeOfDay(params.HasProp("Time") ? params.Time : "")
        this._Arm(ctx, A_Now)
        return ""
    }

    ; The timers are cancelled with the context (CancelTimers); nothing else to release.
    static Disable(ctx) {
    }

    ; The thread variables: none (v1 Element_postTrigger_Trigger_Time_Of_Day sets nothing).
    static TriggerVariables(params, data) => Map()

    ; The first time after now that matches the week days and the time of day, as YYYYMMDDHH24MISS, or "" when there is
    ; none (no week day). Pure function (the unit test checks it with fixed times). now is a timestamp of 14 digits.
    static NextTime(weekDays, hhmmss, now) {
        if (weekDays = "" || hhmmss = "")
            return ""
        loop 8 {                                    ; today and the seven days after it
            day := DateAdd(now, A_Index - 1, "Days")
            candidate := SubStr(day, 1, 8) hhmmss
            if (candidate > now && InStr(weekDays, FormatTime(candidate, "WDay")))
                return candidate
        }
        return ""
    }

    ; The week days of the parameters: the digits in ascending order (1 Sunday to 7 Saturday). "" if none is selected.
    static WeekDaysOf(params) {
        value := params.HasProp("WeekDays") ? params.WeekDays : ""
        if (IsObject(value))
            return ""
        digits := ""
        loop 7 {
            if (InStr(String(value), A_Index))
                digits .= A_Index
        }
        return digits
    }

    ; The time of day as HHmmss from a time stamp (any date) or a time text. Throws ElementError with the v1 text for a value
    ; that is not a time.
    static TimeOfDay(value) {
        digits := this._Digits(value)
        if (StrLen(digits) < 6 || SubStr(digits, -6, 2) > 23 || SubStr(digits, -4, 2) > 59 || SubStr(digits, -2) > 59)
            throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "Time", IsObject(value) ? "" : value))
        return SubStr(digits, -6)
    }

    ; Waits for the next time: one timer, checked again at its end (see the header).
    static _Arm(ctx, now) {
        next := this.NextTime(ctx.State.weekDays, ctx.State.hhmmss, now)
        if (next = "")
            throw ElementError(Lang("Can't calculate next trigger time"))
        ctx.State.target := next
        ctx.After(this._DelayMs(next), () => this._Due(ctx))
    }

    ; The timer ran: fire at the time, or wait for it when the clock says it is not yet there.
    static _Due(ctx) {
        now := A_Now
        if (now < ctx.State.target) {
            ctx.After(this._DelayMs(ctx.State.target), () => this._Due(ctx))
            return
        }
        next := this.NextTime(ctx.State.weekDays, ctx.State.hhmmss, now)
        if (next = "") {
            ctx.Log("f0", Lang("Can't calculate next trigger time"))
            return
        }
        ctx.State.target := next
        ctx.After(this._DelayMs(next), () => this._Due(ctx))    ; the next round first (ELEMENT-API 3.5)
        ctx.Fire()
    }

    ; The delay to a time stamp in milliseconds: whole seconds from A_Now, less the milliseconds of this second.
    static _DelayMs(target) => Max(1, DateDiff(target, A_Now, "Seconds") * 1000 - A_MSec)

    ; The digits of a time text or stamp (an object or a text without digits gives "").
    static _Digits(value) => IsObject(value) ? "" : RegExReplace(String(value), "\D", "")
}
