#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Lock computer of the package Default (WI-0123): locks the workstation (the same as the Windows key + L). Specification:
; the help text of v1 (help/en/Actions/Lock_Computer.md). Class ID and language keys are those of v1
; (Source_Elements/Default/Actions/Lock_computer.ahk).
;
; Worker element; the call goes through the seam SystemOps (E0103): a test records it and locks nothing.
class Action_Lock_Computer extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Lock Computer")
    static Category() => Lang("Power")

    static Parameters(ctx) => []

    static GenerateName(ctx, params) => Lang("Lock Computer")

    static Run(ctx, params) {
        SystemOps.LockWorkStation()
        ctx.Finish("normal")
    }
}
