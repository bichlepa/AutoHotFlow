#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Trigger Manual of the package Default (WI-0047): it fires only when the user (or the engine on cmd.flow.start) starts
; the flow; Enable and Disable do nothing. Parameters, GenerateName and language keys are those of v1
; (Source_Elements/Default/Triggers/Manual.ahk). The ID names the trigger when a flow has several.
; v1 gave a new element the default "Trigger <random phrase>" (with updateOnEdit); that is the job of the
; editor (S0007), so the default here is empty: a flow of v1 always has the parameter.
class Trigger_Manual extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Manual")
    static Category() => Lang("User_interaction")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("ID")},
        {type: "Edit", id: "ID", content: "rawstring", default: ""}
    ]

    ; "Manual" and, on a second line, the ID in quotes (v1 Element_GenerateName_Trigger_Manual).
    static GenerateName(ctx, params) => Lang("Manual") "`n" '"' (params.HasProp("ID") ? params.ID : "") '"'

    static CheckSettings(form, params, staticValues) {
    }

    static Enable(ctx, params) => ""
    static Disable(ctx) {
    }

    ; Pure function, runs in the engine: the thread variables after the event. v1 sets A_ManualTriggerID to the ID
    ; (Element_postTrigger_Trigger_Manual). The engine calls TriggerVariables with the trigger host (S0003).
    static TriggerVariables(params, data) => Map("A_ManualTriggerID", params.HasProp("ID") ? params.ID : "")
}
