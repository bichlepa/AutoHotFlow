#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\TextOps.ahk

; Action Set volume of the package Default (WI-0124): sets the mute state, an absolute volume (0 to 100) or changes the
; volume by a relative amount of the master volume of the first sound device. Specification: the help text of v1
; (help/en/Actions/Set_Volume.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Set_Volume.ahk).
;
; Mode worker. The calls go through the seam SystemOps (E0103): a test records them and changes no volume.
; Differences from v1: the default of the action is the value of the radio (enum "Mute", v1 wrote the position 1; M-0099),
; the relative amount is a number field and not a slider (the editor draws sliders from 0 to 100 only; M-0126).
; A failing call ends with the exception "Volume could not be set" (MIGRATION M-0128).
class Action_Set_Volume extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Set Volume")
    static Category() => Lang("Sound")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Action")},
        {type: "Radio", id: "Action", default: "Mute", choices: [Lang("Set mute state"), Lang("Set a Specified volume")
            , Lang("Increase or decrease volume")], result: "enum", enum: ["Mute", "Absolute", "Relative"]},
        {type: "Label", label: Lang("Mute settings")},
        {type: "Radio", id: "Mute", default: "On", choices: [Lang("Mute on"), Lang("Mute off"), Lang("Toggle")]
            , result: "enum", enum: ["On", "Off", "Toggle"]},
        {type: "Label", label: Lang("Absolute volume")},
        {type: "Slider", id: "volume", default: 80, content: "positiveNumber", AllowExpression: true},
        {type: "Label", label: Lang("Relative volume")},
        {type: "Edit", id: "volumeRelative", default: 10, content: "Number", WarnIfEmpty: true}
    ]

    static GenerateName(ctx, params) {
        switch (TextOps.Par(params, "Action")) {
            case "Mute":
                actionText := Lang("Set mute state")
                mute := TextOps.Par(params, "Mute")
                valueText := Lang(mute = "On" ? "Mute on" : (mute = "Off" ? "Mute off" : "Toggle"))
            case "Absolute":
                actionText := Lang("Set a Specified volume")
                valueText := TextOps.Par(params, "volume")
            default:
                actionText := Lang("Increase or decrease volume")
                valueText := TextOps.Par(params, "volumeRelative")
        }
        return Lang("Set Volume") " - " actionText " - " valueText
    }

    static Run(ctx, params) {
        action := TextOps.Par(params, "Action")
        if (action = "Mute")
            p := ctx.EvalParams(params, ["volume", "volumeRelative"])
        else if (action = "Absolute")
            p := ctx.EvalParams(params, ["Mute", "volumeRelative"])
        else
            p := ctx.EvalParams(params, ["Mute", "volume"])
        try {
            switch action {
                case "Mute":
                    SystemOps.SoundSetMute(p.Mute = "On" ? 1 : (p.Mute = "Off" ? 0 : -1))
                case "Absolute":
                    SystemOps.SoundSetVolume(p.volume)
                default:
                    ; a negative amount is a decrease, a positive one gets "+" (v1: "+" plus the number)
                    amount := p.volumeRelative
                    SystemOps.SoundSetVolume(amount < 0 ? amount : "+" amount)
            }
        } catch {
            throw ElementError(Lang("Volume could not be set"))
        }
        ctx.Finish("normal")
    }
}
