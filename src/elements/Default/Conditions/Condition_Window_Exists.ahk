#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\WindowIdent.ahk

; Condition Window exists of the package Default (WI-0125): yes when a window of the identification exists, no otherwise.
; Hidden windows are found when the setting "Detect hidden window" is on (FindHiddenWindow). The ID of a found window is
; stored as A_WindowID. Specification: the help text of v1 (help/en/Conditions/Window_Exists.md). Class ID, parameter IDs
; and language keys are those of v1 (Source_Elements/Default/Conditions/Window_Exists.ahk).
;
; Worker element (another window). No window at all in the settings is an exception, as in v1.
class Condition_Window_Exists extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Window Exists")
    static Category() => Lang("Window")

    static Parameters(ctx) {
        list := []
        WindowIdent.AddIdentificationParameters(list)
        return list
    }

    static GenerateName(ctx, params) => Lang("Window Exists") ": " WindowIdent.Name(params)

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        win := WindowIdent.Find(WindowIdent.Spec(p))
        if (win = 0) {
            ctx.Finish("no")
            return
        }
        ctx.SetVar("A_WindowID", win, "thread")
        ctx.Finish("yes")
    }
}
