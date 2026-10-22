#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\WindowIdent.ahk

; Action Move window of the package Default (WI-0125): maximizes, minimizes, restores or moves and resizes a window (the
; event WinMoveEvent). Specification: the help text of v1 (help/en/Actions/Move_Window.md). Class ID, parameter IDs,
; defaults and language keys are those of v1 (Source_Elements/Default/Actions/Move_window.ahk).
;
; Worker element (another window). The coordinates are the ones of AutoHotkey: screen coordinates in the coordinate mode
; of the worker, which is the default one. Like v1, the coordinates and the size are evaluated and checked only for the
; event Move. The stored value is the text of the event; a missing one is the first choice (Maximize).
; DPI: the window moves to the coordinates it is given; how a monitor with another scaling is handled is checked by the
; owner, not by a test (WI-0125).
class Action_Move_Window extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Move Window")
    static Category() => Lang("Window")

    static Parameters(ctx) {
        list := [
            {type: "Label", label: Lang("Event")},
            {type: "Radio", id: "WinMoveEvent", default: 1, result: "enum"
                , choices: [Lang("Maximize"), Lang("Minimize"), Lang("Restore"), Lang("Move")]
                , enum: ["Maximize", "Minimize", "Restore", "Move"]},
            {type: "Label", label: Lang("Coordinates") " (x,y)", size: "small"},
            {type: "Edit", id: ["Xpos", "Ypos"], content: "Number"},
            {type: "Label", label: Lang("Width and height"), size: "small"},
            {type: "Edit", id: ["Width", "Height"], content: "Number"},
            {type: "Button", id: "MouseTracker", assistant: "position", label: Lang("Grab coordinates from existing window")
                , map: {Xpos: "Xpos", Ypos: "Ypos", Width: "Width", Height: "Height"}}
        ]
        WindowIdent.AddIdentificationParameters(list)
        return list
    }

    static GenerateName(ctx, params) => Lang("Move Window") ": " WindowIdent.Name(params)

    ; The coordinate and size fields are enabled for the event Move only (v1 CheckSettings).
    static CheckSettings(form, params, staticValues) {
        event := params.HasProp("WinMoveEvent") ? params.WinMoveEvent : ""
        isMove := (event = "Move")
        for id in ["Xpos", "Ypos", "Width", "Height", "MouseTracker"]
            form.Enable(id, isMove)
    }

    static Run(ctx, params) {
        coords := ["Xpos", "Ypos", "Width", "Height"]
        p := ctx.EvalParams(params, coords)
        if (p.WinMoveEvent = "Move") {
            p := ctx.EvalMoreParams(p, params, coords)
            for name in coords {
                value := p.%name%
                if (!IsNumber(value))
                    throw ElementError(Lang("%1% is not a number.", Lang("Parameter '%1%' ('%2%')", name, value)))
            }
        }
        win := WindowIdent.Find(WindowIdent.Spec(p))
        if (win = 0)
            throw ElementError(Lang("Error! Seeked window does not exist"))
        ctx.SetVar("A_WindowID", win, "thread")
        id := "ahk_id " win
        switch p.WinMoveEvent {
            case "Minimize":
                WinMinimize(id)
            case "Restore":
                WinRestore(id)
            case "Move":
                WinMove(p.Xpos, p.Ypos, p.Width, p.Height, id)
            default:
                WinMaximize(id)
        }
        ctx.Finish("normal")
    }
}
