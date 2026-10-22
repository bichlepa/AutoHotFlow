#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\WindowIdent.ahk

; Action Activate window of the package Default (WI-0125): activates the window that the window identification names and
; stores its ID as A_WindowID. Specification: the help text of v1 (help/en/Actions/activate_Window.md). Class ID, parameter
; IDs and language keys are those of v1 (Source_Elements/Default/Actions/activate_Window.ahk).
;
; Worker element (another window, the focus). The v1 code has no wait: it activates and finishes. Here the element waits
; up to ActivateWaitS seconds for the window to become the active one, so that a flow that goes on sees the window active;
; a window that does not get the focus (Windows refuses it) is not an exception, as in v1 (MIGRATION M-0136). The test of
; this element takes the focus and holds the input lock (doc/TEST-STRATEGY.md).
class Action_Activate_Window extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static ActivateWaitS := 2

    static Name() => Lang("Activate Window")
    static Category() => Lang("Window")

    static Parameters(ctx) {
        list := []
        WindowIdent.AddIdentificationParameters(list)
        return list
    }

    static GenerateName(ctx, params) => Lang("Activate Window") ": " WindowIdent.Name(params)

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        spec := WindowIdent.Spec(p)
        win := WindowIdent.Find(spec)
        if (win = 0)
            throw ElementError(Lang("Error! Seeked window does not exist"))
        ctx.SetVar("A_WindowID", win, "thread")
        WinActivate("ahk_id " win)
        WinWaitActive("ahk_id " win,, this.ActivateWaitS)
        ctx.Finish("normal")
    }
}
