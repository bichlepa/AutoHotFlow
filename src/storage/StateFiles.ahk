#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include AtomicFile.ahk

; FlowState.json (WI-0060, E0057, PROTOCOL 4.6): the enabled state of the triggers, in the data folder. The engine owns
; the content and only asks for the file; storage reads it as text, writes it atomically and renames a broken one.
class StateFiles {
    static FILE_NAME := "FlowState.json"

    static Path(dataDir) => dataDir "\" StateFiles.FILE_NAME

    ; Map(exists, text): exists is Json.False when the file is missing (text is then absent).
    static Read(dataDir) {
        path := StateFiles.Path(dataDir)
        if (FileExist(path) = "")
            return Map("exists", Json.False)
        return Map("exists", Json.True, "text", AtomicFile.ReadText(path))
    }

    ; Replaces the whole file (atomic, CRLF as in the other JSON files of the data folder).
    static Write(dataDir, text) {
        if (IsObject(text))
            throw AhfError("FlowState.json content must be text", ErrCode.BAD_PAYLOAD)
        AtomicFile.Write(StateFiles.Path(dataDir), AtomicFile.Crlf(String(text)))
        return Map()
    }

    ; Renames the file to FlowState.json.broken; an older broken file is replaced. Nothing to do when the file is missing.
    static KeepBroken(dataDir) {
        path := StateFiles.Path(dataDir)
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
