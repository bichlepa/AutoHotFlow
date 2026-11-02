#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\WindowWatch.ahk

; Trigger Window opens of the package Default (WI-0132, REQ-TRG-260): fires for every window that the window
; identification matches and that was not there at the last poll. Parameters, GenerateName and language keys are those
; of v1 (Source_Elements/Default/Triggers/Window_opens.ahk). Runs in the trigger host; the polls are WindowWatch/WatchPoll.
class Trigger_Window_Opens extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Window Opens")
    static Category() => Lang("Window")

    static Parameters(ctx) {
        list := []
        WindowIdent.AddIdentificationParameters(list)
        list.Push({type: "Label", label: Lang("Options")})
        list.Push({type: "Checkbox", id: "NotTriggerOnEnable", default: 1
            , label: Lang("Do not trigger if a matching window exists when enabling the trigger")})
        list.Push({type: "Label", label: Lang("Check interval (ms)"), size: "small"})
        list.Push({type: "Edit", id: "interval", content: "Number", default: 500, WarnIfEmpty: true})
        return list
    }

    ; "Window opens: <identification>" (v1 Element_GenerateName_Trigger_Window_Opens).
    static GenerateName(ctx, params) => Lang("Window Opens") ": " WindowIdent.Name(params)

    static CheckSettings(form, params, staticValues) {
    }

    ; Refuses an identification without a window and an interval that is not above 0 (v1 texts), then polls.
    static Enable(ctx, params) => WindowWatch.Arm(ctx, params, "opens")

    static Disable(ctx) => WindowWatch.Disarm(ctx)

    ; A_WindowID: the ID of the new window (v1 a_WindowID).
    static TriggerVariables(params, data) => WindowWatch.Variables(data)
}
