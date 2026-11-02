#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\..\..\core\ElementError.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\ScreenOps.ahk

; Action Get screen settings of the package Default (WI-0127): stores the brightness, the contrast, the red, green and blue
; gain and drive, and the colour temperature of a monitor, with their minimum and maximum where the monitor has them.
; Specification: the help text of v1 (help/en/Actions/Get_Screen_Settings.md). Class ID, parameter IDs and language keys are
; those of v1 (Source_Elements/Default/Actions/Get_Screen_Settings.ahk).
;
; The settings are the DDC/CI settings of the monitor (dxva2, SystemOps.MonitorGetSetting, E0103), as in v1; the resolution,
; the colour depth and the orientation are not settings of v1 and are not read here. A monitor without DDC/CI ends the
; element with an exception that names the setting (v1 text). The name of an output variable that is empty is not set
; (MIGRATION M-0172). The element is experimental, as in v1.
class Action_Get_Screen_Settings extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Experimental"
    static Icon := ""

    ; The settings in the order of the output: the setting of MonitorGetSetting and its channel, the v1 text of the setting,
    ; and the parameter ids of its outputs (current, minimum, maximum) with the default names of v1.
    static Settings := [
        {name: "brightness", channel: 0, label: "Brightness", ids: ["VarnameBrightness", "VarnameBrightnessMin", "VarnameBrightnessMax"], names: ["Brightness", "", ""]},
        {name: "contrast", channel: 0, label: "Contrast", ids: ["VarnameContrast", "VarnameContrastMin", "VarnameContrastMax"], names: ["Contrast", "", ""]},
        {name: "gain", channel: 0, label: "Red gain", ids: ["VarnameRedGain", "VarnameRedGainMin", "VarnameRedGainMax"], names: ["RedGain", "", ""]},
        {name: "gain", channel: 1, label: "Green gain", ids: ["VarnameGreenGain", "VarnameGreenGainMin", "VarnameGreenGainMax"], names: ["GreenGain", "", ""]},
        {name: "gain", channel: 2, label: "Blue gain", ids: ["VarnameBlueGain", "VarnameBlueGainMin", "VarnameBlueGainMax"], names: ["BlueGain", "", ""]},
        {name: "drive", channel: 0, label: "Red drive", ids: ["VarnameReddrive", "VarnameReddriveMin", "VarnameReddriveMax"], names: ["RedDrive", "", ""]},
        {name: "drive", channel: 1, label: "Green drive", ids: ["VarnameGreendrive", "VarnameGreendriveMin", "VarnameGreendriveMax"], names: ["GreenDrive", "", ""]},
        {name: "drive", channel: 2, label: "Blue drive", ids: ["VarnameBluedrive", "VarnameBluedriveMin", "VarnameBluedriveMax"], names: ["BlueDrive", "", ""]}
    ]

    static Name() => Lang("Get Screen Settings")
    static Category() => Lang("image")

    static Parameters(ctx) {
        list := [
            {type: "Label", label: Lang("Which screen")},
            {type: "edit", id: "MonitorNumber", default: 1, content: "PositiveInteger", WarnIfEmpty: true, UseUpDown: true
                , range: "1-" SysGet(80)},
            {type: "Label", label: Lang("Output variables")}
        ]
        for setting in this.Settings {
            list.Push({type: "Label", label: Lang(setting.label) ": " Lang("Current value") " - " Lang("Minimum") " - "
                Lang("Maximum"), size: "small"})
            list.Push({type: "Edit", id: setting.ids, default: setting.names, content: "VariableName"})
        }
        list.Push({type: "Label", label: Lang("Color temperature"), size: "small"})
        list.Push({type: "Edit", id: "VarnameColorTemperature", default: "ColorTemperature", content: "VariableName"})
        return list
    }

    static GenerateName(ctx, params) => Lang("Get Screen Settings")

    static Run(ctx, params) {
        skip := ["VarnameColorTemperature"]
        for setting in this.Settings
            for id in setting.ids
                skip.Push(id)
        p := ctx.EvalParams(params, skip)
        number := p.MonitorNumber
        if (number < 1 || number > SystemOps.MonitorCount())
            throw ElementError(Lang("Screen %1% does not exist", number))
        for setting in this.Settings
            p := this._Store(ctx, p, params, number, setting, setting.ids, setting.label)
        p := this._Store(ctx, p, params, number, {name: "colorTemperature", channel: 0}, ["VarnameColorTemperature"]
            , "Color temperature")
        ctx.Finish("normal")
    }

    ; Reads one setting of the monitor and stores it: the current value, then the minimum and the maximum in their outputs
    ; (an output whose name is empty is not set). Returns the evaluated parameters (the outputs are evaluated here).
    static _Store(ctx, p, params, number, setting, ids, label) {
        try {
            result := SystemOps.MonitorGetSetting(number, setting.name, setting.channel)
        } catch as e {
            throw ElementError(Lang("Couldn't get screen setting: %1%", Lang(label)) ". " e.Message)
        }
        p := ctx.EvalMoreParams(p, params, ids)
        values := [result["current"], result["min"], result["max"]]
        for i, id in ids {
            if (p.%id% != "")
                ctx.SetVar(p.%id%, values[i])
        }
        return p
    }
}
