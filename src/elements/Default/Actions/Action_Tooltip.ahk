#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk

; Action Tooltip of the package Default (WI-0056): shows a tooltip for Duration, optionally following the mouse.
; Specification: the help text of v1 (help/en/Actions/tooltip.html), parameters, defaults and language keys of v1
; (Source_Elements/Default/Actions/Tooltip.ahk).
;
; Mode decision (WI-0056, task 3): worker. A tooltip is UI, and the engine shows no UI (ARCHITECTURE 1, goal 2). The
; element does not hold its worker for the duration: as in v1 it finishes at once ("normal") and the tooltip is removed by
; a timer of the worker process that outlives the job. A worker that holds a tooltip for its duration would occupy a pool
; slot (ARCHITECTURE 6.4) and delay the flow. Limit: the timer lives in the worker process; when the worker is ended
; (idle time, crash) the tooltip disappears early, and a stop of the flow does not remove it (MIGRATION M-0065).
;
; One tooltip per worker process, as in v1 (number 13, a new tooltip replaces the one shown and its timer).
class Action_Tooltip extends AhfElement {
    static Mode := "worker"
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "Tooltip.png"

    static WHICH := 13                ; the tooltip number of v1, so it does not clash with other tooltips
    static FOLLOW_MS := 10            ; the interval of the mouse follow, as v1
    static _removeTimer := ""         ; the timer that removes the tooltip of this process (v1: runActionTooltip_RemoveTooltip)
    static _followTimer := ""         ; the timer that moves the tooltip with the mouse (v1: runActionTooltip_follow_mouse)
    static _x := -1                   ; the mouse position of the last move
    static _y := -1
    static _text := ""                ; the text of the tooltip that follows the mouse

    static Name() => Lang("Tooltip")
    static Category() => Lang("User_interaction")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Text_to_show")},
        {type: "multilineEdit", id: "text", default: Lang("Message"), content: "String", contentConvertObjects: true
            , WarnIfEmpty: true},
        {type: "Label", label: Lang("Duration")},
        {type: "edit", id: "duration", default: 2, content: "Expression", WarnIfEmpty: true},
        {type: "Radio", id: "Unit", default: 2, result: "enum"
            , choices: [Lang("Milliseconds"), Lang("Seconds"), Lang("Minutes")]
            , enum: ["Milliseconds", "Seconds", "Minutes"]},
        {type: "Label", label: Lang("Options")},
        {type: "Checkbox", id: "follow_mouse", default: 1, label: Lang("Follow_Mouse")}
    ]

    ; "Tooltip: text - duration - Follow mouse" (v1 Element_GenerateName_Action_Tooltip, simplified)
    static GenerateName(ctx, params) {
        text := params.HasProp("text") ? params.text : ""
        duration := params.HasProp("duration") ? params.duration : 2
        return Lang("Tooltip") ": " text " - " duration
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)           ; throws on error -> result "exception"
        ms := this.ToMs(p.duration, p.Unit)
        this._StopTimers()                    ; a tooltip shown before is replaced by this one (v1: same timer)
        Dialogs.ToolTip(p.text, , , this.WHICH)
        if (DialogOps.Truthy(p.follow_mouse)) {
            this._text := p.text
            this._x := -1
            this._followTimer := () => this._Follow()
            SetTimer(this._followTimer, this.FOLLOW_MS)
        }
        this._removeTimer := () => this._Remove()
        SetTimer(this._removeTimer, -Max(ms, 1))      ; a timer of 0 would switch the timer off, not fire it
        ctx.Finish("normal")
    }

    ; The duration in milliseconds. unit: a choice text (any case) or its index (the default 2 is Seconds).
    static ToMs(duration, unit) {
        if (IsObject(duration) || !IsNumber(duration) || duration < 0)
            throw ElementError("Tooltip: Duration must be a number of 0 or more, not '" (IsObject(duration) ? Type(duration) : duration) "'")
        if (IsInteger(unit) && unit >= 1 && unit <= 3)
            factor := [1, 1000, 60000][unit]
        else if (!IsObject(unit) && StrLower(String(unit)) = "milliseconds")
            factor := 1
        else if (!IsObject(unit) && StrLower(String(unit)) = "seconds")
            factor := 1000
        else if (!IsObject(unit) && StrLower(String(unit)) = "minutes")
            factor := 60000
        else
            throw ElementError("Tooltip: unknown Unit '" (IsObject(unit) ? Type(unit) : unit) "'")
        return Integer(duration * factor)
    }

    ; Moves the tooltip to the mouse when the mouse has moved (v1 follow timer).
    static _Follow() {
        MouseGetPos(&x, &y)
        if (x = this._x && y = this._y)
            return
        this._x := x
        this._y := y
        Dialogs.ToolTip(this._text, , , this.WHICH)
    }

    ; Removes the tooltip and its timers of this process (v1 runActionTooltip_RemoveTooltip).
    static _Remove() {
        this._StopTimers()
        Dialogs.ToolTip("", , , this.WHICH)
    }

    static _StopTimers() {
        if (IsObject(this._removeTimer)) {
            SetTimer(this._removeTimer, 0)
            this._removeTimer := ""
        }
        if (IsObject(this._followTimer)) {
            SetTimer(this._followTimer, 0)
            this._followTimer := ""
        }
    }
}
