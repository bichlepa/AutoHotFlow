#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ProcessWatch.ahk

; Trigger Process starts of the package Default (WI-0132, REQ-TRG-270): fires for every process that matches the process
; name or ID and was not running at the last poll. Class ID, parameters, GenerateName and language keys are those of v1
; (Source_Elements/Default/Triggers/Process_starts.ahk). The label of NotTriggerOnEnable is the v1 text, which says
; "window"; the option means a matching process. Runs in the trigger host.
class Trigger_Process_starts extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Process starts")
    static Category() => Lang("Process")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Process Name")},
        {type: "Edit", id: "ProcessName", content: "String"},
        {type: "Label", label: Lang("Options")},
        {type: "Checkbox", id: "NotTriggerOnEnable", default: 1
            , label: Lang("Do not trigger if a matching window exists when enabling the trigger")},
        {type: "Label", label: Lang("Check interval (ms)"), size: "small"},
        {type: "Edit", id: "interval", content: "Number", default: 1000, WarnIfEmpty: true}
    ]

    ; "Process starts" and the process name on the next line (v1 Element_GenerateName_Trigger_Process_starts).
    static GenerateName(ctx, params) => Lang("Process starts") "`n" (params.HasProp("ProcessName") ? params.ProcessName : "")

    static CheckSettings(form, params, staticValues) {
    }

    ; Refuses an interval that is not above 0 (v1 text), then polls. An empty name matches every process.
    static Enable(ctx, params) => ProcessWatch.Arm(ctx, params, "starts")

    static Disable(ctx) => ProcessWatch.Disarm(ctx)

    ; A_ProcessID and A_ProcessName: the started process (v1 a_processID, a_processName).
    static TriggerVariables(params, data) => ProcessWatch.Variables(data)
}
