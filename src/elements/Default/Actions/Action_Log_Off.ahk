#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Log off of the package Default (WI-0123): logs off the current user (Shutdown with the code 0, as v1). Specification:
; the help text of v1 (help/en/Actions/Log_Off.md). Class ID and language keys are those of v1
; (Source_Elements/Default/Actions/Log_off.ahk).
;
; Worker element; the call goes through the seam SystemOps (E0103): a test records it and logs off nobody.
class Action_Log_Off extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Log Off")
    static Category() => Lang("Power")

    static Parameters(ctx) => []

    static GenerateName(ctx, params) => Lang("Log Off")

    static Run(ctx, params) {
        SystemOps.Shutdown(0)
        ctx.Finish("normal")
    }
}
