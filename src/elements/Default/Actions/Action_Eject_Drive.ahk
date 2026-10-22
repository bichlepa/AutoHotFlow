#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DriveOps.ahk
#Include ..\lib\TextOps.ahk

; Action Eject drive of the package Default (WI-0122): ejects a removable drive or an optical drive, or retracts the tray of an
; optical drive. Specification: the help text of v1 (help/en/Actions/Eject_Drive.md). Class ID, parameter IDs, defaults,
; choices and language keys are those of v1 (Source_Elements/Default/Actions/Eject_Drive.ahk).
;
; Mode worker. The eject and the retraction go through the seam SystemOps (E0103): DriveEject and DriveRetract of AutoHotkey,
; which use the control code IOCTL_STORAGE_EJECT_MEDIA and IOCTL_STORAGE_LOAD_MEDIA (the AutoHotkey documentation).
; The three v1 methods all end in that call (MIGRATION M-0145): the v1 method 1 (a library that ejects USB mass storage
; devices by their device instance) is not ported, and the choice of the method is kept in the flow but has no effect.
; A failing call ends with the exception "Drive ... could not be ejected" (or "retracted") and the error of AutoHotkey.
class Action_Eject_Drive extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Eject Drive")
    static Category() => Lang("Drive")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Drive letter")},
        {type: "ComboBox", id: "DriveLetter", content: "String", WarnIfEmpty: true, result: "string", default: DriveOps.Default(ctx), choices: DriveOps.Choices(ctx)},
        {type: "Label", label: Lang("Action")},
        {type: "Radio", id: "WhatDo", default: "ejectDrive", result: "enum", choices: [Lang("Eject drive"), Lang("Retract the tray of a optical disc drive")], enum: ["ejectDrive", "RetractTray"]},
        {type: "Label", label: Lang("Method")},
        {type: "Radio", id: "Method", default: "LibraryEjectByScan", result: "enum", choices: [Lang("Method %1%", 1), Lang("Method %1%", 2) " (" Lang("Force #verb") ")", Lang("Method %1%", 3) " (" Lang("Only optical disc drive") ")"], enum: ["LibraryEjectByScan", "DeviceIoControl", "builtIn"]}
    ]

    static GenerateName(ctx, params) {
        if (TextOps.Par(params, "WhatDo") = "RetractTray")
            what := Lang("Retract the tray of a optical disc drive")
        else
            what := Lang("Eject drive")
        return Lang("Eject Drive") " - " what " - " TextOps.Par(params, "DriveLetter")
    }

    static CheckSettings(form, params, staticValues) {
        form.Enable("Method", params.WhatDo = "ejectDrive")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        drive := DriveOps.Letter(p.DriveLetter)
        if (p.WhatDo = "RetractTray") {
            try SystemOps.DriveRetract(drive)
            catch as err
                throw ElementError(Lang("Drive %1% could not be retracted", drive) " - " Lang("Error description") ": " err.Message)
        } else {
            try SystemOps.DriveEject(drive)
            catch as err
                throw ElementError(Lang("Drive %1% could not be ejected", drive) " - " Lang("Error description") ": " err.Message)
        }
        ctx.Finish("normal")
    }
}
