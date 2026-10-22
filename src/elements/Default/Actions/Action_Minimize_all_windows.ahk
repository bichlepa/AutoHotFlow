#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Action Minimize all windows of the package Default (WI-0125): minimizes every window of the user (Minimize) or restores
; them again (Undo, the undo of the last minimize). Specification: the help text of v1 (help/en/Actions/Minimize_All_Windows.md).
; Class ID, parameter IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Minimize_All_Windows.ahk).
;
; Worker element. The call goes through SystemOps (E0103): it changes the windows of the whole desktop, which a test must
; not do; tests use the test provider and the owner checks the real desktop (WI-0135). Every window that the user has is
; affected, not only those of the flow.
class Action_Minimize_all_windows extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Minimize all windows")
    static Category() => Lang("Window")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Event")},
        {type: "Radio", id: "WinMinimizeAllEvent", default: "Minimize", result: "enum"
            , choices: [Lang("Minimize all windows"), Lang("Undo")], enum: ["Minimize", "Undo"]}
    ]

    static GenerateName(ctx, params) => Lang("Minimize all windows")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        if (p.WinMinimizeAllEvent = "Undo")
            SystemOps.WinMinimizeAllUndo()
        else
            SystemOps.WinMinimizeAll()
        ctx.Finish("normal")
    }
}
