#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ProcessWatch.ahk

; Trigger Process closes of the package Default (WI-0132, REQ-TRG-270): fires for every process that matches the process
; name or ID at the arming or at a later poll and is gone at the next poll. Class ID, parameters, GenerateName and
; language keys are those of v1 (Source_Elements/Default/Triggers/Process_closes.ahk). Runs in the trigger host.
class Trigger_Process_Closes extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Process Closes")
    static Category() => Lang("Process")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Process name or ID")},
        {type: "Edit", id: "ProcessName", content: "String"},
        {type: "Label", label: Lang("Options")},
        {type: "Label", label: Lang("Check interval (ms)"), size: "small"},
        {type: "Edit", id: "interval", content: "Number", default: 1000, WarnIfEmpty: true}
    ]

    ; "Process closes" and the process name on the next line (v1 Element_GenerateName_Trigger_Process_Closes).
    static GenerateName(ctx, params) => Lang("Process Closes") "`n" (params.HasProp("ProcessName") ? params.ProcessName : "")

    static CheckSettings(form, params, staticValues) {
    }

    ; Refuses an interval that is not above 0 (v1 text), then polls. An empty name matches every process.
    static Enable(ctx, params) => ProcessWatch.Arm(ctx, params, "closes")

    static Disable(ctx) => ProcessWatch.Disarm(ctx)

    ; A_ProcessID and A_ProcessName: the closed process (v1 A_ProcessID, A_ProcessName).
    static TriggerVariables(params, data) => ProcessWatch.Variables(data)
}
