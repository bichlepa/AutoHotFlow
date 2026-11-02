#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\..\..\core\ElementError.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\ScreenOps.ahk
#Include ..\lib\TextOps.ahk

; Action Search pixel of the package Default (WI-0127): searches a region for the first pixel of a colour, within a
; variation, and stores its position. Specification: the help text of v1 (help/en/Actions/Search_pixel.md). Class ID,
; parameter IDs and language keys are those of v1 (Source_Elements/Default/Actions/Search_pixel.ahk).
;
; Worker element: it reads the screen (see ScreenOps). Differences to v1 (MIGRATION): the "Fast method" checkbox is kept
; for the flows, but PixelSearch of AutoHotkey v2 has no fast mode, so it changes nothing (M-0169); the whole-screen
; region of v1 used the size of the screen as its lower right corner, which is wrong for a virtual screen that does not
; start at 0, 0 and one pixel too far, here the last pixel is included (M-0170).
class Action_Search_pixel extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Search pixel")
    static Category() => Lang("image")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variables")},
        {type: "Edit", id: ["varnameX", "varnameY"], default: ["PixelPosX", "PixelPosY"], content: "VariableName"
            , WarnIfEmpty: true},
        {type: "Label", label: Lang("Screen region")},
        {type: "Radio", id: "CoordMode", default: "Screen", result: "enum"
            , choices: [Lang("Relative to screen"), Lang("Relative to active window position")
                , Lang("Relative to active window client position")], enum: ["Screen", "Window", "Client"]},
        {type: "Checkbox", id: "WholeScreen", default: 0, label: Lang("Whole screen")},
        {type: "Checkbox", id: "AllScreens", default: 0, label: Lang("All screens")},
        {type: "Label", label: Lang("Upper left corner"), size: "small"},
        {type: "Edit", id: ["x1", "y1"], default: [10, 20], content: "Number", WarnIfEmpty: true},
        {type: "Label", label: Lang("Lower right corner"), size: "small"},
        {type: "Edit", id: ["x2", "y2"], default: [600, 700], content: "Number", WarnIfEmpty: true},
        {type: "Button", id: "GetCoordinates", assistant: "mouse", label: Lang("Get coordinates")
            , map: {xpos: "x1", ypos: "y1", CoordMode: "CoordMode"}},
        {type: "Label", label: Lang("Pixel color")},
        {type: "Edit", id: "ColorID", default: "0xAA00FF", content: "String", WarnIfEmpty: true},
        {type: "Button", id: "ChooseColor", assistant: "color", label: Lang("Choose color"), map: {color: "ColorID"}},
        {type: "Button", id: "GetColor", assistant: "mouse", label: Lang("Get color from screen")
            , map: {color: "ColorID"}},
        {type: "Label", label: Lang("Variation")},
        {type: "Slider", id: "variation", default: 0, content: "Number", AllowExpression: true},
        {type: "Label", label: Lang("Method")},
        {type: "Checkbox", id: "FastMode", default: 1, label: Lang("Fast method")}
    ]

    static GenerateName(ctx, params) => Lang("Search pixel")

    static CheckSettings(form, params, staticValues) {
        whole := DialogOps.Truthy(TextOps.Par(params, "WholeScreen"))
        for id in ["x1", "y1", "x2", "y2", "GetCoordinates"]
            form.Enable(id, !whole)
        form.Enable("AllScreens", whole && TextOps.Par(params, "CoordMode") = "Screen")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, ["x1", "y1", "x2", "y2"])
        if (DialogOps.Truthy(p.WholeScreen)) {
            region := ScreenOps.WholeRegion(p.CoordMode, DialogOps.Truthy(p.AllScreens))
        } else {
            p := ctx.EvalMoreParams(p, params, ["x1", "y1", "x2", "y2"])
            region := [p.x1, p.y1, p.x2, p.y2]
        }
        prev := ScreenOps.EnterPhysical()
        try {
            ScreenOps.SetPixelMode(p.CoordMode)
            try {
                PixelSearch(&foundX, &foundY, region[1], region[2], region[3], region[4], p.ColorID
                    , Integer(p.variation))
            } catch {
                throw ElementError(Lang("Something prevented the command from conducting the search"))
            }
        } finally {
            ScreenOps.LeavePhysical(prev)
        }
        if (foundX = "")
            throw ElementError(Lang("Pixel with color '%1%' not found", p.ColorID))
        ctx.SetVar(p.varnameX, foundX)
        ctx.SetVar(p.varnameY, foundY)
        ctx.Finish("normal")
    }
}
