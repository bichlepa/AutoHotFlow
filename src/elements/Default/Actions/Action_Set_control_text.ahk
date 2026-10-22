#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\WindowIdent.ahk
#Include ..\lib\ControlIdent.ahk

; Action Set control text of the package Default (WI-0125): sets the text of a control of a window (ControlSetText), and
; stores the window ID (A_WindowID) and the control ID (A_ControlID). The control is named as in Action_Get_Control_Text.
; Specification: the help text of v1 (help/en/Actions/Set_control_text.md). Class ID, parameter IDs, defaults and language
; keys are those of v1 (Source_Elements/Default/Actions/Set_control_text.ahk).
;
; Worker element (another window). Errors are those of v1 (see Action_Get_Control_Text). The control is changed by its
; window; the focus is not taken.
class Action_Set_control_text extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Set control text")
    static Category() => Lang("Window")

    static Parameters(ctx) {
        list := [
            {type: "Label", label: Lang("Text to set")},
            {type: "Edit", id: "Text", content: "String"}
        ]
        ControlIdent.AddIdentificationParameters(list)
        return list
    }

    static GenerateName(ctx, params) {
        text := params.HasProp("Text") ? params.Text : ""
        return Lang("Set control text") ": " (IsObject(text) ? "" : String(text)) " - " ControlIdent.Name(params)
    }

    static CheckSettings(form, params, staticValues) => ControlIdent.CheckSettings(form, params)

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        found := ControlIdent.Find(p)
        ControlIdent.RequireControl(p, found)
        ControlSetText(p.Text, found["controlID"])
        if (found["windowID"] != 0)
            ctx.SetVar("A_WindowID", found["windowID"], "thread")
        ctx.SetVar("A_ControlID", found["controlID"], "thread")
        ctx.Finish("normal")
    }
}
