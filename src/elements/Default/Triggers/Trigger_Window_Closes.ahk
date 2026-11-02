#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\WindowWatch.ahk

; Trigger Window closes of the package Default (WI-0132, REQ-TRG-260): fires for every window that the window
; identification matched at the arming or at a later poll and that is gone at the next poll. Parameters, GenerateName
; and language keys are those of v1 (Source_Elements/Default/Triggers/Window_closes.ahk). Runs in the trigger host.
class Trigger_Window_Closes extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Window Closes")
    static Category() => Lang("Window")

    static Parameters(ctx) {
        list := []
        WindowIdent.AddIdentificationParameters(list)
        list.Push({type: "Label", label: Lang("Options")})
        list.Push({type: "Label", label: Lang("Check interval (ms)"), size: "small"})
        list.Push({type: "Edit", id: "interval", content: "Number", default: 500, WarnIfEmpty: true})
        return list
    }

    ; "Window closes: <identification>" (v1 Element_GenerateName_Trigger_Window_Closes).
    static GenerateName(ctx, params) => Lang("Window Closes") ": " WindowIdent.Name(params)

    static CheckSettings(form, params, staticValues) {
    }

    ; The matching windows at the arming are the baseline (v1: always, there is no option for it).
    static Enable(ctx, params) => WindowWatch.Arm(ctx, params, "closes")

    static Disable(ctx) => WindowWatch.Disarm(ctx)

    ; A_WindowID: the ID of the closed window (v1 a_WindowID).
    static TriggerVariables(params, data) => WindowWatch.Variables(data)
}
