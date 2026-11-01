#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\..\..\core\ElementError.ahk
#Include ..\lib\TextOps.ahk

; Action Set lock key of the package Default (WI-0126): sets Caps Lock, Num Lock or Scroll Lock to on, off, toggled, or
; forces it to stay on or off. Specification: the help text of v1 (help/en/Actions/Set_lock_key.md). Class ID, parameter
; IDs, defaults and language keys are those of v1 (Source_Elements/Default/Actions/Set_Lock_Key.ahk).
;
; Worker element: the state goes through SystemOps.SetCapsLockState, SetNumLockState or SetScrollLockState (E0103). Toggle
; reads the current state (GetKeyState "T", not a seam function: it only reads) and sets the opposite one.
class Action_Set_Lock_Key extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "Keyboard.png"

    static Name() => Lang("Set Lock Key")
    static Category() => Lang("User simulation")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Which lock key")},
        {type: "Radio", id: "WhichKey", default: "CapsLock", choices: [Lang("Caps lock"), Lang("Num lock"), Lang("Scroll lock")]
            , result: "enum", enum: ["CapsLock", "NumLock", "ScrollLock"]},
        {type: "Label", label: Lang("Status to set")},
        {type: "Radio", id: "Status", default: "On"
            , choices: [Lang("On"), Lang("Off"), Lang("Toggle"), Lang("Always on"), Lang("Always off")]
            , result: "enum", enum: ["On", "Off", "Toggle", "AlwaysOn", "AlwaysOff"]}
    ]

    static GenerateName(ctx, params) {
        switch (TextOps.Par(params, "WhichKey")) {
            case "CapsLock": keyText := Lang("Caps lock")
            case "NumLock": keyText := Lang("Num lock")
            case "ScrollLock": keyText := Lang("Scroll lock")
            default: keyText := TextOps.Par(params, "WhichKey")
        }
        switch (TextOps.Par(params, "Status")) {
            case "On": statusText := Lang("On")
            case "Off": statusText := Lang("Off")
            case "Toggle": statusText := Lang("Toggle")
            case "AlwaysOn": statusText := Lang("Always on")
            case "AlwaysOff": statusText := Lang("Always off")
            default: statusText := TextOps.Par(params, "Status")
        }
        return Lang("Set Lock Key") " - " keyText " - " statusText
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        ; the value for the call: the enum value, or the opposite of the current state for Toggle (1 on, 0 off)
        value := p.Status
        if (p.Status = "Toggle")
            value := !GetKeyState(p.WhichKey, "T")
        switch (p.WhichKey) {
            case "CapsLock": SystemOps.SetCapsLockState(value)
            case "NumLock": SystemOps.SetNumLockState(value)
            case "ScrollLock": SystemOps.SetScrollLockState(value)
            default: throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "WhichKey", p.WhichKey))
        }
        ctx.Finish("normal")
    }
}
