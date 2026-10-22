#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\FileOps.ahk
#Include ..\lib\TextOps.ahk

; Action Get shortcut information of the package Default (WI-0121): reads a shortcut (.lnk) and stores its target, arguments,
; working folder, description, icon, icon number and run mode in variables. Specification: the help text of v1
; (help/en/Actions/Get_shortcut_information.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Get_shortcut_information.ahk).
;
; FileGetShortcut (v2) throws on failure. The run mode is stored as the text of v1: Normal, Maximized, Minimized, or
; "Unknown (n)". An output variable with an empty name is not stored (MIGRATION M-0126). Worker element (the file access,
; ARCHITECTURE 2.3).
class Action_Get_shortcut_information extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Get shortcut information")
    static Category() => Lang("File")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Shortcut path")},
        {type: "File", id: "shortcutFile", label: Lang("Select a shortcut file"), filter: Lang("Shortcut file") " (*.lnk)", options: 32},
        {type: "Label", label: Lang("Output variables")},
        {type: "Label", label: Lang("Target path"), size: "small"},
        {type: "Edit", id: "OutTarget", default: "shortcutTarget", content: "VariableName"},
        {type: "Label", label: Lang("Target arguments"), size: "small"},
        {type: "Edit", id: "OutArgs", default: "shortcutArgs", content: "VariableName"},
        {type: "Label", label: Lang("Working directory"), size: "small"},
        {type: "Edit", id: "OutDir", default: "shortcutDir", content: "VariableName"},
        {type: "Label", label: Lang("Description"), size: "small"},
        {type: "Edit", id: "OutDescription", default: "shortcutDescription", content: "VariableName"},
        {type: "Label", label: Lang("Icon path"), size: "small"},
        {type: "Edit", id: "OutIcon", default: "shortcutIcon", content: "VariableName"},
        {type: "Label", label: Lang("Icon number"), size: "small"},
        {type: "Edit", id: "OutIconNum", default: "shortcutIconNumber", content: "VariableName"},
        {type: "Label", label: Lang("Run mode"), size: "small"},
        {type: "Edit", id: "OutRunState", default: "shortcutRunMode", content: "VariableName"}
    ]

    static GenerateName(ctx, params) => Lang("Get shortcut information") " - " TextOps.Par(params, "shortcutFile")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        target := "", dir := "", args := "", description := "", icon := "", iconNum := "", runState := ""
        try FileGetShortcut(p.shortcutFile, &target, &dir, &args, &description, &icon, &iconNum, &runState)
        catch as err
            throw FileOps.Fail(Lang("Can't read informations of shortcut '%1%'", p.shortcutFile), FileOps.Code(err))
        this._Store(ctx, p.OutTarget, target)
        this._Store(ctx, p.OutArgs, args)
        this._Store(ctx, p.OutDir, dir)
        this._Store(ctx, p.OutDescription, description)
        this._Store(ctx, p.OutIcon, icon)
        this._Store(ctx, p.OutIconNum, iconNum)
        this._Store(ctx, p.OutRunState, this._RunMode(runState))
        ctx.Finish("normal")
    }

    ; Stores a value in the variable of the given name (nothing when the name is empty).
    static _Store(ctx, name, value) {
        if (name != "")
            FileOps.SetOutput(ctx, name, value)
    }

    ; The text of a run mode of FileGetShortcut (1 normal, 3 maximized, 7 minimized), as v1 wrote it.
    static _RunMode(state) {
        switch state {
            case 1: return "Normal"
            case 3: return "Maximized"
            case 7: return "Minimized"
        }
        return Lang("Unknown (%1%)", state)
    }
}
