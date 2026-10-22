#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\WindowIdent.ahk

; Action Show window of the package Default (WI-0125): shows a hidden window (WinShow) and stores its ID as A_WindowID.
; Specification: the help text of v1 (help/en/Actions/Show_Window.md). Class ID, parameter IDs and language keys are those
; of v1 (Source_Elements/Default/Actions/Show_window.ahk).
;
; Worker element (another window). A missing window is an exception, as in v1.
class Action_Show_Window extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Show Window")
    static Category() => Lang("Window")

    static Parameters(ctx) {
        list := []
        WindowIdent.AddIdentificationParameters(list)
        return list
    }

    static GenerateName(ctx, params) => Lang("Show Window") ": " WindowIdent.Name(params)

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        win := WindowIdent.Find(WindowIdent.Spec(p))
        if (win = 0)
            throw ElementError(Lang("Error! Seeked window does not exist"))
        ctx.SetVar("A_WindowID", win, "thread")
        WinShow("ahk_id " win)
        ctx.Finish("normal")
    }
}
