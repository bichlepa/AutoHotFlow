#Requires AutoHotkey v2.0
#Include AssistantValues.ahk

; The colour assistant of the element settings (WI-0110, v1 Choose Color): the Windows colour dialog (comdlg32 ChooseColor)
; with the current colour selected. It is modal, as the file dialogs of the UI roles (E0076): the user opened it, and the
; dialog keeps the message handling going (WI-0069, the standard dialogs). The colour under the mouse is the mouse tracker's
; job (MouseAssistant), not this dialog's. Pick is a function property, so that the tests replace the dialog.
class ColorAssistant {
    ; Pick(current, owner): the colour the user chose as 0xRRGGBB text, or "" when the dialog was cancelled.
    ; current: 0xRRGGBB text (the colour the dialog starts with); owner: the window handle of the settings (0 for none).
    static Pick := (current, owner) => ColorAssistant.Dialog(current, owner)

    static Dialog(current, owner) {
        cc := Buffer(9 * A_PtrSize, 0)            ; CHOOSECOLORW
        custom := Buffer(16 * 4, 0)               ; the custom colours (COLORREF each), empty at the start
        NumPut("uint", 9 * A_PtrSize, cc, 0)      ; lStructSize
        NumPut("ptr", owner, cc, A_PtrSize)       ; hwndOwner
        NumPut("uint", AssistantValues.ToColorref(current), cc, 3 * A_PtrSize)   ; rgbResult
        NumPut("ptr", custom.Ptr, cc, 4 * A_PtrSize)                             ; lpCustColors
        NumPut("uint", 0x3, cc, 5 * A_PtrSize)    ; Flags: CC_RGBINIT | CC_FULLOPEN (the colour is set, the full dialog opens)
        ok := DllCall("comdlg32\ChooseColorW", "ptr", cc, "int")
        if (!ok)
            return ""
        return AssistantValues.FromColorref(NumGet(cc, 3 * A_PtrSize, "uint"))
    }
}
