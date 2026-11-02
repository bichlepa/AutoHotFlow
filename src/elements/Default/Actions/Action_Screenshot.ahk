#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\..\..\core\ElementError.ahk
#Include ..\..\..\gdip\Gdip.ahk
#Include ..\..\..\gdip\GdipCanvas.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\ScreenOps.ahk
#Include ..\lib\TextOps.ahk
#Include ..\lib\WindowIdent.ahk

; Action Screenshot of the package Default (WI-0127): saves the whole screen, all screens, one monitor, a region or a
; window to an image file. The format is the one of the file extension (BMP, JPEG, GIF, TIFF or PNG, as v1). Specification:
; the help text of v1 (help/en/Actions/Screenshot.md). Class ID, parameter IDs and language keys are those of v1
; (Source_Elements/Default/Actions/Screenshot.ahk).
;
; Worker element: it writes a file and reads the screen (GDI+ through the shared wrapper src/gdip/, GdipCanvas.CaptureScreen
; and CaptureWindow). The region of v1 keeps its size as the difference of its corners (the lower right corner is not part
; of it, M-0170 does not apply here). The method "from screen coordinates" is the same capture as "from screen" in v2
; (v1 passed the window size in the same way; MIGRATION M-0174). The window ID is set as A_WindowID (thread variable).
class Action_Screenshot extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Screenshot")
    static Category() => Lang("image")

    static Parameters(ctx) {
        list := [
            {type: "Label", label: Lang("Output")},
            {type: "File", id: "file", label: Lang("Select a file"), filter: Lang("Image") " (*.bmp; *.dib; *.rle; *.jpg; *.jpeg; *.jpe; *.jfif; *.gif; *.tif; *.tiff; *.png)"},
            {type: "Label", label: Lang("Screen region")},
            {type: "Radio", id: "WhichRegion", default: "Screen", result: "enum"
                , choices: [Lang("Whole screen"), Lang("Defined region"), Lang("Specified window")]
                , enum: ["Screen", "Region", "Window"]},
            {type: "Label", label: Lang("Which screen")},
            {type: "Checkbox", id: "AllScreens", default: 1, label: Lang("All screens")},
            {type: "Edit", id: "ScreenNumber", default: 1, content: "PositiveInteger", WarnIfEmpty: true},
            {type: "Label", label: Lang("Coordinates")},
            {type: "Label", label: Lang("Upper left corner"), size: "small"},
            {type: "Edit", id: ["x1", "y1"], default: [10, 20], content: "Number", WarnIfEmpty: true},
            {type: "Label", label: Lang("Lower right corner"), size: "small"},
            {type: "Edit", id: ["x2", "y2"], default: [600, 700], content: "Number", WarnIfEmpty: true},
            {type: "Button", id: "GetCoordinates", assistant: "mouse", label: Lang("Get coordinates")
                , map: {xpos: "x1", ypos: "y1"}}
        ]
        WindowIdent.AddIdentificationParameters(list)
        list.Push({type: "Label", label: Lang("Method")})
        list.Push({type: "Radio", id: "Method", default: "Gdip_FromScreen", result: "enum"
            , choices: [Lang("Method %1%", 1), Lang("Method %1%", 2), Lang("Method %1%", 3) " - "
                Lang("Works only if window visible")], enum: ["Gdip_FromScreen", "Gdip_FromHWND", "Gdip_FromScreenCoordinates"]})
        return list
    }

    static GenerateName(ctx, params) => Lang("Screenshot")

    static CheckSettings(form, params, staticValues) {
        region := TextOps.Par(params, "WhichRegion")
        screen := (region = "Screen")
        window := (region = "Window")
        form.Enable("AllScreens", screen)
        form.Enable("ScreenNumber", screen && !DialogOps.Truthy(TextOps.Par(params, "AllScreens")))
        coords := (region = "Region")
        for id in ["x1", "y1", "x2", "y2", "GetCoordinates"]
            form.Enable(id, coords)
        for id in ScreenOps.WindowIds
            form.Enable(id, window)
        form.Enable("GetWindowInformation", window)
        form.Enable("Method", window)
    }

    static Run(ctx, params) {
        skip := ["x1", "y1", "x2", "y2", "ScreenNumber", "Method"]
        for id in ScreenOps.WindowIds
            skip.Push(id)
        p := ctx.EvalParams(params, skip)
        if (!Gdip.MimeOfFile(p.file))
            throw ElementError(Lang("Can't save screenshot to file '%1%'", p.file) ": " Lang("Wrong extension"))
        canvas := 0
        prev := ScreenOps.EnterPhysical()
        try {
            switch p.WhichRegion {
                case "Screen":
                    if (DialogOps.Truthy(p.AllScreens)) {
                        x := SysGet(76), y := SysGet(77), w := SysGet(78), h := SysGet(79)
                        canvas := this._Capture(x, y, w, h, Lang("Can't make screenshot from all screens"))
                    } else {
                        p := ctx.EvalMoreParams(p, params, ["ScreenNumber"])
                        number := p.ScreenNumber
                        if (number < 1 || number > SystemOps.MonitorCount())
                            throw ElementError(Lang("Can't make screenshot from screen %1%", number))
                        L := 0, T := 0, R := 0, B := 0
                        MonitorGet(number, &L, &T, &R, &B)
                        canvas := this._Capture(L, T, R - L, B - T
                            , Lang("Can't make screenshot from screen %1%", number))
                    }
                case "Region":
                    p := ctx.EvalMoreParams(p, params, ["x1", "y1", "x2", "y2"])
                    w := p.x2 - p.x1, h := p.y2 - p.y1
                    if (w < 1 || h < 1)
                        throw ElementError(Lang("Coordinates are invalid") ": x" p.x1 "-" p.y1 " y" p.x2 "-" p.y2)
                    canvas := this._Capture(p.x1, p.y1, w, h, Lang("Coordinates are invalid"))
                case "Window":
                    p := ctx.EvalMoreParams(p, params, ScreenOps.WindowIds)
                    p := ctx.EvalMoreParams(p, params, ["Method"])
                    spec := WindowIdent.Spec(p)
                    win := WindowIdent.Find(spec)
                    if (win = 0)
                        throw ElementError(Lang("Error! Seeked window does not exist"))
                    ctx.SetVar("A_WindowID", win, "thread")
                    WinGetPos(&x, &y, &w, &h, "ahk_id " win)
                    if (p.Method = "Gdip_FromHWND") {
                        canvas := GdipCanvas(w, h)
                        try {
                            canvas.CaptureWindow(win)
                        } catch as e {
                            throw ElementError(Lang("Can't make screenshot from window") ": " e.Message)
                        }
                    } else {
                        canvas := this._Capture(x, y, w, h, Lang("Can't make screenshot from window"))
                    }
                default:
                    throw ElementError(Lang("Can't make screenshot from window"))
            }
            try {
                canvas.SaveFile(p.file)
            } catch as e {
                throw ElementError(Lang("Can't save screenshot to file '%1%'", p.file) ": "
                    Lang("Could not save file to disk.") " " e.Message)
            }
        } finally {
            if (IsObject(canvas))
                canvas.Destroy()
            ScreenOps.LeavePhysical(prev)
        }
        ctx.Finish("normal")
    }

    ; A canvas of the size w x h that holds the screen from x, y (v1 Gdip_BitmapFromScreen). Throws ElementError with the
    ; text when the screen cannot be read or the size is not valid.
    static _Capture(x, y, w, h, failText) {
        if (w < 1 || h < 1)
            throw ElementError(failText)
        canvas := GdipCanvas(w, h)
        try {
            canvas.CaptureScreen(x, y)
        } catch as e {
            canvas.Destroy()
            throw ElementError(failText ": " e.Message)
        }
        return canvas
    }
}
