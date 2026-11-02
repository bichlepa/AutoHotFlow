#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\TextOps.ahk

; Action Input box of the package Default (WI-0128, REQ-ELM-270): asks the user for a text or a number in a window of its
; own (Dialogs.InputWindow, ELEMENT-API-V2 3.3). Specification: the help text of v1 (help/en/Actions/Input_Box.md), the
; parameters, defaults and language keys of v1 (Source_Elements/Default/Actions/Input_Box.ahk). Class ID and parameter IDs
; are those of v1.
;
; Worker element (ARCHITECTURE 2.3): the window blocks until the user answers. The output variable is set to the text for
; OK and to the empty text for every other way of ending. A_UserAction (thread variable) tells the way:
;   ok                     the OK button (normal)
;   timeout                OnTimeout: normal or exception ("Timeout reached"). v1 set "Cancel" here, its help said "timeout";
;                          the help is followed (MIGRATION M-0168)
;   cancel                 the cancel button: IfDismiss: normal or exception ("User cancelled the dialog")
;   close                  the close button or Esc: IfClose: normal or exception ("User closed the dialog")
class Action_Input_Box extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Input_Box")
    static Category() => Lang("User_interaction")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Output variable name")},
        {type: "Edit", id: "Varname", default: "UserInput", content: "VariableName", WarnIfEmpty: true},
        {type: "Label", label: Lang("Title")},
        {type: "Edit", id: "title", default: Lang("Title"), content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Message")},
        {type: "multiLineEdit", id: "message", default: Lang("Please, write something"), content: "String", contentConvertObjects: true},
        {type: "Label", label: Lang("Edit field")},
        {type: "Checkbox", id: "OnlyNumbers", default: 0, label: Lang("Only allow numbers")},
        {type: "Checkbox", id: "MaskUserInput", default: 0, label: Lang("Mask user's input")},
        {type: "Checkbox", id: "MultilineEdit", default: 0, label: Lang("Use a multiline edit field")},
        {type: "Label", label: Lang("Count of lines"), size: "small"},
        {type: "Edit", id: "MultilineEditRows", default: 4, content: "PositiveInteger", WarnIfEmpty: true},
        {type: "Label", label: Lang("Default value"), size: "small"},
        {type: "multiLineEdit", id: "defaultText", default: "", content: "String"},
        {type: "Label", label: Lang("Button Text")},
        {type: "Edit", id: "ButtonLabel", default: Lang("OK"), content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Timeout")},
        {type: "Radio", id: "IsTimeout", default: "NoTimeout", result: "enum"
            , choices: [Lang("No timeout"), Lang("Define timeout")], enum: ["NoTimeout", "Timeout"]},
        {type: "Edit", id: "TimeoutUnits", default: 10, content: "PositiveNumber", WarnIfEmpty: true},
        {type: "Radio", id: "Unit", default: "Seconds", result: "enum"
            , choices: [Lang("Seconds"), Lang("Minutes"), Lang("Hours")], enum: ["Seconds", "Minutes", "Hours"]},
        {type: "Label", label: Lang("Result on timeout"), size: "small"},
        {type: "Radio", id: "OnTimeout", default: "Normal", result: "enum"
            , choices: [Lang("Normal"), Lang("Throw exception")], enum: ["Normal", "Exception"]},
        {type: "Label", label: Lang("Width and height")},
        {type: "Edit", id: ["Width", "Height"], default: [300, 250], content: "PositiveNumber", WarnIfEmpty: true},
        {type: "Label", label: Lang("Cancelling")},
        {type: "Checkbox", id: "ShowCancelButton", default: 0, label: Lang("Show cancel button")},
        {type: "Label", label: Lang("Button Text"), size: "small"},
        {type: "Edit", id: "ButtonLabelCancel", default: Lang("Cancel"), content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Result if cancelled"), size: "small"},
        {type: "Radio", id: "IfDismiss", default: "Exception", result: "enum"
            , choices: [Lang("Normal"), Lang("Throw exception")], enum: ["Normal", "Exception"]},
        {type: "Label", label: Lang("Result if closed"), size: "small"},
        {type: "Radio", id: "IfClose", default: "Exception", result: "enum"
            , choices: [Lang("Normal"), Lang("Throw exception")], enum: ["Normal", "Exception"]}
    ]

    ; "Input box: name - title - message"; a message over 100 characters is cut (v1 Element_GenerateName_Action_Input_Box)
    static GenerateName(ctx, params) {
        message := String(TextOps.Par(params, "message"))
        text := StrLen(message) > 100 ? SubStr(message, 1, 100) " ... " : message
        return Lang("Input_Box") ": " TextOps.Par(params, "Varname") " - " TextOps.Par(params, "title") " - " text
    }

    ; v1 Element_CheckSettings_Action_Input_Box: the fields that do not apply are disabled. Digits only and a mask exclude
    ; each other, and so do a mask and several lines.
    static CheckSettings(form, params, staticValues) {
        only := DialogOps.Truthy(TextOps.Par(params, "OnlyNumbers"))
        mask := DialogOps.Truthy(TextOps.Par(params, "MaskUserInput"))
        multi := DialogOps.Truthy(TextOps.Par(params, "MultilineEdit"))
        timeout := TextOps.Par(params, "IsTimeout") = "Timeout"
        cancel := DialogOps.Truthy(TextOps.Par(params, "ShowCancelButton"))
        form.Disable("MaskUserInput", only || multi)
        form.Disable("OnlyNumbers", mask)
        form.Disable("MultilineEdit", mask)
        form.Disable("MultilineEditRows", !multi)
        form.Disable("TimeoutUnits", !timeout)
        form.Disable("Unit", !timeout)
        form.Disable("OnTimeout", !timeout)
        form.Disable("ButtonLabelCancel", !cancel)
        form.Disable("IfDismiss", !cancel)
    }

    static Run(ctx, params) {
        ; the cancel button text is evaluated only when the button is shown (as v1)
        p := ctx.EvalParams(params, "ButtonLabelCancel")
        showCancel := DialogOps.Truthy(p.ShowCancelButton)
        if (showCancel)
            p := ctx.EvalMoreParams(p, params, "ButtonLabelCancel")
        timeoutMs := (p.IsTimeout = "Timeout") ? DialogOps.TimeoutMs(p.TimeoutUnits, p.Unit) : 0
        mask := DialogOps.Truthy(p.OnlyNumbers) ? "Number" : (DialogOps.Truthy(p.MaskUserInput) ? "Password" : "")
        rows := DialogOps.Truthy(p.MultilineEdit) ? p.MultilineEditRows : 1
        answer := Dialogs.InputWindow(Map("title", p.title, "text", p.message, "default", p.defaultText, "mask", mask
            , "rows", rows, "buttonLabel", p.ButtonLabel, "cancelLabel", showCancel ? p.ButtonLabelCancel : ""
            , "width", p.Width, "height", p.Height, "timeoutMs", timeoutMs))
        switch answer.Result {
            case "OK":
                if (!ctx.SetVar(p.Varname, answer.Value))
                    throw ElementError("The variable '" p.Varname "' could not be set (the reason is in the log).")
                DialogOps.End(ctx, "ok", "normal")
            case "Cancel":
                this._Cleared(ctx, p.Varname, "cancel", p.IfDismiss = "Exception", Lang("User cancelled the dialog"))
            case "Timeout":
                this._Cleared(ctx, p.Varname, "timeout", p.OnTimeout = "Exception", Lang("Timeout reached"))
            default:
                this._Cleared(ctx, p.Varname, "close", p.IfClose = "Exception", Lang("User closed the dialog"))
        }
    }

    ; The output variable becomes empty and the way of the end is set; the element ends with an exception when asked to.
    static _Cleared(ctx, varname, action, asException, message) {
        ctx.SetVar(varname, "")
        DialogOps.End(ctx, action, asException ? "exception" : "normal", message)
    }
}
