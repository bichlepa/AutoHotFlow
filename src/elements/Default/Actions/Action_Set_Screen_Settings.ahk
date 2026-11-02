#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\..\..\core\ElementError.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\ScreenOps.ahk
#Include ..\lib\TextOps.ahk

; Action Set screen settings of the package Default (WI-0127): changes the brightness, the contrast, the gains and drives
; of the red, green and blue channel, and the colour temperature of one monitor or of all monitors. Specification: the help
; text of v1 (help/en/Actions/Set_Screen_Settings.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Set_Screen_Settings.ahk), except the name of the colour temperature 11500 K (M-0173).
;
; Worker element that changes the monitor, so it goes through SystemOps (E0103): MonitorSetSetting is the DDC/CI call of
; the monitor (MonitorDdc.ahk). A monitor without DDC/CI, or a value that the monitor refuses, ends the element with an
; exception that names the setting (v1 text). The monitors are changed one after the other; a failure leaves the earlier
; ones changed, as in v1.
class Action_Set_Screen_Settings extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Experimental"
    static Icon := ""

    ; The settings in the order of the dialog: the flag that switches it on, the parameter with its value, the call of
    ; SystemOps.MonitorSetSetting (name, channel) and the v1 text of the setting.
    static Settings := [
        {flag: "WhetherChangeBrightness", id: "brightness", name: "brightness", channel: 0, label: "Brightness"},
        {flag: "WhetherChangeContrast", id: "contrast", name: "contrast", channel: 0, label: "Contrast"},
        {flag: "WhetherSetRedGain", id: "RedGain", name: "gain", channel: 0, label: "Red gain"},
        {flag: "WhetherSetGreenGain", id: "GreenGain", name: "gain", channel: 1, label: "Green gain"},
        {flag: "WhetherSetBlueGain", id: "BlueGain", name: "gain", channel: 2, label: "Blue gain"},
        {flag: "WhetherSetRedDrive", id: "RedDrive", name: "drive", channel: 0, label: "Red drive"},
        {flag: "WhetherSetGreenDrive", id: "GreenDrive", name: "drive", channel: 1, label: "Green drive"},
        {flag: "WhetherSetBlueDrive", id: "BlueDrive", name: "drive", channel: 2, label: "Blue drive"},
        {flag: "WhetherChangeColorTemperature", id: "ColorTemperature", name: "colorTemperature", channel: 0
            , label: "Color temperature"}
    ]

    static Name() => Lang("Set Screen Settings")
    static Category() => Lang("image")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Which monitor")},
        {type: "Checkbox", id: "AllMonitors", default: 0, label: Lang("All monitors")},
        {type: "edit", id: "MonitorNumber", default: 1, content: "positiveInteger", WarnIfEmpty: true, UseUpDown: true
            , range: "1-" SysGet(80)},
        {type: "Label", label: Lang("Brightness")},
        {type: "Checkbox", id: "WhetherChangeBrightness", default: 1, label: Lang("Change brightness")},
        {type: "Slider", id: "brightness", default: 100, content: "positiveNumber", AllowExpression: true},
        {type: "Label", label: Lang("Contrast")},
        {type: "Checkbox", id: "WhetherChangeContrast", default: 0, label: Lang("Change contrast")},
        {type: "Slider", id: "contrast", default: 50, content: "positiveNumber", AllowExpression: true},
        {type: "Label", label: Lang("Color gain")},
        {type: "Checkbox", id: "WhetherSetRedGain", default: 0, label: Lang("Change red gain value")},
        {type: "Slider", id: "RedGain", default: 128, content: "positiveNumber", AllowExpression: true},
        {type: "Checkbox", id: "WhetherSetGreenGain", default: 0, label: Lang("Change green gain value")},
        {type: "Slider", id: "GreenGain", default: 128, content: "positiveNumber", AllowExpression: true},
        {type: "Checkbox", id: "WhetherSetBlueGain", default: 0, label: Lang("Change blue gain value")},
        {type: "Slider", id: "BlueGain", default: 128, content: "positiveNumber", AllowExpression: true},
        {type: "Label", label: Lang("Color drive")},
        {type: "Checkbox", id: "WhetherSetRedDrive", default: 0, label: Lang("Change red drive value")},
        {type: "Slider", id: "RedDrive", default: 128, content: "positiveNumber", AllowExpression: true},
        {type: "Checkbox", id: "WhetherSetGreenDrive", default: 0, label: Lang("Change green drive value")},
        {type: "Slider", id: "GreenDrive", default: 128, content: "positiveNumber", AllowExpression: true},
        {type: "Checkbox", id: "WhetherSetBlueDrive", default: 0, label: Lang("Change blue drive value")},
        {type: "Slider", id: "BlueDrive", default: 128, content: "positiveNumber", AllowExpression: true},
        {type: "Label", label: Lang("Color temperature")},
        {type: "Checkbox", id: "WhetherChangeColorTemperature", default: 0, label: Lang("Change color temperature")},
        {type: "DropDown", id: "ColorTemperature", default: 1, result: "number"
            , choices: ["4000 K.", "5000 K.", "6500 K.", "7500 K.", "8200 K.", "9300 K.", "10000 K.", "11500 K."]}
    ]

    static GenerateName(ctx, params) => Lang("Set Screen Settings")

    static CheckSettings(form, params, staticValues) {
        form.Enable("MonitorNumber", !DialogOps.Truthy(TextOps.Par(params, "AllMonitors")))
        for setting in this.Settings
            form.Enable(setting.id, DialogOps.Truthy(TextOps.Par(params, setting.flag)))
    }

    static Run(ctx, params) {
        skip := []
        for setting in this.Settings
            skip.Push(setting.id)
        skip.Push("MonitorNumber")
        p := ctx.EvalParams(params, skip)
        all := DialogOps.Truthy(p.AllMonitors)
        ; the values of the settings that are switched on, evaluated now (a value that is no number ends the element)
        chosen := []
        for setting in this.Settings {
            if (DialogOps.Truthy(TextOps.Par(params, setting.flag))) {
                p := ctx.EvalMoreParams(p, params, [setting.id])
                chosen.Push(setting)
            }
        }
        if (!all)
            p := ctx.EvalMoreParams(p, params, ["MonitorNumber"])
        count := SystemOps.MonitorCount()
        monitors := []
        if (all) {
            loop count
                monitors.Push(A_Index)
        } else {
            if (p.MonitorNumber < 1 || p.MonitorNumber > count)
                throw ElementError(Lang("Screen %1% does not exist", p.MonitorNumber))
            monitors.Push(p.MonitorNumber)
        }
        for number in monitors {
            for setting in chosen {
                id := setting.id
                value := Integer(p.%id%)
                try {
                    SystemOps.MonitorSetSetting(number, setting.name, value, setting.channel)
                } catch as e {
                    throw ElementError(Lang("Couldn't set screen setting: %1%", Lang(setting.label)) ". " e.Message)
                }
            }
        }
        ctx.Finish("normal")
    }
}
