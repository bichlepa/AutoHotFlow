#Requires AutoHotkey v2.0
#Include ..\core\Lang.ahk

; The texts of open windows follow a change of the language (REQ-LNG-010, WI-0069). A window registers every text as a
; Lang key together with the property of the control that shows it; Reload() sets all registered texts again, so no
; window has to be rebuilt. Only keys are stored, never the translated text. The registry is per process and holds
; the controls by their Gui handle (owner) until Forget(owner) removes them.
class UiTexts {
    static _items := []   ; Array of Map("owner", hwnd, "ctl", control, "prop", name, "key", key, "args", Array)

    ; Sets ctl.<prop> to the text of key (with the arguments args*) and keeps the entry for Reload. Returns ctl.
    static Register(owner, ctl, key, prop := "Text", args*) {
        UiTexts._items.Push(Map("owner", owner, "ctl", ctl, "prop", prop, "key", key, "args", args))
        UiTexts._Set(ctl, prop, key, args)
        return ctl
    }

    ; Removes every entry of owner (call it before the window is destroyed).
    static Forget(owner) {
        kept := []
        for item in UiTexts._items {
            if (item["owner"] != owner)
                kept.Push(item)
        }
        UiTexts._items := kept
    }

    ; Reads the texts of LangTable.Code again (the caller has changed it) and sets every registered text. A control that
    ; no longer exists is skipped and its entry is removed.
    static Reload() {
        LangTable.Load()
        kept := []
        for item in UiTexts._items {
            try {
                UiTexts._Set(item["ctl"], item["prop"], item["key"], item["args"])
                kept.Push(item)
            }
        }
        UiTexts._items := kept
    }

    ; Number of entries (of owner, or all when owner is "").
    static Count(owner := "") {
        n := 0
        for item in UiTexts._items {
            if (owner = "" || item["owner"] = owner)
                n++
        }
        return n
    }

    static _Set(ctl, prop, key, args) {
        text := Lang(key, args*)
        ctl.%prop% := text
    }
}
