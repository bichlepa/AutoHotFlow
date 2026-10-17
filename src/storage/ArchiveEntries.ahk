#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\ErrCode.ahk

; The layout and the limits of an .ahf archive (WI-0081, PROTOCOL 4.6, REQ-SEC-060). An archive from outside is checked from
; its listing (tar -tvf) before anything is written, so a name cannot leave the extraction folder ("../x.json", an absolute
; name, a drive, a backslash, a component "." or "..") and no other file of the archive is used. Allowed: "<key>.json" at the
; root (a flow); "Variables/", "Variables/<key>/" and "Variables/<key>/<name>.ahfvd|.ahfvar" (static variables of the flow
; <key>). A link or a device is refused. Limits (zip bombs): the file itself (MAX_FILE_BYTES), the number of entries
; (MAX_ENTRIES) and the sum of the sizes of the entries (MAX_UNPACKED_BYTES; the unpack answer must fit one protocol frame,
; 16 MB, with the escaped JSON text). Every refusal names the entry or the limit.
class ArchiveEntries {
    static BAD_CHARS := '[\\/:*?"<>|\x00-\x1F]'
    static MAX_FILE_BYTES := 50 * 1024 * 1024
    static MAX_ENTRIES := 2000
    static MAX_UNPACKED_BYTES := 4 * 1024 * 1024

    ; text: the output of tar -tvf (one line per entry). Throws denied for an entry outside the layout or a limit, and
    ; bad_payload for a line that is not a listing (the file is then not an archive that tar can list).
    static CheckListing(text) {
        count := 0
        total := 0
        for raw in StrSplit(text, "`n", "`r") {
            line := Trim(raw, " `t")
            if (line = "")
                continue
            count += 1
            if (count > ArchiveEntries.MAX_ENTRIES)
                throw AhfError("the archive has more than " ArchiveEntries.MAX_ENTRIES " entries, the file is refused",
                    ErrCode.DENIED)
            if (!RegExMatch(line, "^([-dl])\S*\s+\d+\s+\d+\s+\d+\s+(\d+)\s+\S+\s+\d+\s+\S+\s+(.+)$", &m))
                throw AhfError("the listing of the archive has a line that is not an entry: " line, ErrCode.BAD_PAYLOAD)
            if (m[1] = "l")
                throw AhfError("a link in the archive is not allowed, the file is refused", ErrCode.DENIED)
            if (m[1] != "-" && m[1] != "d")
                throw AhfError("an entry of this type is not allowed in an .ahf file, the file is refused", ErrCode.DENIED)
            total += Integer(m[2])
            if (total > ArchiveEntries.MAX_UNPACKED_BYTES)
                throw AhfError("the entries of the archive are larger than " ArchiveEntries.MAX_UNPACKED_BYTES
                    " bytes unpacked, the file is refused", ErrCode.DENIED)
            if (!ArchiveEntries.IsAllowed(m[3]))
                throw AhfError("the entry '" m[3] "' is not allowed in an .ahf file, the file is refused", ErrCode.DENIED)
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
