#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include AtomicFile.ahk
#Include StoragePaths.ahk

; Settings.json in the data folder (WI-0077, PROTOCOL 4.6): the global settings. The engine owns the runtime copy and checks
; the content (SettingsModel.ahk) and only asks for the file; storage reads it as text, writes it atomically and renames a broken
; one. The file is one document, so a read or a write is one queue operation.
class SettingsFile {
    static FILE := "Settings.json"

    static Path(dataDir) => dataDir "\" SettingsFile.FILE

    ; Map(exists, text): exists is Json.False when the file is missing (text is then absent).
    static Read(dataDir) {
        path := SettingsFile.Path(dataDir)
        if (FileExist(path) = "")
            return Map("exists", Json.False)
        return Map("exists", Json.True, "text", AtomicFile.ReadText(path))
    }

    ; Replaces the whole file (atomic, CRLF as in the other JSON files of the data folder).
    static Write(dataDir, text) {
        if (IsObject(text))
            throw AhfError("Settings content must be text", ErrCode.BAD_PAYLOAD)
        AtomicFile.Write(SettingsFile.Path(dataDir), AtomicFile.Crlf(String(text)))
        return Map()
    }

    ; Renames the file to Settings.json.broken; an older broken file is replaced. Nothing to do when the file is missing.
    static KeepBroken(dataDir) {
        path := SettingsFile.Path(dataDir)
        if (FileExist(path) = "")
            return Map()
        try {
            FileMove(path, path ".broken", true)
        } catch as e {
            throw AhfError("cannot keep '" path "' as broken: " e.Message, ErrCode.INTERNAL)
        }
        return Map()
    }
}
