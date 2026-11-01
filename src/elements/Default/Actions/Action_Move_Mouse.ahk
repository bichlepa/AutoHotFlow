#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\..\..\core\ElementError.ahk
#Include ..\lib\MouseOps.ahk
#Include ..\lib\TextOps.ahk

; Action Move mouse of the package Default (WI-0126): moves the mouse to the coordinates (absolute, or relative to the
; current position). Specification: the help text of v1 (help/en/Actions/Move_mouse.md). Class ID, parameter IDs, defaults
; and language keys are those of v1 (Source_Elements/Default/Actions/Move_Mouse.ahk).
;
; Worker element: the move goes through SystemOps.MouseMove (E0103). The speed is the AutoHotkey speed (0 fastest, 100
; slowest), which AutoHotkey applies in the Event mode only (the help text says so). The coordinates are rounded to whole
; numbers (MIGRATION M-0154, as Action_Beep rounds its numbers).
class Action_Move_Mouse extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "Keyboard.png"

    static Name() => Lang("Move mouse")
    static Category() => Lang("User simulation")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Mouse position")},
        {type: "Radio", id: "CoordMode", default: "Screen", result: "enum"
            , choices: [Lang("Relative to screen"), Lang("Relative to active window position")
                , Lang("Relative to active window client position"), Lang("Relative to current mouse position")]
            , enum: ["Screen", "Window", "Client", "Relative"]},
        {type: "Label", label: Lang("Coordinates") Lang("(x,y)"), size: "small"},
        {type: "Edit", id: ["Xpos", "Ypos"], default: [10, 20], content: "Expression", WarnIfEmpty: true},
        {type: "Button", id: "MouseTracker", assistant: "mouse", label: Lang("Get coordinates")
            , map: {xpos: "Xpos", ypos: "Ypos", CoordMode: "CoordMode"}},
        {type: "Label", label: Lang("Method")},
        {type: "Radio", id: "SendMode", default: "Input", result: "enum"
            , choices: [Lang("Input mode"), Lang("Event mode"), Lang("Play mode")], enum: ["Input", "Event", "Play"]},
        {type: "Label", label: Lang("Speed")},
        {type: "Slider", id: "speed", default: 2},
        {type: "Label", label: Lang("Delay in ms")},
        {type: "Edit", id: "delay", default: 10, content: "Expression", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("Move mouse")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        if (!IsNumber(p.Xpos))
            throw ElementError(Lang("%1% is not a number.", Lang("X position")))
        if (!IsNumber(p.Ypos))
            throw ElementError(Lang("%1% is not a number.", Lang("Y position")))
        if (!IsNumber(p.speed))
            throw ElementError(Lang("%1% is not a number.", Lang("Speed")))
        if (!IsNumber(p.delay))
            throw ElementError(Lang("%1% is not a number.", Lang("Delay")))
        MouseOps.SetSendMode(p.SendMode, Integer(Round(p.delay)))
        MouseOps.SetCoordMode(p.CoordMode)
        args := [Integer(Round(p.Xpos)), Integer(Round(p.Ypos)), Integer(Round(p.speed))]
        if (p.CoordMode = "Relative")
            args.Push("R")
        SystemOps.MouseMove(args*)
        ctx.Finish("normal")
    }
}
