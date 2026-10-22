#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\WindowIdent.ahk

; Action Hide window of the package Default (WI-0125): hides a window (WinHide) and stores its ID as A_WindowID.
; Specification: the help text of v1 (help/en/Actions/Hide_Window.md). Class ID, parameter IDs and language keys are those
; of v1 (Source_Elements/Default/Actions/Hide_window.ahk).
;
; Worker element (another window). A missing window is an exception, as in v1.
class Action_Hide_Window extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Hide Window")
    static Category() => Lang("Window")

    static Parameters(ctx) {
        list := []
        WindowIdent.AddIdentificationParameters(list)
        return list
    }

    static GenerateName(ctx, params) => Lang("Hide Window") ": " WindowIdent.Name(params)

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        win := WindowIdent.Find(WindowIdent.Spec(p))
        if (win = 0)
            throw ElementError(Lang("Error! Seeked window does not exist"))
        ctx.SetVar("A_WindowID", win, "thread")
        WinHide("ahk_id " win)
        ctx.Finish("normal")
    }
}
