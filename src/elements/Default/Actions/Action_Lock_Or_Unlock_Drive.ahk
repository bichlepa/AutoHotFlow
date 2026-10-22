#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DriveOps.ahk
#Include ..\lib\TextOps.ahk

; Action Lock or unlock drive of the package Default (WI-0122): prevents the eject of a drive (DriveLock) or allows it again
; (DriveUnlock). Specification: the help text of v1 (help/en/Actions/Lock_Or_Unlock_Drive.md). Class ID, parameter IDs and
; language keys are those of v1 (Source_Elements/Default/Actions/Lock_Or_Unlock_Drive.ahk).
;
; Mode worker. The lock and the unlock go through the seam SystemOps (E0103): a test records the call and locks no drive.
; The default of the action is the enum value "Lock" (v1 wrote the position 1; M-0099). A failing call ends with the
; exception "Could not lock drive" or "Could not unlock drive" (v1 text; v1 named an unset variable there, corrected).
class Action_Lock_Or_Unlock_Drive extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Lock Or Unlock Drive")
    static Category() => Lang("Drive")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Action")},
        {type: "Radio", id: "WhatDo", default: "Lock", choices: [Lang("Lock drive"), Lang("Unlock drive")], result: "enum", enum: ["Lock", "Unlock"]},
        {type: "Label", label: Lang("Drive letter")},
        {type: "ComboBox", id: "DriveLetter", content: "string", default: DriveOps.Default(ctx), choices: DriveOps.Choices(ctx), result: "string"}
    ]

    static GenerateName(ctx, params) {
        if (TextOps.Par(params, "WhatDo") = "Unlock")
            what := Lang("Unlock")
        else
            what := Lang("Lock #verb")
        return Lang("Lock Or Unlock Drive") " - " what " - " TextOps.Par(params, "DriveLetter")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        drive := DriveOps.Letter(p.DriveLetter)
        if (p.WhatDo = "Unlock") {
            try SystemOps.DriveUnlock(drive)
            catch
                throw ElementError(Lang("Could not unlock drive '%1%'", drive))
        } else {
            try SystemOps.DriveLock(drive)
            catch
                throw ElementError(Lang("Could not lock drive '%1%'", drive))
        }
        ctx.Finish("normal")
    }
}
