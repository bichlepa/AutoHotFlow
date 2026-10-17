#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk

; Condition Confirmation dialog of the package Default (WI-0056, REQ-ELM-270): asks the user a question in a window
; with the buttons Yes and No (and optionally Cancel); the outputs are "yes" and "no". Specification: the help text of v1
; (help/en/Conditions/Confirmation_Dialog.html), the parameters, defaults and language keys of v1
; (Source_Elements/Default/Conditions/Confirmation_Dialog.ahk).
;
; Worker element (ARCHITECTURE 2.3). Results:
;   Yes or No button       yes or no
;   timeout                OnTimeout: yes, no or exception ("Timeout reached")
;   cancel button, close   IfDismiss: yes, no or exception ("User cancelled the dialog" / "User closed the dialog")
class Condition_Confirmation_Dialog extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Confirmation_Dialog")
    static Category() => Lang("User_interaction")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Title")},
        {type: "Edit", id: "title", default: Lang("Title"), content: "String"},
        {type: "Label", label: Lang("Message")},
        {type: "multiLineEdit", id: "message", default: Lang("Message"), content: "String", contentConvertObjects: true},
        {type: "Label", label: Lang("Button Text")},
        {type: "Label", label: Lang("Button '%1%'", Lang("Yes")), size: "small"},
        {type: "Edit", id: "ButtonLabelYes", default: Lang("Yes"), content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Button '%1%'", Lang("No")), size: "small"},
        {type: "Edit", id: "ButtonLabelNo", default: Lang("No"), content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Timeout")},
        {type: "Checkbox", id: "IsTimeout", default: 0, label: Lang("Timeout enabled")},
        {type: "Edit", id: "TimeoutUnits", default: 10, content: "Expression", WarnIfEmpty: true},
        {type: "Radio", id: "Unit", default: "Seconds", result: "enum"
            , choices: [Lang("Seconds"), Lang("Minutes"), Lang("Hours")], enum: ["Seconds", "Minutes", "Hours"]},
        {type: "Label", label: Lang("Result on timeout"), size: "small"},
        {type: "Radio", id: "OnTimeout", default: "Exception", result: "enum"
            , choices: [Lang("Yes"), Lang("No"), Lang("Throw exception")], enum: ["Yes", "No", "Exception"]},
        {type: "Label", label: Lang("Width and height")},
        {type: "Edit", id: ["Width", "Height"], default: [300, 200], content: "Expression", WarnIfEmpty: true},
        {type: "Label", label: Lang("Cancelling")},
        {type: "Checkbox", id: "ShowCancelButton", default: 0, label: Lang("Show cancel button")},
        {type: "Label", label: Lang("Button text"), size: "small"},
        {type: "Edit", id: "ButtonLabelCancel", default: Lang("Cancel"), content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Result if cancelled"), size: "small"},
        {type: "Radio", id: "IfDismiss", default: "Exception", result: "enum"
            , choices: [Lang("Yes"), Lang("No"), Lang("Throw exception")], enum: ["Yes", "No", "Exception"]},
        {type: "Label", label: Lang("Default Button")},
        {type: "Radio", id: "DefaultButton", default: "No", result: "enum"
            , choices: [Lang("Yes"), Lang("No"), Lang("Cancel")], enum: ["Yes", "No", "Cancel"]}
    ]

    ; "Confirmation dialog" and the title and message (v1 Element_GenerateName_Condition_Confirmation_Dialog)
    static GenerateName(ctx, params) {
        title := params.HasProp("title") ? params.title : ""
        message := params.HasProp("message") ? params.message : ""
        return Lang("Confirmation_Dialog") "`n" title ", " message
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)           ; throws on error -> result "exception"
        buttons := [Map("id", "yes", "label", p.ButtonLabelYes), Map("id", "no", "label", p.ButtonLabelNo)]
        showCancel := DialogOps.Truthy(p.ShowCancelButton)
        if (showCancel)
            buttons.Push(Map("id", "cancel", "label", p.ButtonLabelCancel))
        defaultId := StrLower(p.DefaultButton)
        if (defaultId = "cancel" && !showCancel)
            defaultId := "no"
        timeoutMs := DialogOps.Truthy(p.IsTimeout) ? DialogOps.TimeoutMs(p.TimeoutUnits, p.Unit) : 0
        answer := Dialogs.Window(Map("title", p.title, "text", p.message, "buttons", buttons, "width", p.Width
            , "height", p.Height, "timeoutMs", timeoutMs, "defaultId", defaultId))
        switch answer {
            case "yes", "no":
                ctx.Finish(answer)
            case "timeout":
                this._Result(ctx, p.OnTimeout, "Timeout reached")
            default:
                this._Result(ctx, p.IfDismiss, answer = "cancel" ? "User cancelled the dialog" : "User closed the dialog")
        }
    }

    ; The result for a choice of the parameter (Yes, No or Exception); Exception ends the element with the message.
    static _Result(ctx, choice, message) {
        if (choice = "Exception")
            throw ElementError(message)
        ctx.Finish(StrLower(choice))
    }
}
