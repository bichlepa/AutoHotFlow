#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include AtomicFile.ahk
#Include StoragePaths.ahk

; Categories.json in the data folder (WI-0071, E0067, PROTOCOL 4.6): the categories and the order of the flow list. The
; engine owns the content and only asks for the file; storage reads it as text, writes it atomically and renames a broken
; one. The file is one document, so a read or a write is one queue operation.
class CategoryFile {
    static FILE := "Categories.json"

    static Path(dataDir) => dataDir "\" CategoryFile.FILE

    ; Map(exists, text): exists is Json.False when the file is missing (text is then absent).
    static Read(dataDir) {
        path := CategoryFile.Path(dataDir)
        if (FileExist(path) = "")
            return Map("exists", Json.False)
        return Map("exists", Json.True, "text", AtomicFile.ReadText(path))
    }

    ; Replaces the whole file (atomic, CRLF as in the other JSON files of the data folder).
    static Write(dataDir, text) {
        if (IsObject(text))
            throw AhfError("Categories content must be text", ErrCode.BAD_PAYLOAD)
        AtomicFile.Write(CategoryFile.Path(dataDir), AtomicFile.Crlf(String(text)))
        return Map()
    }

    ; Renames the file to Categories.json.broken; an older broken file is replaced. Nothing to do when the file is missing.
    static KeepBroken(dataDir) {
        path := CategoryFile.Path(dataDir)
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
