#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include StoragePaths.ahk
#Include AtomicFile.ahk

; Variable files in v1 format (WI-0012, ARCHITECTURE 7, v1 "Global variables.ahk"):
;   global:  Variables/<name>.ahfvd (metadata) and Variables/<name>.ahfvar (content)
;   static:  Variables/<flowId>/<name>.ahfvd and .ahfvar
; Metadata is JSON {"name": ..., "type": "normal" | "object"}. Content of type "object" is JSON text,
; content of type "normal" is the plain value as text. Storage keeps the content text as given (the
; engine serializes objects), so the round trip does not change the value.
class VarFiles {
    static TYPES := Map("normal", true, "object", true)

    ; Path without extension of one variable. Throws bad_payload for a bad scope or name.
    static Stem(dataDir, scope, flowId, name) {
        StoragePaths.CheckName(name, "variable name")
        if (scope = "global")
            return StoragePaths.VarsDir(dataDir) "\" name
        if (scope = "static") {
            StoragePaths.CheckName(flowId, "flow id")
            return StoragePaths.VarsDir(dataDir) "\" flowId "\" name
        }
        throw AhfError("unknown variable scope '" scope "'", ErrCode.BAD_PAYLOAD)
    }

    ; Map(exists, type, content), the payload of the answer (exists is Json.True/Json.False). exists is false
    ; when the metadata file is missing.
    static Get(dataDir, scope, flowId, name) {
        stem := VarFiles.Stem(dataDir, scope, flowId, name)
        if (FileExist(stem ".ahfvd") = "")
            return Map("exists", Json.False)
        meta := ""
        try {
            meta := Json.Parse(AtomicFile.ReadText(stem ".ahfvd"))
        } catch as e {
            throw AhfError("metadata of variable '" name "' is not valid JSON: " e.Message, ErrCode.INTERNAL)
        }
        if (!(meta is Map))
            throw AhfError("metadata of variable '" name "' is not a JSON object", ErrCode.INTERNAL)
        if (FileExist(stem ".ahfvar") = "")
            throw AhfError("content of variable '" name "' is missing", ErrCode.INTERNAL)
        return Map("exists", Json.True, "type", meta.Get("type", "normal")
            , "content", AtomicFile.ReadText(stem ".ahfvar"))
    }

    ; Writes content first, then metadata (each file is replaced atomically). A crash between the two
    ; leaves the new content with the old type; the type is then wrong until the next set.
    static Set(dataDir, scope, flowId, name, varType, content) {
        stem := VarFiles.Stem(dataDir, scope, flowId, name)
        if (!VarFiles.TYPES.Has(varType))
            throw AhfError("unknown variable type '" varType "'", ErrCode.BAD_PAYLOAD)
        text := String(content)
        if (varType = "object") {
            try {
                Json.Parse(text)
            } catch as e {
                throw AhfError("object content is not valid JSON: " e.Message, ErrCode.BAD_PAYLOAD)
            }
            text := AtomicFile.Crlf(text)
        }
        SplitPath(stem, , &dirPath)
        DirCreate(dirPath)
        AtomicFile.Write(stem ".ahfvar", text)
        meta := Json.Stringify(Map("name", name, "type", varType), 2)
        AtomicFile.Write(stem ".ahfvd", AtomicFile.Crlf(meta))
    }

    ; Removes both files. Deleting a variable that does not exist is not an error (existed is false then).
    static Delete(dataDir, scope, flowId, name) {
        stem := VarFiles.Stem(dataDir, scope, flowId, name)
        existed := (FileExist(stem ".ahfvd") != "") || (FileExist(stem ".ahfvar") != "")
        for ext in [".ahfvd", ".ahfvar"] {
            if (FileExist(stem ext) != "")
                FileDelete(stem ext)
        }
        return Map("existed", Json.Bool(existed))
    }

    ; Removes the static variables of one flow: the folder Variables/<flowId>/ with its files (WI-0070, E0066).
    ; Nothing to do when the folder is missing.
    static DeleteFlow(dataDir, flowId) {
        dirPath := StoragePaths.VarsDir(dataDir) "\" StoragePaths.CheckName(flowId, "flow id")
        if (!DirExist(dirPath))
            return Map()
        try {
            DirDelete(dirPath, true)
        } catch as e {
            throw AhfError("cannot delete the static variables of '" flowId "': " e.Message, ErrCode.INTERNAL)
        }
        return Map()
    }

    ; Names of the variables of one scope, sorted. Map("names", Array).
    static List(dataDir, scope, flowId) {
        dirPath := ""
        if (scope = "global")
            dirPath := StoragePaths.VarsDir(dataDir)
        else if (scope = "static")
            dirPath := StoragePaths.VarsDir(dataDir) "\" StoragePaths.CheckName(flowId, "flow id")
        else
            throw AhfError("unknown variable scope '" scope "'", ErrCode.BAD_PAYLOAD)
        names := []
        if (DirExist(dirPath)) {
            pattern := dirPath "\*.ahfvd"
            loop files, pattern
                names.Push(SubStr(A_LoopFileName, 1, -6))
        }
        return Map("names", StoragePaths.SortStrings(names))
    }
}
