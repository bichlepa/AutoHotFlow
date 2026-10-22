#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Create shortcut of the package Default (WI-0121): writes a shortcut (.lnk) to a target file, with the arguments,
; the working folder, a description, an icon and the run mode. Specification: the help text of v1
; (help/en/Actions/Create_Shortcut.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Create_Shortcut.ahk).
;
; FileCreateShortcut (v2) throws on failure; the element ends with the v1 text and the reason of the system. The icon
; number is passed only with an icon and when it is set (as v1); the run mode is 1 normal, 3 maximized, 7 minimized.
; Worker element (the file access, ARCHITECTURE 2.3).
class Action_Create_Shortcut extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Create shortcut")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Shortcut path")},
        {type: "File", id: "shortcutFile", default: "shortcut.lnk", label: Lang("Select a shortcut file"), filter: Lang("Shortcut file") " (*.lnk)", options: 32, WarnIfEmpty: true},
        {type: "Label", label: Lang("Target path")},
        {type: "File", id: "file", label: Lang("Select a target file"), WarnIfEmpty: true},
        {type: "Label", label: Lang("Target arguments")},
        {type: "Edit", id: "runArguments", content: ["String", "RawString"], contentID: "ToRunContent", contentDefault: "string"},
        {type: "Label", label: Lang("Working directory")},
        {type: "Folder", id: "WorkingDir", label: Lang("Select a folder")},
        {type: "Label", label: Lang("Description")},
        {type: "Edit", id: "description", content: "String"},
        {type: "Label", label: Lang("Icon path")},
        {type: "File", id: "iconFile", label: Lang("Select an icon"), options: 8, filter: Lang("File with icon") " (*.ico; *.exe; *.dll)"},
        {type: "Label", label: Lang("File with multiple icons"), size: "small"},
        {type: "Checkbox", id: "SetIconNumber", default: 0, label: Lang("Set icon number")},
        {type: "Edit", id: "IconNumber", default: 1, content: "PositiveInteger", WarnIfEmpty: true},
        {type: "Label", label: Lang("Run mode")},
        {type: "Radio", id: "RunMode", default: "Normal", result: "enum", choices: [Lang("Run normally"), Lang("Run maximized"), Lang("Run minimized")], enum: ["Normal", "Max", "Min"]}
    ]

    static GenerateName(ctx, params) => Lang("Create shortcut") " - " TextOps.Par(params, "shortcutFile") " - " TextOps.Par(params, "file") " " TextOps.Par(params, "runArguments")

    static CheckSettings(form, params, staticValues) {
        hasIcon := TextOps.Par(params, "iconFile") != ""
        form.Disable("SetIconNumber", !hasIcon)
        form.Disable("IconNumber", !hasIcon || !DialogOps.Truthy(TextOps.Par(params, "SetIconNumber")))
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params, "WorkingDir,iconFile,IconNumber")   ; the optional parts are evaluated only when set (as v1)
        runMode := (p.RunMode = "Max") ? 3 : (p.RunMode = "Min") ? 7 : 1
        workingDir := ""
        if (TextOps.Par(params, "WorkingDir") != "")
            workingDir := ctx.EvalMoreParams(p, params, "WorkingDir").WorkingDir
        icon := "", iconNumber := 0           ; 0 is the first icon, the default of FileCreateShortcut
        if (TextOps.Par(params, "iconFile") != "") {
            icon := ctx.EvalMoreParams(p, params, "iconFile").iconFile
            if (DialogOps.Truthy(TextOps.Par(params, "SetIconNumber")))
                iconNumber := ctx.EvalMoreParams(p, params, "IconNumber").IconNumber
        }
        ; Target, LinkFile, WorkingDir, Args, Description, IconFile, ShortcutKey (none), IconNumber, RunState
        try FileCreateShortcut(p.file, p.shortcutFile, workingDir, p.runArguments, p.description, icon, "", iconNumber, runMode)
        catch as err
            throw FileOps.Fail(Lang("Can't create shortcut '%1%'", p.shortcutFile), FileOps.Code(err))
        ctx.Finish("normal")
    }
}
