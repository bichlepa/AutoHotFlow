#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\..\..\core\ElementError.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\ScreenOps.ahk
#Include ..\lib\TextOps.ahk

; Action Get pixel color of the package Default (WI-0127): stores the colour of the pixel at a position as "0xRRGGBB", and
; optionally its red, green and blue values. Specification: the help text of v1 (help/en/Actions/Get_pixel_color.md).
; Class ID, parameter IDs and language keys are those of v1 (Source_Elements/Default/Actions/Get_pixel_color.ahk).
;
; Worker element: it reads the screen, which the windows of the user share, and the coordinates are device pixels (see
; ScreenOps). The method names are the v1 enum values (Default, Alt, Slow). The default names of the green and blue
; output (v1: ColorBlue and ColorGreen, swapped) are corrected (MIGRATION M-0172).
class Action_Get_Pixel_Color extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Get Pixel Color")
    static Category() => Lang("image")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variables")},
        {type: "Checkbox", id: "OutputRGB", default: 1, label: Lang("Write RGB value in output variable")},
        {type: "Checkbox", id: "OutputSeparate", default: 0, label: Lang("Write each color in separate variable")},
        {type: "Label", label: Lang("RGB value"), size: "small"},
        {type: "Edit", id: "varnameRGB", default: "ColorRBG", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Red, green, blue"), size: "small"},
        {type: "Edit", id: ["varnameR", "varnameG", "varnameB"], default: ["ColorRed", "ColorGreen", "ColorBlue"]
            , content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Position")},
        {type: "Radio", id: "CoordMode", default: "Screen", result: "enum"
            , choices: [Lang("Relative to screen"), Lang("Relative to active window position")
                , Lang("Relative to active window client position")], enum: ["Screen", "Window", "Client"]},
        {type: "Label", label: "x, y", size: "small"},
        {type: "Edit", id: ["Xpos", "Ypos"], default: [10, 20], content: "Expression", WarnIfEmpty: true},
        {type: "Button", id: "MouseTracker", assistant: "mouse", label: Lang("Get coordinates")
            , map: {xpos: "Xpos", ypos: "Ypos", CoordMode: "CoordMode"}},
        {type: "Label", label: Lang("Method")},
        {type: "Radio", id: "Method", default: "Default", result: "enum"
            , choices: [Lang("Default method"), Lang("Alternative method"), Lang("Slow method")]
            , enum: ["Default", "Alt", "Slow"]}
    ]

    static GenerateName(ctx, params) => Lang("Get Pixel Color")

    static CheckSettings(form, params, staticValues) {
        form.Enable("varnameRGB", DialogOps.Truthy(TextOps.Par(params, "OutputRGB")))
        separate := DialogOps.Truthy(TextOps.Par(params, "OutputSeparate"))
        form.Enable("varnameR", separate)
        form.Enable("varnameG", separate)
        form.Enable("varnameB", separate)
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, ["varnameRGB", "varnameR", "varnameG", "varnameB"])
        if (DialogOps.Truthy(p.OutputRGB))
            p := ctx.EvalMoreParams(p, params, ["varnameRGB"])
        if (DialogOps.Truthy(p.OutputSeparate))
            p := ctx.EvalMoreParams(p, params, ["varnameR", "varnameG", "varnameB"])
        if (!IsNumber(p.Xpos))
            throw ElementError(Lang("%1% is not a number.", Lang("X position")))
        if (!IsNumber(p.Ypos))
            throw ElementError(Lang("%1% is not a number.", Lang("Y position")))
        mode := (p.Method = "Alt") ? "Alt" : (p.Method = "Slow") ? "Slow" : ""
        prev := ScreenOps.EnterPhysical()
        try {
            ScreenOps.SetPixelMode(p.CoordMode)
            try {
                color := PixelGetColor(p.Xpos, p.Ypos, mode)
            } catch {
                throw ElementError(Lang("Could not get pixel color from coordinates x%1% y%2%.", p.Xpos, p.Ypos))
            }
        } finally {
            ScreenOps.LeavePhysical(prev)
        }
        if (DialogOps.Truthy(p.OutputRGB))
            ctx.SetVar(p.varnameRGB, color)
        if (DialogOps.Truthy(p.OutputSeparate)) {
            ctx.SetVar(p.varnameR, Integer("0x" SubStr(color, 3, 2)))
            ctx.SetVar(p.varnameG, Integer("0x" SubStr(color, 5, 2)))
            ctx.SetVar(p.varnameB, Integer("0x" SubStr(color, 7, 2)))
        }
        ctx.Finish("normal")
    }
}
