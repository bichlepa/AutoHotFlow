#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\ControlIdent.ahk
#Include ..\lib\DialogOps.ahk
#Include ..\lib\TextOps.ahk

; Action Send keystrokes to control of the package Default (WI-0126): sends keys and text to one control of a window
; (ControlSend), without the keyboard focus and without moving the mouse. Specification: the help text of v1
; (help/en/Actions/Send_Keystrokes_To_Control.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Send_Keystrokes_To_Control.ahk).
;
; Worker element (another window). The control is identified as in Action_Set_control_text (lib/ControlIdent.ahk), and
; the errors are the v1 texts. Raw mode sends the text as it is (ControlSendText, the v1 ControlSendRaw). The window ID
; and the control ID are stored as A_WindowID and A_ControlID, as v1 did. ControlSend is not a seam function: it does not
; move the mouse or change the focus, so it runs for real in the tests.
class Action_Send_Keystrokes_To_Control extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := "Keyboard.png"

    static Name() => Lang("Send Keystrokes To Control")
    static Category() => Lang("User simulation") "|" Lang("Window")

    static Parameters(ctx) {
        list := [
            {type: "Label", label: Lang("Keys or text to send")},
            {type: "Checkbox", id: "RawMode", default: 0, label: Lang("Raw mode")},
            {type: "Edit", id: "KeysToSend", content: ["RawString", "String"], contentID: "KeysToSendContentType"
                , contentDefault: "String", WarnIfEmpty: true}
        ]
        ControlIdent.AddIdentificationParameters(list)
        return list
    }

    static GenerateName(ctx, params) => Lang("Send Keystrokes To Control") ": " TextOps.Par(params, "KeysToSend") " - " ControlIdent.Name(params)

    static CheckSettings(form, params, staticValues) => ControlIdent.CheckSettings(form, params)

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        found := ControlIdent.Find(p)
        ControlIdent.RequireControl(p, found)
        keys := String(p.KeysToSend)
        if (DialogOps.Truthy(p.RawMode))
            ControlSendText(keys, found["controlID"])
        else
            ControlSend(keys, found["controlID"])
        if (found["windowID"] != 0)
            ctx.SetVar("A_WindowID", found["windowID"], "thread")
        ctx.SetVar("A_ControlID", found["controlID"], "thread")
        ctx.Finish("normal")
    }
}
