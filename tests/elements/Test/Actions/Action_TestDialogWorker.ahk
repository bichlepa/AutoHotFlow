#Requires AutoHotkey v2.0
#Include ..\..\..\..\src\elements\base\AhfElement.ahk

; Test element of WI-0051 (E0038): shows one dialog through the indirection Dialogs.* in a worker and exports what the
; provider answered. In the tests the provider is TestDialogProvider, which answers from the script of the test.
;   Kind     MsgBox (default), InputBox, FileSelect, DirSelect or ToolTip
;   Text     the text of the dialog (MsgBox: text, InputBox: prompt, ToolTip: text)
;   Title    the title
;   Options  the options of the AutoHotkey function (MsgBox: "YesNo T2", InputBox: "T2")
;   Tag      names the exports: they are the global variables global_dialog_<Tag>_result and global_dialog_<Tag>_value
; (the engine sets an export where its name says), which the test reads from the variable files.
; Exports "result" (MsgBox: the button, InputBox: the Result, FileSelect and DirSelect: the path, several files joined by
; "|") and "value" (InputBox: the text that was entered). The element finishes "normal"; an error of the dialog (for
; example a dialog with no scripted answer) ends it with "exception".
class Action_TestDialogWorker extends AhfElement {
    static Mode := "worker"
    static Level := "Programmer"
    static Stability := "Experimental"

    static Name() => "Test: show a dialog in a worker"
    static Category() => "Test"

    static Run(ctx, params) {
        kind := params.HasProp("Kind") ? params.Kind : "MsgBox"
        text := params.HasProp("Text") ? params.Text : ""
        title := params.HasProp("Title") ? params.Title : ""
        options := params.HasProp("Options") ? params.Options : ""
        pre := "global_dialog_" (params.HasProp("Tag") ? params.Tag : "x") "_"
        switch kind, "Off" {
            case "MsgBox":
                ctx.Export(pre "result", Dialogs.MsgBox(text, title, options))
            case "InputBox":
                box := Dialogs.InputBox(text, title, options)
                ctx.Export(pre "result", box.Result)
                ctx.Export(pre "value", box.Value)
            case "FileSelect":
                ctx.Export(pre "result", this._Joined(Dialogs.FileSelect(options, "", title)))
            case "DirSelect":
                ctx.Export(pre "result", Dialogs.DirSelect("", 1, text))
            case "ToolTip":
                Dialogs.ToolTip(text)
                ctx.Export(pre "result", "shown")
            default:
                throw ElementError("TestDialogWorker: unknown Kind '" kind "'")
        }
        ctx.Finish("normal")
    }

    static _Joined(value) {
        if (!IsObject(value))
            return value
        out := ""
        for item in value
            out .= (out = "" ? "" : "|") item
        return out
    }
}
