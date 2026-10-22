#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Suspend computer of the package Default (WI-0123): puts the computer into standby (SetSuspendState with hibernate
; 0, force 0, as v1). Specification: the help text of v1 (help/en/Actions/Suspend_Computer.md). Class ID and language keys
; are those of v1 (Source_Elements/Default/Actions/Suspend_computer.ahk).
;
; Worker element; the call goes through the seam SystemOps (E0103): a test records it and suspends nothing. The result of
; the system is not checked (as v1).
class Action_Suspend_Computer extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Suspend Computer")
    static Category() => Lang("Power")

    static Parameters(ctx) => []

    static GenerateName(ctx, params) => Lang("Suspend Computer")

    static Run(ctx, params) {
        SystemOps.Suspend(0)
        ctx.Finish("normal")
    }
}
