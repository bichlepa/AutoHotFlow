#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Beep of the package Default (WI-0124): emits a tone from the PC speaker (SoundBeep) for the duration. Specification:
; the help text of v1 (help/en/Actions/Beep.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Beep.ahk).
;
; Mode worker: the tone takes the duration and the script waits for it (AutoHotkey). The frequency must be from 37 to
; 32767 Hz, the duration is rounded to whole milliseconds. The v1 text for a duration that is not a number named the
; frequency; the v2 text names the duration (MIGRATION M-0133).
class Action_Beep extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "Bullhorn.png"

    static Name() => Lang("Beep")
    static Category() => Lang("Sound")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Frequency in Hz")},
        {type: "Edit", id: "frequency", default: 523, content: "Expression", WarnIfEmpty: true},
        {type: "Label", label: Lang("Duration in ms")},
        {type: "Edit", id: "duration", default: 150, content: "Expression", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("Beep") " - " TextOps.Par(params, "frequency") " " Lang("Hz") " " TextOps.Par(params, "duration") " " Lang("ms")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        if (!IsNumber(p.frequency))
            throw ElementError(Lang("Frequency is not a number: '%1%'", p.frequency))
        if (!IsNumber(p.duration))
            throw ElementError(Lang("Duration is not a number: '%1%'", p.duration))
        frequency := Integer(Round(p.frequency))
        duration := Integer(Round(p.duration))
        if (frequency < 37 || frequency > 32767)
            throw ElementError(Lang("Frequency must be from 37 to 32767 Hz"))
        try SystemOps.SoundBeep(frequency, duration)
        catch
            throw ElementError(Lang("Sound could not be played"))
        ctx.Finish("normal")
    }
}
