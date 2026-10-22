#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\TextOps.ahk

; Action Shutdown of the package Default (WI-0123): shuts the computer down (Shutdown code 9, the power off of v1). Force
; adds 4: the open applications are closed without asking, which can lose data. Specification: the help text of v1
; (help/en/Actions/Shutdown.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Shutdown.ahk).
;
; Worker element; the call goes through the seam SystemOps (E0103): a test records the code and shuts nothing down.
; The name shows "Shutdown (force)" for the force option (v1 showed it the other way round, MIGRATION M-0123).
class Action_Shutdown extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Shutdown")
    static Category() => Lang("Power")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Force #verb")},
        {type: "Checkbox", id: "Force", default: 0, label: Lang("Force (this can cause loss of data!)")}
    ]

    static GenerateName(ctx, params) => DialogOps.Truthy(TextOps.Par(params, "Force")) ? Lang("Shutdown (force)") : Lang("Shutdown")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        flags := 9                                  ; shut down and power off (v1)
        if (DialogOps.Truthy(p.Force))
            flags += 4
        SystemOps.Shutdown(flags)
        ctx.Finish("normal")
    }
}
