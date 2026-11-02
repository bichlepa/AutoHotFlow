#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk

; The shortcut files of the trigger "Shortcut" (WI-0133, REQ-TRG-240, PROTOCOL 4.6 cmd.storage.shortcut.*). The trigger host
; has no file access (rule file-io, ARCHITECTURE 2.3), so it asks storage. Only a path that is absolute and ends with .lnk
; is written or removed, and the folder of the shortcut must exist: nothing else in the file system is touched.
class ShortcutFile {
    ; Creates or replaces the shortcut at path. Returns Map(action): created (new), repaired (an old one with other
    ; target, arguments or working folder was replaced) or unchanged. Throws AhfError for a bad path or a failed write.
    static Write(path, target, args, workDir) {
        ShortcutFile._CheckPath(path)
        if (IsObject(target) || IsObject(args) || IsObject(workDir) || target = "")
            throw AhfError("shortcut: target must be a text, args and workDir texts", ErrCode.BAD_PAYLOAD)
        dirName := SubStr(path, 1, InStr(path, "\", , -1) - 1)
        if (!DirExist(dirName))
            throw AhfError("the folder '" dirName "' of the shortcut does not exist", ErrCode.NOT_FOUND)
        exists := FileExist(path) != ""
        if (exists) {
            cur := ShortcutFile._Read(path)
            if (cur != "" && StrLower(cur["target"]) = StrLower(target) && cur["args"] == args
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

    ; Deletes the shortcut at path. Returns Map(action): removed or none (there was no file).
    static Remove(path) {
        ShortcutFile._CheckPath(path)
        if (FileExist(path) = "")
            return Map("action", "none")
        try {
            FileDelete(path)
        } catch as e {
            throw AhfError("the shortcut '" path "' cannot be deleted: " e.Message, ErrCode.INTERNAL)
        }
        return Map("action", "removed")
    }

    ; Map(target, args, workDir) of a shortcut, "" when the file is not a readable shortcut (it is replaced then).
    static _Read(path) {
        try {
            FileGetShortcut(path, &target, &dir, &args)
        } catch {
            return ""
        }
        return Map("target", target, "args", args, "workDir", dir)
    }

    ; Absolute path (drive or UNC), one line, extension .lnk. Otherwise AhfError bad_payload.
    static _CheckPath(path) {
        text := IsObject(path) ? "" : String(path)
        if (!RegExMatch(text, "^([A-Za-z]:\\|\\\\[^\\]+\\)") || InStr(text, "`n") || InStr(text, "`r"))
            throw AhfError("the path of a shortcut must be absolute: '" text "'", ErrCode.BAD_PAYLOAD)
        if (!RegExMatch(text, "i)\.lnk$"))
            throw AhfError("the path of a shortcut must end with .lnk: '" text "'", ErrCode.BAD_PAYLOAD)
    }
}
