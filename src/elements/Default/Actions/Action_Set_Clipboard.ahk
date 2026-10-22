#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Set clipboard of the package Default (WI-0123): puts a text into the Windows clipboard. Specification: the help
; text of v1 (help/en/Actions/Set_Clipboard.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Set_clipboard.ahk).
;
; Worker element. The clipboard is the real one (no seam). A clipboard that another program keeps busy is an exception
; with the text "The clipboard could not be used" (MIGRATION M-0122); v1 ignored the failure.
class Action_Set_Clipboard extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Set Clipboard")
    static Category() => Lang("Variable")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("New clipboard content")},
        {type: "Edit", id: "text", default: "New element", content: ["String", "Expression"], contentID: "expression", contentDefault: "string"}
    ]

    static GenerateName(ctx, params) => Lang("Set Clipboard") " - " TextOps.Par(params, "text")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        try
            A_Clipboard := p.text
        catch
            throw ElementError(Lang("The clipboard could not be used"))
        ctx.Finish("normal")
    }
}
