#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Block user input of the package Default (WI-0126): blocks the keyboard and the mouse of the user, or unblocks them.
; Specification: the help text of v1 (help/en/Actions/Block_user_input.md). Class ID, parameter IDs, defaults and language
; keys are those of v1 (Source_Elements/Default/Actions/Block_User_Input.ahk).
;
; Worker element: the call goes through SystemOps.BlockInput (E0103). The block stays after the element has finished (as
; in v1): it ends with Unblock, or when the worker shuts down in an orderly way (SystemOps.ReleaseInput, called by the
; worker). A worker that is killed does not release it (MIGRATION M-0156, OPEN-ITEMS).
;
; BlockInput is documented for the AutoHotkey script that calls it (the help does not ask for administrator rights);
; whether it needs them on a locked-down machine is not checked.
class Action_Block_User_Input extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "Keyboard.png"

    static Name() => Lang("Block user input")
    static Category() => Lang("User interaction")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("New block state")},
        {type: "Radio", id: "blockState", result: "enum", default: "Block"
            , choices: [Lang("Block user input"), Lang("Unblock user input")], enum: ["Block", "Unblock"]}
    ]

    static GenerateName(ctx, params) => (TextOps.Par(params, "blockState") = "Unblock")
        ? Lang("Unblock user input") : Lang("Block user input")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        SystemOps.BlockInput(p.blockState = "Block" ? "On" : "Off")
        ctx.Finish("normal")
    }
}
