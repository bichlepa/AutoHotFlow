#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\WindowWatch.ahk

; Trigger Window gets inactive of the package Default (WI-0132, REQ-TRG-260): fires when the window that the window
; identification matched was the active window and another window (or none) is active at the next poll. The ID of that
; window is A_WindowID. Parameters, GenerateName and language keys are those of v1
; (Source_Elements/Default/Triggers/Window_gets_inactive.ahk). Runs in the trigger host.
class Trigger_Window_Gets_Inactive extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Window Gets Inactive")
    static Category() => Lang("Window")

    static Parameters(ctx) {
        list := []
        WindowIdent.AddIdentificationParameters(list)
        list.Push({type: "Label", label: Lang("Options")})
        list.Push({type: "Label", label: Lang("Check interval (ms)"), size: "small"})
        list.Push({type: "Edit", id: "interval", content: "Number", default: 500, WarnIfEmpty: true})
        return list
    }

    ; "Window gets inactive: <identification>" (v1 Element_GenerateName_Trigger_Window_Gets_Inactive).
    static GenerateName(ctx, params) => Lang("Window Gets Inactive") ": " WindowIdent.Name(params)

    static CheckSettings(form, params, staticValues) {
    }

    ; The active matching window at the arming is the baseline (v1 first call).
    static Enable(ctx, params) => WindowWatch.Arm(ctx, params, "inactive")

    static Disable(ctx) => WindowWatch.Disarm(ctx)

    ; A_WindowID: the ID of the window that stopped being active (v1 a_WindowID).
    static TriggerVariables(params, data) => WindowWatch.Variables(data)
}
