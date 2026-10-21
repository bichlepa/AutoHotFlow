#Requires AutoHotkey v2.0

; The keys of the editor (WI-0098, REQ-EDT-060, WI-0101, REQ-EDT-080, PROTOCOL 4.11): the key table of the editor window. The
; window gets the keys as WM_KEYDOWN of its own window, never as a hotkey (a hotkey would also catch the keys of other
; windows). A name is the key with "Ctrl+" and "Shift+" in front: "Esc", "Ctrl+A", "Del". The table maps a name to a function
; of the pointer (EditorPointer) and the canvas pixel `at` of the mouse ("" when the mouse is not over the canvas; a paste
; goes there). Ctrl+Z, Ctrl+Y and Ctrl+S are the menu commands of the editor (WI-0102, EditorMenus): the pointer passes them on.
class EditorKeys {
    static TABLE := Map(
        "Esc", (pointer, at) => pointer.Escape(),
        "Ctrl+A", (pointer, at) => pointer.SelectAll(),
        "Ctrl+C", (pointer, at) => pointer.Copy(),
        "Ctrl+X", (pointer, at) => pointer.Cut(),
        "Ctrl+V", (pointer, at) => pointer.Paste(at),
        "Ctrl+Z", (pointer, at) => pointer.Command("undo"),
        "Ctrl+Y", (pointer, at) => pointer.Command("redo"),
        "Ctrl+S", (pointer, at) => pointer.Command("save"),
        "Del", (pointer, at) => pointer.Delete()
    )

    ; The name of a key with its modifiers ("Ctrl+A"). key is "Esc" or one letter (upper case, "a" is taken as "A").
    static Name(key, ctrl := false, shift := false) {
        name := (StrLen(key) = 1) ? StrUpper(key) : key
        if (shift)
            name := "Shift+" name
        if (ctrl)
            name := "Ctrl+" name
        return name
    }

    ; The key of a virtual key code (wParam of WM_KEYDOWN): "Esc", a letter "A" to "Z", or "" for a key the table does not
    ; know yet.
    static KeyOf(vk) {
        if (vk = 0x1B)
            return "Esc"
        if (vk = 0x2E)
            return "Del"
        if (vk >= 0x41 && vk <= 0x5A)
            return Chr(vk)
        return ""
    }

    ; Runs the function of the key name, with the canvas pixel at of the mouse ("" for none). True when the table has the
    ; name (the key is handled).
    static Handle(pointer, name, at := "") {
        if (!EditorKeys.TABLE.Has(name))
            return false
        fn := EditorKeys.TABLE[name]
        fn(pointer, at)
        return true
    }
}
