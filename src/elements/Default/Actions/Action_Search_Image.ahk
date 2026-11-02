#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\..\..\core\ElementError.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\ScreenOps.ahk
#Include ..\lib\TextOps.ahk

; Action Search image of the package Default (WI-0127): searches a region of the screen for an image file and stores the
; position of its upper left corner. Specification: the help text of v1 (help/en/Actions/Search_Image.md). Class ID,
; parameter IDs and language keys are those of v1 (Source_Elements/Default/Actions/Search_Image.ahk).
;
; Worker element: it reads the screen (see ScreenOps). The options of v1 (the icon number, the variation, the transparent
; colour, the scaling) are the options of ImageSearch of AutoHotkey v2, which has them as v1 has (*Icon, *n, *Trans,
; *w and *h). The image file must exist (v1 text); a file that cannot be loaded ends the element with the v1 text
; (ImageSearch throws ValueError for it). The whole-screen region of v1 is corrected as in Search pixel (M-0171).
class Action_Search_Image extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Search Image")
    static Category() => Lang("image")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variables")},
        {type: "Edit", id: ["varnameX", "varnameY"], default: ["ImagePosX", "ImagePosY"], content: "VariableName"
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
        {type: "Label", label: Lang("Image file path")},
        {type: "File", id: "file", label: Lang("Select a file"), filter: Lang("Images and icons")
            " (*.gif; *.jpg; *.bmp; *.ico; *.cur; *.ani; *.png; *.tif; *.exif; *.wmf; *.emf; *.exe; *.dll; *.cpl; *.scr)"},
        {type: "Label", label: Lang("File with multiple icons")},
        {type: "Checkbox", id: "SetIconNumber", default: 0, label: Lang("Set icon number")},
        {type: "Edit", id: "IconNumber", default: 1, content: "PositiveInteger", WarnIfEmpty: true},
        {type: "Label", label: Lang("Variation")},
        {type: "Slider", id: "variation", default: 0, content: "PositiveNumber", AllowExpression: true},
        {type: "Label", label: Lang("Transparent color")},
        {type: "Checkbox", id: "makeTransparent", default: 0, label: Lang("Make a color of image transparent")},
        {type: "Edit", id: "transparent", content: "String", WarnIfEmpty: true},
        {type: "Button", id: "ChooseColor", assistant: "color", label: Lang("Choose color"), map: {color: "transparent"}},
        {type: "Button", id: "GetColor", assistant: "mouse", label: Lang("Get color from screen")
            , map: {color: "transparent"}},
        {type: "Label", label: Lang("Scale image")},
        {type: "Checkbox", id: "ScaleImage", default: 0, label: Lang("Scale image")},
        {type: "Checkbox", id: "PreserveAspectRatio", default: 0, label: Lang("Preserve aspect ratio")},
        {type: "Radio", id: "WhichSizeSet", default: "widthManually", result: "enum"
            , choices: [Lang("Set width manually and set height automatically")
                , Lang("Set height manually and set width automatically")], enum: ["widthManually", "heightManually"]},
        {type: "Label", label: Lang("width, height"), size: "small"},
        {type: "Edit", id: ["ImageWidth", "ImageHeight"], content: "Number", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("Search Image")

    static CheckSettings(form, params, staticValues) {
        whole := DialogOps.Truthy(TextOps.Par(params, "WholeScreen"))
        for id in ["x1", "y1", "x2", "y2", "GetCoordinates"]
            form.Enable(id, !whole)
        form.Enable("AllScreens", whole && TextOps.Par(params, "CoordMode") = "Screen")
        form.Enable("IconNumber", DialogOps.Truthy(TextOps.Par(params, "SetIconNumber")))
        form.Enable("transparent", DialogOps.Truthy(TextOps.Par(params, "makeTransparent")))
        form.Enable("ChooseColor", DialogOps.Truthy(TextOps.Par(params, "makeTransparent")))
        form.Enable("GetColor", DialogOps.Truthy(TextOps.Par(params, "makeTransparent")))
        scaled := DialogOps.Truthy(TextOps.Par(params, "ScaleImage"))
        form.Enable("PreserveAspectRatio", scaled)
        form.Enable("WhichSizeSet", scaled)
        form.Enable("ImageWidth", scaled)
        form.Enable("ImageHeight", scaled)
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, ["x1", "y1", "x2", "y2", "IconNumber", "transparent", "ImageWidth", "ImageHeight"])
        if (!DialogOps.Truthy(p.WholeScreen))
            p := ctx.EvalMoreParams(p, params, ["x1", "y1", "x2", "y2"])
        if (DialogOps.Truthy(p.WholeScreen))
            region := ScreenOps.WholeRegion(p.CoordMode, DialogOps.Truthy(p.AllScreens))
        else
            region := [p.x1, p.y1, p.x2, p.y2]
        if (!FileExist(p.file))
            throw ElementError(Lang("File '%1%' does not exist", p.file))
        options := ""
        if (DialogOps.Truthy(p.SetIconNumber)) {
            p := ctx.EvalMoreParams(p, params, ["IconNumber"])
            options .= "*Icon" p.IconNumber " "
        }
        if (p.variation > 0)
            options .= "*" Integer(p.variation) " "
        if (DialogOps.Truthy(p.makeTransparent)) {
            p := ctx.EvalMoreParams(p, params, ["transparent"])
            options .= "*Trans" p.transparent " "
        }
        if (DialogOps.Truthy(p.ScaleImage)) {
            p := ctx.EvalMoreParams(p, params, ["ImageWidth", "ImageHeight"])
            width := p.ImageWidth, height := p.ImageHeight
            if (DialogOps.Truthy(p.PreserveAspectRatio)) {
                if (p.WhichSizeSet = "widthManually")
                    height := -1
                else
                    width := -1
            }
            options .= "*w" width " *h" height " "
        }
        prev := ScreenOps.EnterPhysical()
        try {
            ScreenOps.SetPixelMode(p.CoordMode)
            try {
                ImageSearch(&foundX, &foundY, region[1], region[2], region[3], region[4], options p.file)
            } catch as e {
                throw ElementError(Lang("File '%1%' could not be read", p.file) ": " e.Message)
            }
        } finally {
            ScreenOps.LeavePhysical(prev)
        }
        if (foundX = "")
            throw ElementError(Lang("Image was not found on screen"))
        ctx.SetVar(p.varnameX, foundX)
        ctx.SetVar(p.varnameY, foundY)
        ctx.Finish("normal")
    }
}
