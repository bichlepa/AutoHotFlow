#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Empty recycle bin of the package Default (WI-0121): empties the recycle bin of all drives or of one drive.
; Specification: the help text of v1 (help/en/Actions/Empty_Recycle_bin.md). Class ID, parameter IDs, defaults and language
; keys are those of v1 (Source_Elements/Default/Actions/Empty_Recycle_bin.ahk).
;
; The call goes through the seam SystemOps (E0103): a test never empties a real recycle bin. Worker element (a drive, ARCHITECTURE
; 2.3). The drive list of the choices is read when the parameters are described (DriveGetList, as v1 did in the editor).
class Action_Empty_Recycle_Bin extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Empty Recycle Bin")
    static Category() => Lang("Drive")

    static Parameters(ctx) {
        drives := this._Drives()
        defaultDrive := (drives.Length > 0) ? drives[1] : ""
        return [
            {type: "Label", label: Lang("Which drive")},
            {type: "Radio", id: "AllDrives", default: "All", result: "enum", choices: [Lang("All drives"), Lang("Specified drive")], enum: ["All", "Specified"]},
            {type: "ComboBox", id: "DriveLetter", content: "String", WarnIfEmpty: true, result: "string", default: defaultDrive, choices: drives}
        ]
    }

    static GenerateName(ctx, params) {
        driveText := (TextOps.Par(params, "AllDrives") = "Specified") ? TextOps.Par(params, "DriveLetter") : Lang("All drives")
        return Lang("Empty Recycle Bin") " - " driveText
    }

    static CheckSettings(form, params, staticValues) {
        form.Disable("DriveLetter", TextOps.Par(params, "AllDrives") != "Specified")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "DriveLetter")
        if (p.AllDrives = "Specified") {
            p := ctx.EvalMoreParams(p, params, "DriveLetter")      ; WarnIfEmpty: an empty drive ends the evaluation
            try SystemOps.FileRecycleEmpty(p.DriveLetter)
            catch as err
                throw FileOps.Fail(Lang("Recycle bin could not be emptied."), FileOps.Code(err))
        } else {
            try SystemOps.FileRecycleEmpty()
            catch as err
                throw FileOps.Fail(Lang("Recycle bin could not be emptied."), FileOps.Code(err))
        }
        ctx.Finish("normal")
    }

    ; The drive letters of the system as "C:", "D:" (the first one is the default choice). Empty when the list is not
    ; available.
    static _Drives() {
        list := []
        try {
            for letter in StrSplit(DriveGetList()) {
                list.Push(letter ":")
            }
        }
        return list
    }
}
