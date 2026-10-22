#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DriveOps.ahk
#Include ..\lib\TextOps.ahk

; Action List drives of the package Default (WI-0122): stores the letters of the drives of the system (or of one drive type)
; in a list variable. Specification: the help text of v1 (help/en/Actions/List_drives.md). Class ID, parameter IDs, defaults,
; choices and language keys are those of v1 (Source_Elements/Default/Actions/List_Drives.ahk).
;
; Mode worker (the drives are read from the operating system). Each drive is one member of the list, its letter without
; colon, as v1 wrote it. Without a drive, the element ends with the exception "No drives found", or with the normal result
; and the same text when the choice "Normal" is set (the variable is then not written, as in v1).
class Action_List_drives extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("List drives")
    static Category() => Lang("Drive")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "DriveList", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Drive type")},
        {type: "Radio", id: "WhetherDriveTypeFilter", default: "all", choices: [Lang("Find all drives"), Lang("Get only a Specified type of drive")], result: "enum", enum: ["all", "filter"]},
        {type: "DropDown", id: "DriveType", default: "CDROM", choices: [Lang("Optical disk drives"), Lang("Removable drives"), Lang("Fixed drives"), Lang("Network drives"), Lang("RAM disk drives"), Lang("Unknown drives")], result: "enum", enum: ["CDROM", "REMOVABLE", "FIXED", "NETWORK", "RAMDISK", "UNKNOWN"]},
        {type: "Label", label: Lang("If no drive can be found")},
        {type: "Radio", id: "IfNothingFound", default: "Exception", choices: [Lang("Normal") " - " Lang("Make output variable empty"), Lang("Throw exception")], result: "enum", enum: ["Normal", "Exception"]}
    ]

    static GenerateName(ctx, params) => Lang("List drives") " - " TextOps.Par(params, "Varname")

    static CheckSettings(form, params, staticValues) {
        form.Enable("DriveType", params.WhetherDriveTypeFilter = "filter")
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        letters := (p.WhetherDriveTypeFilter = "filter") ? DriveGetList(p.DriveType) : DriveGetList()
        if (letters = "") {
            if (p.IfNothingFound = "Exception")
                throw ElementError(Lang("No drives found"))
            ctx.Finish("normal", Lang("No drives found"))
            return
        }
        found := []
        loop parse letters
            found.Push(A_LoopField)
        if (!ctx.SetVar(p.Varname, found))
            throw ElementError(Lang("The variable '%1%' could not be set (the reason is in the log).", p.Varname))
        ctx.Finish("normal")
    }
}
