#Requires AutoHotkey v2.0

; The indirection for the dialogs of elements (E0038, WI-0051). An element never calls MsgBox, InputBox, ToolTip, FileSelect
; or DirSelect itself, it calls Dialogs.<name> with the arguments and the return value of the AutoHotkey function of the
; same name. The product uses the real dialogs (Dialogs.Real). The test entry points register a provider with scripted
; answers (Dialogs.UseProvider, tests/integration/helpers/TestDialogProvider.ahk), so a dialog element runs headless.
;
; Only a worker element may show a dialog (ELEMENT-API-V2 section 3, ARCHITECTURE 6.4): the engine never blocks on a
; dialog. This file is only the seam; where an element may call it is decided by the Mode of the element, as before.
;
; A provider is any object with the methods MsgBox, InputBox, ToolTip, FileSelect and DirSelect (same parameters as the
; Dialogs methods). src/ never registers a provider: arch_check.py (rule dialog-seam) forbids Dialogs.UseProvider outside
; this file, so only the test entries can do it.
class Dialogs {
    static provider := ""
    static _realDialogs := ""

    ; Registers the provider of the process. "" restores the real dialogs. Called by test entries only (rule dialog-seam).
    static UseProvider(provider) {
        Dialogs.provider := provider
    }

    ; Returns the string result of MsgBox: "OK", "Cancel", "Yes", "No", "Timeout", ...
    static MsgBox(text := "", title := "", options := "") {
        return Dialogs._Provider().MsgBox(text, title, options)
    }

    ; Returns an object with the properties Value and Result ("OK", "Cancel" or "Timeout") as InputBox does.
    static InputBox(prompt := "", title := "", options := "", defaultText := "") {
        return Dialogs._Provider().InputBox(prompt, title, options, defaultText)
    }

    ; Shows or removes (empty text) a tooltip. Returns nothing.
    static ToolTip(text := "", x?, y?, which := 1) {
        return Dialogs._Provider().ToolTip(text, x?, y?, which)
    }

    ; Returns the chosen file (String), an Array for the multi-select option, or "" when the user cancels.
    static FileSelect(options := "", root := "", title := "", filter := "") {
        return Dialogs._Provider().FileSelect(options, root, title, filter)
    }

    ; Returns the chosen folder, or "" when the user cancels.
    static DirSelect(root := "", options := 1, prompt := "") {
        return Dialogs._Provider().DirSelect(root, options, prompt)
    }

    static _Provider() {
        if (IsObject(Dialogs.provider))
            return Dialogs.provider
        if (!IsObject(Dialogs._realDialogs))
            Dialogs._realDialogs := Dialogs.Real()
        return Dialogs._realDialogs
    }

    ; The real dialogs: the built-in functions, called with the same arguments. The only place in src/elements/ that
    ; may call them (exempt from the arch rules dialog and dialog-seam, tools/arch_check.py).
    class Real {
        MsgBox(text, title, options) {
            return MsgBox(text, title, options)
        }

        InputBox(prompt, title, options, defaultText) {
            return InputBox(prompt, title, options, defaultText)
        }

        ToolTip(text, x?, y?, which := 1) {
            return ToolTip(text, x?, y?, which)
        }

        FileSelect(options, root, title, filter) {
            return FileSelect(options, root, title, filter)
        }

        DirSelect(root, options, prompt) {
            return DirSelect(root, options, prompt)
        }
    }
}
