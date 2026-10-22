#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Get volume of the package Default (WI-0124): stores the master volume of the first sound device (0 to 100) in a
; variable. Specification: the help text of v1 (help/en/Actions/Get_Volume.md). Class ID, parameter IDs, defaults and
; language keys are those of v1 (Source_Elements/Default/Actions/Get_Volume.ahk).
;
; Mode worker, because the variable is written through the engine. Reading the volume changes nothing, so the call is
; AutoHotkey's SoundGetVolume and not a seam call (ELEMENT-API-V2 3.3a); the tests read the real volume and check the range.
class Action_Get_Volume extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Get Volume")
    static Category() => Lang("Sound")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output Variable name")},
        {type: "Edit", id: "Varname", default: "Volume", content: "VariableName", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) => Lang("Get Volume") "`n" TextOps.Par(params, "Varname")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        try volume := SoundGetVolume()
        catch
            throw ElementError(Lang("Volume could not be read"))
        if (!ctx.SetVar(p.Varname, volume))
            throw ElementError(Lang("The variable '%1%' could not be set (the reason is in the log).", p.Varname))
        ctx.Finish("normal")
    }
}
