#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\DialogOps.ahk

; Action Message box of the package Default (WI-0056, REQ-ELM-270): shows a window with a message and an OK button,
; optionally a cancel button and a timeout. Specification: the help text of v1 (help/en/Actions/Message_Box.html), the
; parameters, defaults and language keys of v1 (Source_Elements/Default/Actions/Message_Box.ahk).
;
; Worker element (ARCHITECTURE 2.3): the window blocks until the user answers, so it runs in a worker. The results:
;   OK                     normal, the variable A_UserAction is "ok"
;   timeout                OnTimeout: normal or exception ("Timeout reached"); A_UserAction "timeout"
;   cancel button          IfDismiss: normal or exception ("User cancelled the dialog"); A_UserAction "cancel"
;   close button or Esc    IfClose: normal or exception ("User closed the dialog"); A_UserAction "close"
; The window is not stopped by a stop of the instance: the worker ends with it (ARCHITECTURE 6.4).
class Action_Message_Box extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Message_Box")
    static Category() => Lang("User_interaction")

    static Parameters(ctx) => [
        {type: "Label", label: Lang("Title")},
        {type: "Edit", id: "title", default: Lang("Title"), content: "String"},
        {type: "Label", label: Lang("Message")},
        {type: "multiLineEdit", id: "message", default: Lang("Message"), content: "String", contentConvertObjects: true},
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
            , choices: [Lang("Normal") " - " Lang("Make output variable empty"), Lang("Throw exception")]
            , enum: ["Normal", "Exception"]},
        {type: "Label", label: Lang("Width and height")},
        {type: "Edit", id: ["Width", "Height"], default: [300, 200], content: "PositiveNumber", WarnIfEmpty: true},
        {type: "Label", label: Lang("Cancelling")},
        {type: "Checkbox", id: "ShowCancelButton", default: 0, label: Lang("Show cancel button")},
        {type: "Label", label: Lang("Button text"), size: "small"},
        {type: "Edit", id: "ButtonLabelCancel", default: Lang("Cancel"), content: "String", WarnIfEmpty: true},
        {type: "Label", label: Lang("Result if cancelled"), size: "small"},
        {type: "Radio", id: "IfDismiss", default: "Exception", result: "enum"
            , choices: [Lang("Normal"), Lang("Throw exception")], enum: ["Normal", "Exception"]},
        {type: "Label", label: Lang("Result if closed"), size: "small"},
        {type: "Radio", id: "IfClose", default: "Exception", result: "enum"
            , choices: [Lang("Normal"), Lang("Throw exception")], enum: ["Normal", "Exception"]}
    ]

    ; "Message box - title - message" (v1 Element_GenerateName_Action_Message_Box)
    static GenerateName(ctx, params) {
        title := params.HasProp("title") ? params.title : ""
        message := params.HasProp("message") ? params.message : ""
        return Lang("Message_Box") " - " title " - " message
    }

    static Run(ctx, params) {
        p := ctx.EvalParams(params)           ; throws on error -> result "exception"
        buttons := [Map("id", "ok", "label", p.ButtonLabel)]
        if (DialogOps.Truthy(p.ShowCancelButton))
            buttons.Push(Map("id", "cancel", "label", p.ButtonLabelCancel))
        timeoutMs := (p.IsTimeout = "Timeout") ? DialogOps.TimeoutMs(p.TimeoutUnits, p.Unit) : 0
        answer := Dialogs.Window(Map("title", p.title, "text", p.message, "buttons", buttons, "width", p.Width
            , "height", p.Height, "timeoutMs", timeoutMs, "defaultId", "ok"))
        switch answer {
            case "ok":
                this._End(ctx, "ok", "normal")
            case "timeout":
                this._End(ctx, "timeout", p.OnTimeout = "Exception" ? "exception" : "normal", "Timeout reached")
            case "cancel":
                this._End(ctx, "cancel", p.IfDismiss = "Exception" ? "exception" : "normal", "User cancelled the dialog")
            default:
                this._End(ctx, "close", p.IfClose = "Exception" ? "exception" : "normal", "User closed the dialog")
        }
    }

    ; Sets A_UserAction (thread variable) and ends the element: with result "exception" and the message, or "normal".
    static _End(ctx, action, result, message := "") {
        ctx.SetVar("A_UserAction", action, "thread")
        if (result = "exception")
            throw ElementError(message)
        ctx.Finish("normal")
    }
}
