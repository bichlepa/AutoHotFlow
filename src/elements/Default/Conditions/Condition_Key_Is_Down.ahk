#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\TextOps.ahk

; Condition Key is down of the package Default (WI-0126): yes while the key is held down, no otherwise. The logical state
; is the state the system and the active window see; the physical state is the state of the key on the keyboard (they
; differ when the hooks are installed or a key is sent). Specification: the help text of v1 (help/en/Conditions/key_is_down.md).
; Class ID, parameter IDs, defaults and language keys are those of v1 (Source_Elements/Default/Conditions/Key_Is_Down.ahk).
;
; Worker element (GetKeyState is a read; the element runs in the worker like the other input elements). A key name that
; AutoHotkey does not know is an exception.
class Condition_Key_Is_Down extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "Keyboard.png"

    static Name() => Lang("Key Is Down")
    static Category() => Lang("User interaction")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Key name")},
        {type: "Edit", id: "key", content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Which key state")},
        {type: "Radio", id: "WhichKeyState", default: "logical", result: "enum"
            , choices: [Lang("Logical"), Lang("Physical")], enum: ["logical", "physical"]}
    ]

    static GenerateName(ctx, params) => Lang("Key Is Down") " - " TextOps.Par(params, "key")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        down := (p.WhichKeyState = "physical") ? GetKeyState(p.key, "P") : GetKeyState(p.key)
        ctx.Finish(DialogOps.Truthy(down) ? "yes" : "no")
    }
}
