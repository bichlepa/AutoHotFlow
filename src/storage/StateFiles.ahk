#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include AtomicFile.ahk
#Include StoragePaths.ahk

; FlowStates/<flowId>.json (WI-0060, E0057, E0063, PROTOCOL 4.6): the enabled triggers of one flow, in the data folder.
; The engine owns the content and only asks for the file; storage reads it as text, writes it atomically and renames a
; broken one. One file per flow: a file that cannot be read affects that flow only.
class StateFiles {
    static EXT := ".json"

    ; Absolute path of the state file of one flow. The flow ID is a flow file name: StoragePaths checks it.
    static Path(dataDir, flowId) => StoragePaths.StatesDir(dataDir) "\" StoragePaths.CheckName(flowId, "flow ID") StateFiles.EXT

    ; Map(exists, text): exists is Json.False when the file is missing (text is then absent).
    static Read(dataDir, flowId) {
        path := StateFiles.Path(dataDir, flowId)
        if (FileExist(path) = "")
            return Map("exists", Json.False)
        return Map("exists", Json.True, "text", AtomicFile.ReadText(path))
    }

    ; Replaces the whole file of one flow (atomic, CRLF as in the other JSON files of the data folder).
    static Write(dataDir, flowId, text) {
        if (IsObject(text))
            throw AhfError("FlowStates content must be text", ErrCode.BAD_PAYLOAD)
        path := StateFiles.Path(dataDir, flowId)
        DirCreate(StoragePaths.StatesDir(dataDir))
        AtomicFile.Write(path, AtomicFile.Crlf(String(text)))
        return Map()
    }

    ; Renames the file to <flowId>.json.broken; an older broken file is replaced. Nothing to do when the file is missing.
    static KeepBroken(dataDir, flowId) {
        path := StateFiles.Path(dataDir, flowId)
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
