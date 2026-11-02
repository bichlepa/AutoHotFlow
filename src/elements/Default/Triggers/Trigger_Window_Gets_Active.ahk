#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\WindowWatch.ahk

; Trigger Window gets active of the package Default (WI-0132, REQ-TRG-260): fires when a window that the window
; identification matches becomes the active window. Parameters, GenerateName and language keys are those of v1
; (Source_Elements/Default/Triggers/Window_gets_active.ahk). Runs in the trigger host.
class Trigger_Window_Gets_Active extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Window Gets Active")
    static Category() => Lang("Window")

    static Parameters(ctx) {
        list := []
        WindowIdent.AddIdentificationParameters(list)
        list.Push({type: "Label", label: Lang("Options")})
        list.Push({type: "Checkbox", id: "NotTriggerOnEnable", default: 1
            , label: Lang("Do not trigger if a matching window is active when enabling the trigger")})
        list.Push({type: "Label", label: Lang("Check interval (ms)"), size: "small"})
        list.Push({type: "Edit", id: "interval", content: "Number", default: 500, WarnIfEmpty: true})
        return list
    }

    ; "Window gets active: <identification>" (v1 Element_GenerateName_Trigger_Window_Gets_Active).
    static GenerateName(ctx, params) => Lang("Window Gets Active") ": " WindowIdent.Name(params)

    static CheckSettings(form, params, staticValues) {
    }

    ; Refuses an identification without a window and an interval that is not above 0 (v1 texts), then polls.
    static Enable(ctx, params) => WindowWatch.Arm(ctx, params, "active")

    static Disable(ctx) => WindowWatch.Disarm(ctx)

    ; A_WindowID: the ID of the window that became active (v1 a_WindowID).
    static TriggerVariables(params, data) => WindowWatch.Variables(data)
}
