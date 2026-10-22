#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DriveOps.ahk
#Include ..\lib\TextOps.ahk

; Action Change drive label of the package Default (WI-0122): sets the volume label of a drive. Specification: the help text of
; v1 (help/en/Actions/Change_Drive_Label.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Change_Drive_Label.ahk).
;
; Mode worker. The label is changed through the seam SystemOps (E0103): a test records the call and changes no drive.
; An empty new label removes the label (the function without a label, as AutoHotkey). Usually administrator rights are
; needed for a drive that is not a removable one. The v1 text of the error had a doubled apostrophe, which is corrected.
class Action_Change_Drive_Label extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Change Drive Label")
    static Category() => Lang("Drive")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Drive letter")},
        {type: "ComboBox", id: "DriveLetter", content: "String", WarnIfEmpty: true, result: "string", default: DriveOps.Default(ctx), choices: DriveOps.Choices(ctx)},
        {type: "Label", label: Lang("New label")},
        {type: "Edit", id: "NewLabel", content: "String"}
    ]

    static GenerateName(ctx, params) => Lang("Change Drive Label") " - " TextOps.Par(params, "DriveLetter") " - " TextOps.Par(params, "NewLabel")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        drive := DriveOps.Letter(p.DriveLetter)
        try {
            if (p.NewLabel = "")
                SystemOps.DriveSetLabel(drive)
            else
                SystemOps.DriveSetLabel(drive, p.NewLabel)
        } catch {
            throw ElementError(Lang("Label '%1%' could not be set to drive '%2%'", p.NewLabel, drive))
        }
        ctx.Finish("normal")
    }
}
