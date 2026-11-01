#Requires AutoHotkey v2.0
#Include ..\..\base\AhfElement.ahk

; Trigger Clipboard changes of the package Default (WI-0131, REQ-TRG-250): fires whenever the content of the clipboard
; changes. OnClipboardChange runs in the trigger host. Name and category are those of v1
; (Source_Elements/Default/Triggers/Clipboard_Changes.ahk); the trigger has no parameters.
class Trigger_Clipboard_Changes extends AhfElement {
    static Mode := "trigger"
    static ActsOnSystem := false
    static Level := "Beginner"
    static Stability := "Stable"

    static Name() => Lang("Clipboard_Changes")
    static Category() => Lang("Variable")

    static Parameters(ctx) => []

    static GenerateName(ctx, params) => Lang("Clipboard_Changes")

    static CheckSettings(form, params, staticValues) {
    }

    ; Registers the callback for every change of the clipboard. The callback is kept for Disable.
    static Enable(ctx, params) {
        ctx.State.callback := ctx.Guard((*) => ctx.Fire())
        OnClipboardChange(ctx.State.callback)
        return ""
    }

    ; Removes the callback of this arming. Nothing to do when Enable did not get that far.
    static Disable(ctx) {
        if (ctx.State.HasProp("callback"))
            OnClipboardChange(ctx.State.callback, 0)
    }

    ; The thread variables: none (v1 Element_postTrigger_Trigger_Clipboard_Changes sets nothing).
    static TriggerVariables(params, data) => Map()
}
