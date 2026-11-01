#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\..\..\core\ElementError.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\MouseOps.ahk
#Include ..\lib\TextOps.ahk

; Action Get mouse position of the package Default (WI-0126): stores the position of the mouse in two variables, and
; optionally the handle of the window and of the control under the mouse. Specification: the help text of v1
; (help/en/Actions/Get_mouse_position.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Get_mouse_position.ahk).
;
; Worker element: the position is read through SystemOps.MouseGetPos (E0103), so a test gets a fixed position from the
; provider. The control is returned as its handle (MouseGetPos flag 2), as v1 did; the coordinate mode is set first.
; The element reads the keys and the mouse of the user, so it counts as acting on the system (the import warning).
class Action_Get_Mouse_Position extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "Keyboard.png"

    static Name() => Lang("Get Mouse Position")
    static Category() => Lang("User interaction")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variables")},
        {type: "Label", label: Lang("Coordinates"), size: "small"},
        {type: "Edit", id: ["varnameX", "varnameY"], default: ["posX", "posY"], content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Mouse position"), size: "small"},
        {type: "Radio", id: "CoordMode", default: "Screen", result: "enum"
            , choices: [Lang("Relative to screen"), Lang("Relative to active window position")
                , Lang("Relative to active window client position")], enum: ["Screen", "Window", "Client"]},
        {type: "Label", label: Lang("Additional information")},
        {type: "Checkbox", id: "WhetherGetWindowID", default: 0, label: Lang("Get window ID beneath the mouse")},
        {type: "Edit", id: "varnameWindowID", default: "windowID", content: "VariableName", WarnIfEmpty: true},
        {type: "Checkbox", id: "WhetherGetControlID", default: 0, label: Lang("Get control ID beneath the mouse")},
        {type: "Edit", id: "varnameControlID", default: "controlID", content: "VariableName", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("Get Mouse Position")

    static CheckSettings(form, params, staticValues) {
        form.Enable("varnameWindowID", DialogOps.Truthy(TextOps.Par(params, "WhetherGetWindowID")))
        form.Enable("varnameControlID", DialogOps.Truthy(TextOps.Par(params, "WhetherGetControlID")))
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, ["varnameWindowID", "varnameControlID"])
        wantWindow := DialogOps.Truthy(p.WhetherGetWindowID)
        wantControl := DialogOps.Truthy(p.WhetherGetControlID)
        if (wantWindow)
            p := ctx.EvalMoreParams(p, params, ["varnameWindowID"])
        if (wantControl)
            p := ctx.EvalMoreParams(p, params, ["varnameControlID"])
        MouseOps.SetCoordMode(p.CoordMode)
        pos := SystemOps.MouseGetPos(wantControl ? 2 : 0)
        ctx.SetVar(p.varnameX, pos[1])
        ctx.SetVar(p.varnameY, pos[2])
        if (wantWindow)
            ctx.SetVar(p.varnameWindowID, pos[3])
        if (wantControl)
            ctx.SetVar(p.varnameControlID, pos[4])
        ctx.Finish("normal")
    }
}
