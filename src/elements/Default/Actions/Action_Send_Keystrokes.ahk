#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\TextOps.ahk

; Action Send keystrokes of the package Default (WI-0126): sends keys and text to the window that has the keyboard focus,
; with the send method (Input, Event or Play). Specification: the help text of v1 (help/en/Actions/Send_keystrokes.md).
; Class ID, parameter IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Send_Keystrokes.ahk).
;
; Worker element: the keys go through SystemOps.Send (E0103), which sets the send mode for that call only. Raw mode
; prefixes the text with {Raw} (as v1 prefixed {raw}): the special characters ^+!#{} are then sent as text. The key names
; are those of AutoHotkey v2 (the help page lists them; the v1 names of the keys are not translated).
class Action_Send_Keystrokes extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "Keyboard.png"

    static Name() => Lang("Send keystrokes")
    static Category() => Lang("User simulation")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Keys or text to send")},
        {type: "Checkbox", id: "RawMode", default: 0, label: Lang("Raw mode")},
        {type: "Edit", id: "KeysToSend", content: ["RawString", "String"], contentID: "KeysToSendContentType"
            , contentDefault: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Send mode")},
        {type: "Radio", id: "SendMode", default: "Input", choices: [Lang("Input mode"), Lang("Event mode"), Lang("Play mode")]
            , result: "enum", enum: ["Input", "Event", "Play"]}
    ]

    static GenerateName(ctx, params) => Lang("Send keystrokes") " - " TextOps.Par(params, "KeysToSend")

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        keys := String(p.KeysToSend)
        if (DialogOps.Truthy(p.RawMode))
            keys := "{Raw}" keys
        SystemOps.Send(keys, p.SendMode)
        ctx.Finish("normal")
    }
}
