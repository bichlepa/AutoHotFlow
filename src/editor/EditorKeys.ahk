#Requires AutoHotkey v2.0

; The keys of the editor (WI-0098, REQ-EDT-060, PROTOCOL 4.11): the key table of the editor window. The window gets the keys as
; WM_KEYDOWN of its own window, never as a hotkey (a hotkey would also catch the keys of other windows). A name is the key
; with "Ctrl+" and "Shift+" in front: "Esc", "Ctrl+A". The table maps a name to a function of the pointer (EditorPointer);
; the packages that come later add their keys here (WI-0099 to WI-0101, the menus WI-0102).
class EditorKeys {
    static TABLE := Map(
        "Esc", (pointer) => pointer.Escape(),
        "Ctrl+A", (pointer) => pointer.SelectAll()
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
        if (vk >= 0x41 && vk <= 0x5A)
            return Chr(vk)
        return ""
    }

    ; Runs the function of the key name. True when the table has the name (the key is handled).
    static Handle(pointer, name) {
        if (!EditorKeys.TABLE.Has(name))
            return false
        fn := EditorKeys.TABLE[name]
        fn(pointer)
        return true
    }
}
