#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\WindowIdent.ahk

; Action Close window of the package Default (WI-0125): closes a window (WinClose, the window gets the close message) or
; kills it (WinKill, the process of the window is ended with it), as the setting WinCloseMethod says. Specification: the
; help text of v1 (help/en/Actions/Close_Window.md). Class ID, parameter IDs and language keys are those of v1
; (Source_Elements/Default/Actions/Close_Window.ahk).
;
; Worker element (another window). The element does not wait for the window to go away, as v1 did; a window that asks
; before it closes stays open. A missing window is an exception, as in v1. Tests close only their own windows.
class Action_Close_Window extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Close Window")
    static Category() => Lang("Window")

    static Parameters(ctx) {
        list := []
        WindowIdent.AddIdentificationParameters(list)
        list.Push({type: "Label", label: Lang("Method")})
        list.Push({type: "Radio", id: "WinCloseMethod", default: 1, result: "enum"
            , choices: [Lang("Close"), Lang("Kill")], enum: ["close", "kill"]})
        return list
    }

    static GenerateName(ctx, params) => Lang("Close Window") ": " WindowIdent.Name(params)

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        win := WindowIdent.Find(WindowIdent.Spec(p))
        if (win = 0)
            throw ElementError(Lang("Error! Seeked window does not exist"))
        ctx.SetVar("A_WindowID", win, "thread")
        ; the stored value is the enum text; a flow without the parameter has the position of the first choice (1)
        if (this.Kill(p.WinCloseMethod))
            WinKill("ahk_id " win)
        else
            WinClose("ahk_id " win)
        ctx.Finish("normal")
    }

    ; True for the method "kill" (the text, or the position 2 of the choices). Any other value closes: the first choice is
    ; the default, and v1 did nothing for a value that was neither (MIGRATION M-0132).
    static Kill(method) => (method = "kill" || method = 2)
}
