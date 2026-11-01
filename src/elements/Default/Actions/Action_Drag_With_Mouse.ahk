#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\..\..\core\ElementError.ahk
#Include ..\lib\MouseOps.ahk
#Include ..\lib\TextOps.ahk

; Action Drag with mouse of the package Default (WI-0126): moves the mouse to the start coordinates, presses the button,
; drags to the end coordinates and releases it. Specification: the help text of v1 (help/en/Actions/Drag_with_mouse.md).
; Class ID, parameter IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Drag_with_mouse.ahk).
;
; Worker element: the drag goes through SystemOps.MouseClickDrag (E0103). The coordinates and the speed are rounded to
; whole numbers (MIGRATION M-0154). The drag takes the mouse delay of the send method like Action_Move_Mouse.
class Action_Drag_With_Mouse extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "Keyboard.png"

    static Name() => Lang("Drag With Mouse")
    static Category() => Lang("User simulation")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Which button")},
        {type: "DropDown", id: "Button", default: "Left", result: "enum"
            , choices: [Lang("Left button"), Lang("Right button"), Lang("Middle Button"), Lang("4th mouse button (back)")
                , Lang("5th mouse button (forward)")]
            , enum: ["Left", "Right", "Middle", "X1", "X2"]},
        {type: "Label", label: Lang("Mouse position")},
        {type: "Radio", id: "CoordMode", default: "Screen", result: "enum"
            , choices: [Lang("Relative to screen"), Lang("Relative to active window position")
                , Lang("Relative to active window client position"), Lang("Relative to current mouse position")]
            , enum: ["Screen", "Window", "Client", "Relative"]},
        {type: "Label", label: Lang("Start coordinates") " " Lang("(x,y)"), size: "small"},
        {type: "Edit", id: ["XposFrom", "YposFrom"], default: [10, 20], content: "Expression", WarnIfEmpty: true},
        {type: "Button", id: "MouseTrackerFrom", assistant: "mouse", label: Lang("Get coordinates")
            , map: {xpos: "XposFrom", ypos: "YposFrom", CoordMode: "CoordMode"}},
        {type: "Label", label: Lang("End coordinates") " " Lang("(x,y)"), size: "small"},
        {type: "Edit", id: ["Xpos", "Ypos"], default: [100, 200], content: "Expression", WarnIfEmpty: true},
        {type: "Button", id: "MouseTrackerTo", assistant: "mouse", label: Lang("Get coordinates")
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
        button := this._ButtonText(TextOps.Par(params, "Button"))
        from := TextOps.Par(params, "XposFrom") "/" TextOps.Par(params, "YposFrom")
        to := TextOps.Par(params, "Xpos") "/" TextOps.Par(params, "Ypos")
        return Lang("Drag With Mouse") " - " button " - " Lang("From '%1%' to '%2%'", from, to)
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        checks := [["Xpos", "Second X position"], ["Ypos", "Second Y position"], ["XposFrom", "First X position"]
            , ["YposFrom", "First Y position"], ["speed", "Speed"], ["delay", "Delay"]]
        for pair in checks {
            if (!IsNumber(p.%pair[1]%))
                throw ElementError(Lang("%1% is not a number.", Lang(pair[2])))
        }
        MouseOps.SetSendMode(p.SendMode, Integer(Round(p.delay)))
        MouseOps.SetCoordMode(p.CoordMode)
        args := [p.Button, Integer(Round(p.XposFrom)), Integer(Round(p.YposFrom)), Integer(Round(p.Xpos))
            , Integer(Round(p.Ypos)), Integer(Round(p.speed))]
        if (p.CoordMode = "Relative")
            args.Push("R")
        SystemOps.MouseClickDrag(args*)
        ctx.Finish("normal")
    }

    static _ButtonText(button) {
        switch (button) {
            case "Left": return Lang("Left button")
            case "Right": return Lang("Right button")
            case "Middle": return Lang("Middle Button")
            case "X1": return Lang("4th mouse button (back)")
            case "X2": return Lang("5th mouse button (forward)")
        }
        return button
    }
}
