#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\TextOps.ahk

; Action Reboot computer of the package Default (WI-0123): restarts the computer (Shutdown code 2, as v1). Force adds 4:
; the open applications are closed without asking, which can lose data. Specification: the help text of v1
; (help/en/Actions/Reboot_Computer.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Reboot_computer.ahk).
;
; Worker element; the call goes through the seam SystemOps (E0103): a test records the code and restarts nothing.
; The name shows "(force)" for the force option (v1 showed it the other way round, MIGRATION M-0123).
class Action_Reboot_Computer extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Reboot Computer")
    static Category() => Lang("Power")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Force #verb")},
        {type: "Checkbox", id: "Force", default: 0, label: Lang("Force (this can cause loss of data!)")}
    ]

    static GenerateName(ctx, params) => DialogOps.Truthy(TextOps.Par(params, "Force")) ? Lang("Reboot computer (force)") : Lang("Reboot Computer")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        flags := 2                                  ; restart (v1)
        if (DialogOps.Truthy(p.Force))
            flags += 4
        SystemOps.Shutdown(flags)
        ctx.Finish("normal")
    }
}
