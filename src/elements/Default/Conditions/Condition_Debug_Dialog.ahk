#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DebugOps.ahk

; Condition Debug dialog of the package Default (WI-0056, REQ-DBG-060): halts the branch and opens the debug window. The
; window lists every variable the branch can see, grouped by scope, shows and changes their values and types, and deletes
; them. The buttons Yes and No are the outputs of the condition. Closing the window ends the element with exception
; "User dismissed the dialog", as v1 did (help/en/Conditions/Debug_dialog.html, Debug_dialog.ahk). Other branches and
; flows go on while the window is open.
;
; Worker element (ARCHITECTURE 2.3): the variables are read and changed through the requests to the engine (ctx, WI-0050).
class Condition_Debug_Dialog extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "Bug.png"

    static Name() => Lang("Debug_Dialog")
    static Category() => Lang("Debugging")

    static GenerateName(ctx, params) => Lang("Debug_dialog")

    static Run(ctx, params) {
        result := Dialogs.DebugWindow(DebugOps(ctx, false))
        if (result = "close")
            throw ElementError("User dismissed the dialog")
        ctx.Finish(result = "yes" ? "yes" : "no")
    }
}
