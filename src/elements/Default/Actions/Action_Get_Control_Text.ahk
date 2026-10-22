#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk
#Include ..\lib\WindowIdent.ahk
#Include ..\lib\ControlIdent.ahk

; Action Get control text of the package Default (WI-0125): reads the text of a control of a window into the variable
; Varname, and stores the window ID (A_WindowID) and the control ID (A_ControlID). The control is named by its text, its
; class (ClassNN) or its window handle (IdentifyControlBy). Specification: the help text of v1
; (help/en/Actions/Get_Control_Text.md). Class ID, parameter IDs, defaults and language keys are those of v1
; (Source_Elements/Default/Actions/Get_control_text.ahk).
;
; Worker element (another window). Errors are those of v1: a missing window, a missing control, a missing control of the
; window. The identification is in lib/ControlIdent.ahk, shared with Action_Set_control_text.
class Action_Get_Control_Text extends AhfElement {
    static Mode := "worker"
    static ActsOnSystem := true
    static Level := "Beginner"
    static Stability := "Stable"
    static Icon := ""

    static Name() => Lang("Get Control Text")
    static Category() => Lang("Window")

    static Parameters(ctx) {
        list := [
            {type: "Label", label: Lang("Output Variable name")},
            {type: "Edit", id: "Varname", default: "ControlText", content: "VariableName"}
        ]
        ControlIdent.AddIdentificationParameters(list)
        return list
    }

    static GenerateName(ctx, params) => Lang("Get Control Text") ": " ControlIdent.Name(params)

    static CheckSettings(form, params, staticValues) => ControlIdent.CheckSettings(form, params)

    static Run(ctx, params) {
        p := ctx.EvalParams(params)
        found := ControlIdent.Find(p)
        ControlIdent.RequireControl(p, found)
        text := ControlGetText(found["controlID"])
        ctx.SetVar(p.Varname, text)
        if (found["windowID"] != 0)
            ctx.SetVar("A_WindowID", found["windowID"], "thread")
        ctx.SetVar("A_ControlID", found["controlID"], "thread")
        ctx.Finish("normal")
    }
}
