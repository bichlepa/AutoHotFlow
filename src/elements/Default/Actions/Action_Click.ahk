#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\..\..\core\ElementError.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\TextOps.ahk
#Include ..\lib\MouseOps.ahk

; Action Click of the package Default (WI-0126): clicks a mouse button, holds it down, releases it or turns the wheel, at the
; current position or at given coordinates. Specification: the help text of v1 (help/en/Actions/Click.md). Class ID,
; parameter IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Click.ahk).
;
; Worker element: the click goes through SystemOps.Click (E0103), the seam records it in the tests. The call is one
; AutoHotkey Click with an options string ("x y Left 2 D R"), so the coordinates, the button and the count are one call.
; The coordinate mode and the send mode are set for this worker thread before the call (CoordMode, SendMode); the speed
; of the movement is the default mouse speed (AutoHotkey Click has no speed parameter), see MIGRATION M-0153.
;
; Coordinates and the speed are rounded to whole numbers; a value that is not a number is an exception with the v1 text.
class Action_Click extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "Keyboard.png"

    static Name() => Lang("Click")
    static Category() => Lang("User simulation")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Which button")},
        {type: "DropDown", id: "Button", default: "Left", result: "enum"
            , choices: [Lang("Left button"), Lang("Right button"), Lang("Middle Button"), Lang("Wheel up"), Lang("Wheel down")
                , Lang("Wheel left"), Lang("Wheel right"), Lang("4th mouse button (back)"), Lang("5th mouse button (forward)")]
            , enum: ["Left", "Right", "Middle", "WheelUp", "WheelDown", "WheelLeft", "WheelRight", "X1", "X2"]},
        {type: "Label", label: Lang("Click count")},
        {type: "Edit", id: "ClickCount", default: 1, content: "Expression", WarnIfEmpty: true},
        {type: "Label", label: Lang("Event")},
        {type: "Radio", id: "DownUp", default: "Click", result: "enum"
            , choices: [Lang("Click (Down and up)"), Lang("Hold down"), Lang("Release only")], enum: ["Click", "D", "U"]},
        {type: "Label", label: Lang("Mouse position")},
        {type: "Checkbox", id: "changePosition", default: 0, label: Lang("Move mouse before clicking")},
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
        {type: "Label", label: Lang("Mouse movement speed")},
        {type: "Slider", id: "speed", default: 2},
        {type: "Label", label: Lang("Delay in ms")},
        {type: "Edit", id: "delay", default: 10, content: "Expression", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        text := Lang("Click") " - " this._ButtonText(TextOps.Par(params, "Button"))
        downUp := TextOps.Par(params, "DownUp")
        if (downUp = "D")
            text .= " - " Lang("Hold down")
        else if (downUp = "U")
            text .= " - " Lang("Release")
        count := TextOps.Par(params, "ClickCount")
        if (count != "" && count != 1)
            text .= " - " Lang("%1% times", count)
        if (DialogOps.Truthy(TextOps.Par(params, "changePosition")))
            text .= " - " Lang("Move mouse")
        return text
    }

    ; The settings of the position follow the checkbox (v1 CheckSettings).
    static CheckSettings(form, params, staticValues) {
        moves := DialogOps.Truthy(TextOps.Par(params, "changePosition"))
        for id in ["Xpos", "Ypos", "CoordMode", "speed"]
            form.Enable(id, moves)
    }

    static Run(ctx, params) {
        ; the position and speed are evaluated only when the element moves the mouse (v1)
        p := ctx.EvalParams(params, ["Xpos", "Ypos", "speed", "CoordMode"])
        moves := DialogOps.Truthy(p.changePosition)
        if (moves)
            p := ctx.EvalMoreParams(p, params, ["Xpos", "Ypos", "CoordMode", "speed"])
        if (!IsNumber(p.ClickCount))
            throw ElementError(Lang("%1% is not a number.", Lang("Click count")))
        if (!IsNumber(p.delay))
            throw ElementError(Lang("%1% is not a number.", Lang("Delay")))
        MouseOps.SetSendMode(p.SendMode, Integer(Round(p.delay)))

        options := ""
        if (moves) {
            if (!IsNumber(p.Xpos))
                throw ElementError(Lang("%1% is not a number.", Lang("X position")))
            if (!IsNumber(p.Ypos))
                throw ElementError(Lang("%1% is not a number.", Lang("Y position")))
            if (!IsNumber(p.speed))
                throw ElementError(Lang("%1% is not a number.", Lang("Speed")))
            MouseOps.SetCoordMode(p.CoordMode)
            SetDefaultMouseSpeed(Integer(Round(p.speed)))
            options := Integer(Round(p.Xpos)) " " Integer(Round(p.Ypos)) " "
        }
        options .= p.Button " " Integer(Round(p.ClickCount))
        if (p.DownUp = "D")
            options .= " D"
        else if (p.DownUp = "U")
            options .= " U"
        if (moves && p.CoordMode = "Relative")
            options .= " R"
        SystemOps.Click(options)
        ctx.Finish("normal")
    }

    static _ButtonText(button) {
        switch (button) {
            case "Left": return Lang("Left button")
            case "Right": return Lang("Right button")
            case "Middle": return Lang("Middle Button")
            case "WheelUp": return Lang("Wheel up")
            case "WheelDown": return Lang("Wheel down")
            case "WheelLeft": return Lang("Wheel left")
            case "WheelRight": return Lang("Wheel right")
            case "X1": return Lang("4th mouse button (back)")
            case "X2": return Lang("5th mouse button (forward)")
        }
        return button
    }
}
