#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Hibernate computer of the package Default (WI-0123): puts the computer into hibernation (SetSuspendState with
; hibernate 1, force 0, as v1). Specification: the help text of v1 (help/en/Actions/Hibernate_Computer.md). Class ID and
; language keys are those of v1 (Source_Elements/Default/Actions/Hibernate_computer.ahk).
;
; Worker element; the call goes through the seam SystemOps (E0103): a test records it and hibernates nothing. Whether the
; computer can hibernate depends on its settings; the system refuses otherwise and the element does not check it.
class Action_Hibernate_Computer extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Hibernate Computer")
    static Category() => Lang("Power")

    static Parameters(ctx) => []

    static GenerateName(ctx, params) => Lang("Hibernate Computer")

    static Run(ctx, params) {
        SystemOps.Hibernate(0)
        ctx.Finish("normal")
    }
}
