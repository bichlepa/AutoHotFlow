#Requires AutoHotkey v2.0

; The file and folder dialogs of the UI roles (E0076). The only place in manager/, editor/ and ui_common/ that calls
; FileSelect and DirSelect (arch_check.py, rule dialog-seam).
;
; Allowed here, and only in a UI role, because the user opened the dialog and waits for it. The message handling of the
; role keeps going while the dialog is open (pings are answered, HOW-TO gui-and-hotkeys), but the timers of the role
; stall for up to 0.7 s and the calling thread waits for the answer. So: call it from a click handler, never from a
; handler of a message or a timer that others wait for, and keep no state that must change while it is open.
;
; owner is the handle of the window the dialog belongs to (0 for none). An owned dialog keeps that window from being
; used while it is open (+OwnDialogs). The arguments and the return values are those of FileSelect and DirSelect:
; File returns the chosen file (String), an Array with the multi-select option, or "" when the user cancels; Dir
; returns the chosen folder or "".
;
; The test entries of a UI role register a provider with scripted answers (UseProvider; an object with the methods
; FileSelect and DirSelect, e.g. TestDialogProvider), so a flow through the dialog runs headless. src/ never registers one.
class UiFileDialogs {
    static provider := ""
    static _real := ""

    ; Registers the provider of the process. "" restores the real dialogs. Called by test entries only (rule dialog-seam).
    static UseProvider(provider) {
        UiFileDialogs.provider := provider
    }

    static File(owner := 0, options := "", root := "", title := "", filter := "") {
        UiFileDialogs._Own(owner)
        return UiFileDialogs._Provider().FileSelect(options, root, title, filter)
    }

    static Dir(owner := 0, root := "", options := 1, prompt := "") {
        UiFileDialogs._Own(owner)
        return UiFileDialogs._Provider().DirSelect(root, options, prompt)
    }

    ; Makes the dialog of the next call belong to the owner window. A handle that is not a Gui of this script is ignored.
    static _Own(owner) {
        if (!owner)
            return
        try {
            GuiFromHwnd(owner).Opt("+OwnDialogs")
        } catch {
            ; best effort: the dialog is then simply not owned
        }
    }

    static _Provider() {
        if (IsObject(UiFileDialogs.provider))
            return UiFileDialogs.provider
        if (!IsObject(UiFileDialogs._real))
            UiFileDialogs._real := UiFileDialogs.Real()
        return UiFileDialogs._real
    }

    class Real {
        FileSelect(options, root, title, filter) {
            return FileSelect(options, root, title, filter)
        }

        DirSelect(root, options, prompt) {
            return DirSelect(root, options, prompt)
        }
    }
}
