#Requires AutoHotkey v2.0

; The Windows clipboard of the editor (WI-0101, REQ-EDT-080, E0091): the text of ElementClipboard in a clipboard format that
; AutoHotFlow registers for itself (RegisterClipboardFormatW). No text format is written, so a paste into another program
; gets nothing from a copy of elements. The clipboard is opened only for the time of one copy or one read, with a hidden
; window of this process as its owner (Owner): the clipboard is a lock only for a window. Opened with no window a second
; process could open it at the same time (verified, WI-0101).
;
; Write(text) and Read() never wait: a clipboard that another program holds open gives "busy" at once, and the caller
; (EditorTransfer) retries on its timer, a few times, then tells the user (rule 3 of AGENTS.md: no wait on the message path).
; Write answers "ok", "busy" or "failed"; Read answers Map("state", "ok"|"busy"|"none"|"failed", "text", string).
class WinClipboard {
    static FORMAT_NAME := "AutoHotFlow.Elements"
    static GMEM_MOVEABLE := 0x0002
    static MAX_BYTES := 16 * 1024 * 1024
    static _format := 0
    static _owner := 0

    ; The clipboard format of AutoHotFlow (registered once per process; the same number in every process of the session).
    static Format() {
        if (WinClipboard._format = 0)
            WinClipboard._format := DllCall("user32\RegisterClipboardFormatW", "wstr", WinClipboard.FORMAT_NAME, "uint")
        return WinClipboard._format
    }

    ; The window that owns the clipboard while it is open: a hidden static control of this process, made at the first use
    ; (0 when it cannot be made: the clipboard is then opened with no owner).
    static Owner() {
        if (WinClipboard._owner = 0)
            WinClipboard._owner := DllCall("user32\CreateWindowExW", "uint", 0, "wstr", "Static", "wstr", "AutoHotFlow"
                , "uint", 0, "int", 0, "int", 0, "int", 0, "int", 0, "ptr", 0, "ptr", 0, "ptr", 0, "ptr", 0, "ptr")
        return WinClipboard._owner
    }

    ; The text (UTF-8, with its terminating null) becomes the content of the clipboard in our format.
    static Write(text) {
        fmt := WinClipboard.Format()
        if (fmt = 0)
            return "failed"
        size := StrPut(text, "UTF-8")
        buf := Buffer(size)
        StrPut(text, buf, "UTF-8")
        if (!DllCall("user32\OpenClipboard", "ptr", WinClipboard.Owner(), "int"))
            return "busy"
        result := "failed"
        try {
            if (DllCall("user32\EmptyClipboard", "int")) {
                h := DllCall("kernel32\GlobalAlloc", "uint", WinClipboard.GMEM_MOVEABLE, "uptr", size, "ptr")
                if (h) {
                    p := DllCall("kernel32\GlobalLock", "ptr", h, "ptr")
                    if (p) {
                        DllCall("RtlMoveMemory", "ptr", p, "ptr", buf, "uptr", size)
                        DllCall("kernel32\GlobalUnlock", "ptr", h)
                        if (DllCall("user32\SetClipboardData", "uint", fmt, "ptr", h, "ptr")) {
                            result := "ok"
                            h := 0                     ; the system owns the memory now
                        }
                    }
                    if (h)
                        DllCall("kernel32\GlobalFree", "ptr", h, "ptr")
                }
            }
        } finally {
            DllCall("user32\CloseClipboard")
        }
        return result
    }

    ; The text of our format, or state "none" when the clipboard holds no content of it.
    static Read() {
        fmt := WinClipboard.Format()
        if (fmt = 0 || !DllCall("user32\IsClipboardFormatAvailable", "uint", fmt, "int"))
            return Map("state", "none", "text", "")
        if (!DllCall("user32\OpenClipboard", "ptr", WinClipboard.Owner(), "int"))
            return Map("state", "busy", "text", "")
        try {
            h := DllCall("user32\GetClipboardData", "uint", fmt, "ptr")
            if (!h)
                return Map("state", "failed", "text", "")
            size := DllCall("kernel32\GlobalSize", "ptr", h, "uptr")
            if (size = 0 || size > WinClipboard.MAX_BYTES)
                return Map("state", "failed", "text", "")
            p := DllCall("kernel32\GlobalLock", "ptr", h, "ptr")
            if (!p)
                return Map("state", "failed", "text", "")
            try {
                ; two zero bytes after the content: the text ends even when the content has no terminator
                buf := Buffer(size + 2, 0)
                DllCall("RtlMoveMemory", "ptr", buf, "ptr", p, "uptr", size)
            } finally {
                DllCall("kernel32\GlobalUnlock", "ptr", h)
            }
            return Map("state", "ok", "text", StrGet(buf, "UTF-8"))
        } finally {
            DllCall("user32\CloseClipboard")
        }
    }
}
