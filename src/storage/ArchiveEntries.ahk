#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk

; The layout of an .ahf archive (WI-0081, PROTOCOL 4.6, REQ-SEC-060): what may be extracted. An archive from outside is
; checked by its entry names before anything is written, so a name cannot leave the extraction folder ("../x.json", an
; absolute name, a drive, a backslash, a link name with a component "." or "..") and no other file of the archive is used.
; Allowed: "<key>.json" at the root (a flow); "Variables/", "Variables/<key>/" and "Variables/<key>/<name>.ahfvd|.ahfvar"
; (static variables of the flow <key>). Everything else refuses the whole archive (denied, with the name of the entry).
class ArchiveEntries {
    static BAD_CHARS := '[\\/:*?"<>|\x00-\x1F]'

    ; names: the lines of tar -tf (directories end with "/"). Throws denied for the first entry outside the layout.
    static Check(names) {
        for raw in names {
            name := Trim(raw, " `r`n`t")
            if (name = "")
                continue
            if (!ArchiveEntries.IsAllowed(name))
                throw AhfError("the entry '" name "' is not allowed in an .ahf file, the file is refused", ErrCode.DENIED)
        }
    }

    ; True when the entry name has the allowed layout (see the header).
    static IsAllowed(name) {
        if (InStr(name, "\") || SubStr(name, 1, 1) = "/" || InStr(name, ":"))
            return false
        parts := StrSplit(name, "/")
        ; a trailing "/" gives an empty last part: a directory
        isDir := (parts.Length > 0 && parts[parts.Length] = "")
        if (isDir)
            parts.Pop()
        for part in parts {
            if (part = "" || part = "." || part = ".." || RegExMatch(part, ArchiveEntries.BAD_CHARS))
                return false
        }
        if (parts.Length = 1) {
            if (isDir)
                return parts[1] = "Variables"                        ; "Variables/"
            return RegExMatch(parts[1], "\.json$") && StrLen(parts[1]) > 5   ; "<key>.json"
        }
        if (parts[1] != "Variables")
            return false
        if (parts.Length = 2)
            return isDir                                            ; "Variables/<key>/"
        if (parts.Length = 3)
            return !isDir && RegExMatch(parts[3], "\.ahfv(d|ar)$") && StrLen(parts[3]) > 6   ; "Variables/<key>/<name>.ahfv*"
        return false
    }
}
