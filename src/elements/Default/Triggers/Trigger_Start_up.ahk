#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Trigger Start up of the package Default (WI-0063, REQ-TRG-220): fires once when it is armed with the start context of
; its type (WI-0062, PROTOCOL 4.4): "AutoHotFlow" on the context token ahfStartup (the first arming after the start of
; AutoHotFlow), "Windows" on windowsStartup (AutoHotFlow started with --windows-startup). A start with Windows carries
; both tokens, so both types fire then, as in v1. Parameters, GenerateName and language keys are those of v1
; (Source_Elements/Default/Triggers/Start_up.ahk). The trigger never fires later: not after an engine or host restart,
; and not when a flow is enabled later (the engine sends no start context then).
class Trigger_Start_up extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    ; The values of the parameter startupType, in the order of its choices (v1 enum), and their start context token.
    static TYPES := ["AutoHotFlow", "Windows"]
    static TOKENS := Map("AutoHotFlow", "ahfStartup", "Windows", "windowsStartup")

    static Name() => Lang("Start_up")
    static Category() => Lang("Time")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Trigger_event")},
        {type: "Radio", id: "startupType", default: 1, result: "enum"
            , choices: [Lang("AutoHotFlow_startup"), Lang("Windows_startup")]
            , enum: this.TYPES}
    ]

    ; "Start up - When AHF starts" (v1 Element_GenerateName_Trigger_Start_up).
    static GenerateName(ctx, params) {
        switch this.TypeOf(params.HasProp("startupType") ? params.startupType : "") {
            case "AutoHotFlow": whenText := Lang("When_AHF_starts")
            case "Windows":     whenText := Lang("When_Windows_starts")
            default:            whenText := ""
        }
        return Lang("Start_up") " - " whenText
    }

    static CheckSettings(form, params, staticValues) {
    }

    ; Fires at once when the start context carries the token of the type. Any other start, and a type that is none of
    ; TYPES, does not fire (an invalid type is refused, as v1 refuses an invalid unit: ElementError).
    static Enable(ctx, params) {
        value := params.HasProp("startupType") ? params.startupType : ""
        startType := this.TypeOf(value)
        if (startType = "")
            throw ElementError(Lang("Parameter '%1%' has invalid value: %2%", "startupType", IsObject(value) ? "" : value))
        if (InStr(ctx.context, this.TOKENS[startType]))
            ctx.Fire()
        return ""
    }

    static Disable(ctx) {
    }

    ; The thread variables: none (v1 Element_postTrigger_Trigger_Start_up sets nothing).
    static TriggerVariables(params, data) => Map()

    ; The type text of a stored startupType: the text in any case, or its index (1 or 2: v1 stores the index when a flow
    ; does not have the parameter). "" if it is none of them.
    static TypeOf(value) {
        if (IsObject(value))
            return ""
        if (IsInteger(value))
            return (value >= 1 && value <= this.TYPES.Length) ? this.TYPES[Integer(value)] : ""
        for name in this.TYPES {
            if (name = value)
                return name
        }
        return ""
    }
}
