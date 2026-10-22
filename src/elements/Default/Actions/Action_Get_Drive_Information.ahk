#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DriveOps.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Get drive information of the package Default (WI-0122): stores one piece of information about a drive (label,
; type, status, capacity, free space, file system, serial number) in a variable. Specification: the help text of v1
; (help/en/Actions/Get_Drive_Information.md). Class ID, parameter IDs, choices and language keys are those of v1
; (Source_Elements/Default/Actions/Get_Drive_Information.ahk).
;
; Mode worker (the drives are read from the operating system). The label, the status of an optical drive, the file system
; and the serial number need a drive letter; the type, the capacity and the free space need a folder (any path on the
; drive). Differences from v1 (MIGRATION M-0139): "Status" needs a drive letter (v1 used an empty path), and the empty
; drive letter is the exception "Drive is not specified".
class Action_Get_Drive_Information extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Get Drive Information")
    static Category() => Lang("Drive")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "DriveInfo", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Which information")},
        {type: "dropdown", id: "WhichInformation", default: "Label", result: "enum", choices: [Lang("Label"), Lang("Type"), Lang("Status"), Lang("Status of optical disc drive"), Lang("Capacity"), Lang("Free disk space"), Lang("File system"), Lang("Serial number")], enum: ["Label", "Type", "Status", "StatusCD", "Capacity", "FreeSpace", "FileSystem", "Serial"]},
        {type: "Label", label: Lang("Drive letter")},
        {type: "ComboBox", id: "DriveLetter", content: "String", WarnIfEmpty: true, result: "string", default: DriveOps.Default(ctx), choices: DriveOps.Choices(ctx)},
        {type: "Label", label: Lang("Path")},
        {type: "Folder", id: "folder", label: Lang("Select a folder")}
    ]

    static GenerateName(ctx, params) {
        info := TextOps.Par(params, "WhichInformation")
        if (info = "Type" || info = "Capacity" || info = "FreeSpace")
            pathText := TextOps.Par(params, "folder")
        else
            pathText := TextOps.Par(params, "DriveLetter")
        return Lang("Get Drive Information") " - " TextOps.Par(params, "Varname") " - " this.InfoName(info) " - " pathText
    }

    ; The text of one kind of information (the v1 choice texts).
    static InfoName(info) {
        switch info {
            case "Label": return Lang("Label")
            case "Type": return Lang("Type")
            case "Status": return Lang("Status")
            case "StatusCD": return Lang("Status of optical disc drive")
            case "Capacity": return Lang("Capacity")
            case "FreeSpace": return Lang("Free disk space")
            case "FileSystem": return Lang("File system")
            case "Serial": return Lang("Serial number")
        }
        return info
    }

    static CheckSettings(form, params, staticValues) {
        info := params.WhichInformation
        byFolder := (info = "Type" || info = "Capacity" || info = "FreeSpace")
        form.Enable("DriveLetter", !byFolder)
        form.Enable("folder", byFolder)
    }

    static Run(ctx, params) {
        info := TextOps.Par(params, "WhichInformation")
        byFolder := (info = "Type" || info = "Capacity" || info = "FreeSpace")
        p := ctx.EvalParams(params, byFolder ? ["DriveLetter"] : ["folder"])
        try {
            if (byFolder) {
                if (FileOps.Attr(p.folder) = "")
                    throw ElementError(Lang("%1% '%2%' does not exist.", Lang("Folder"), p.folder))
                value := this.ReadByFolder(info, p.folder)
            } else {
                drive := DriveOps.Letter(p.DriveLetter)
                value := this.ReadByDrive(info, drive)
            }
        } catch as err {
            if (err is ElementError)
                throw err
            throw ElementError(Lang("Could not get drive information from '%1%'", byFolder ? p.folder : p.DriveLetter))
        }
        FileOps.SetOutput(ctx, p.Varname, value)
        ctx.Finish("normal")
    }

    static ReadByDrive(info, drive) {
        switch info {
            case "Label": return DriveGetLabel(drive)
            case "Status": return DriveGetStatus(drive)
            case "StatusCD": return DriveGetStatusCD(drive)
            case "FileSystem": return DriveGetFileSystem(drive)
            case "Serial": return DriveGetSerial(drive)
        }
        throw ElementError(Lang("'%1%' is not a kind of drive information.", info))
    }

    static ReadByFolder(info, path) {
        switch info {
            case "Type": return DriveGetType(path)
            case "Capacity": return DriveGetCapacity(path)
            case "FreeSpace": return DriveGetSpaceFree(path)
        }
        throw ElementError(Lang("'%1%' is not a kind of drive information.", info))
    }
}
