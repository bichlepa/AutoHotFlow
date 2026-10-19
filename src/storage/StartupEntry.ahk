#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk

; The entry of "Start with Windows" (WI-0079, E0070, REQ-SET-030, PROTOCOL 4.6 cmd.storage.startup.*): the shortcut
; "AutoHotFlow v2.lnk" in the startup folder of the user. The folder comes from the supervisor (the real one only for a
; real start, never in a test, ARCHITECTURE 6.1 item 7). The name differs from the shortcut of v1 ("AutoHotFlow.lnk",
; V1Source), so the two never replace each other and the import of v1 never takes this one for the shortcut of v1.
; Only this one name is ever created, rewritten or deleted.
class StartupEntry {
    static SHORTCUT := "AutoHotFlow v2.lnk"

    ; Map(exists, target, args, workDir) of the shortcut (read only).
    static Check(startupDir) {
        path := StartupEntry._Path(startupDir)
        if (FileExist(path) = "")
            return Map("exists", Json.False, "target", "", "args", "", "workDir", "")
        return StartupEntry._Read(path)
    }

    ; enabled: the shortcut exists with target, args and workDir afterwards (Map(action): created, repaired, unchanged).
    ; Not enabled: it does not exist afterwards (removed, none).
    static Sync(startupDir, enabled, target := "", args := "", workDir := "") {
        path := StartupEntry._Path(startupDir)
        exists := FileExist(path) != ""
        if (!enabled) {
            if (!exists)
                return Map("action", "none")
            try {
                FileDelete(path)
            } catch as e {
                throw AhfError("the shortcut '" path "' cannot be deleted: " e.Message, ErrCode.INTERNAL)
            }
            return Map("action", "removed")
        }
        if (IsObject(target) || IsObject(args) || IsObject(workDir) || target = "")
            throw AhfError("startup entry: target must be a text, args and workDir texts", ErrCode.BAD_PAYLOAD)
        if (exists) {
            cur := StartupEntry._Read(path)
            if (StrLower(cur["target"]) = StrLower(target) && cur["args"] == args
                && StrLower(RTrim(cur["workDir"], "\")) = StrLower(RTrim(workDir, "\")))
                return Map("action", "unchanged")
        }
        try {
            FileCreateShortcut(target, path, workDir, args, "AutoHotFlow")
        } catch as e {
            throw AhfError("the shortcut '" path "' cannot be written: " e.Message, ErrCode.INTERNAL)
        }
        return Map("action", exists ? "repaired" : "created")
    }

    static _Read(path) {
        try {
            FileGetShortcut(path, &target, &dir, &args)
        } catch as e {
            throw AhfError("the shortcut '" path "' cannot be read: " e.Message, ErrCode.INTERNAL)
        }
        return Map("exists", Json.True, "target", target, "args", args, "workDir", dir)
    }

    static _Path(startupDir) {
        text := String(startupDir)
        if (!RegExMatch(text, "^[A-Za-z]:\\") || InStr(text, "`n") || InStr(text, "`r"))
            throw AhfError("the startup folder must be an absolute path", ErrCode.BAD_PAYLOAD)
        if (!DirExist(text))
            throw AhfError("the startup folder '" text "' does not exist", ErrCode.NOT_FOUND)
        return RTrim(text, "\") "\" StartupEntry.SHORTCUT
    }
}
