#Requires AutoHotkey v2.0
#Include ..\..\..\core\Errors.ahk
#Include ..\..\..\core\Lang.ahk

; The shared functions of the file and folder elements of the package Default (WI-0120): the attributes of a path, the
; wildcard test, the reason of a failed file operation and the error that an element ends with. Pure: no file is read or
; written here. The elements that touch files are workers and make the calls themselves (rule file-io of
; tools/arch_check.py: the file functions are allowed in worker elements only).
;
; Errors (WI-0120, task 1): the v1 text of the failure, and after it the reason where the system tells one (in use by
; another program, the path is too long, access denied). A failure with no known reason keeps the v1 text alone.
class FileOps {
    ; The attribute string of a path (FileExist): "" when nothing matches, "D" in it for a folder. A wildcard pattern
    ; gives the attributes of its first match.
    static Attr(path) => FileExist(path)

    static IsFolder(attr) => InStr(attr, "D") > 0

    ; True for a wildcard pattern (* or ?): such a path names files, not one file.
    static IsWild(path) => InStr(path, "*") > 0 || InStr(path, "?") > 0

    ; The number a failed file function reports in its error: the OSError number, else the last system error code
    ; (FileCopy, FileMove and FileDelete throw a plain Error whose Extra property counts the failed files).
    static Code(err) => (err is OSError) ? err.Number : A_LastError

    ; The number of failed files of a wildcard operation (Extra of the error), 1 when the error does not say.
    static Failures(err) => (err.HasProp("Extra") && IsInteger(err.Extra)) ? err.Extra : 1

    ; The reason of a system error code, "" when it does not say more than the v1 text.
    static Reason(code) {
        switch code {
            case 5:
                return Lang("access is denied")
            case 32, 33:
                return Lang("in use by another program")
            case 206:
                return Lang("the path is too long")
        }
        return ""
    }

    ; The exception of a failed file operation: the v1 text, with the reason in brackets when the code tells one.
    static Fail(text, code := 0) {
        reason := FileOps.Reason(code)
        return ElementError((reason = "") ? text : text " (" reason ")")
    }

    ; The source of a file operation (copy, move, rename, delete): it must exist and, unless it is a pattern, be a file.
    ; The v1 texts of its checks.
    static CheckFileSource(path) {
        attr := FileOps.Attr(path)
        if (attr = "")
            throw ElementError(Lang("%1% '%2%' does not exist.", Lang("Source file"), path))
        if (!FileOps.IsWild(path) && FileOps.IsFolder(attr))
            throw ElementError(Lang("%1% '%2%' is a folder.", Lang("Source file"), path))
    }

    ; The source of a folder operation (copy, move, rename): it must exist and be a folder (the v1 texts).
    static CheckFolderSource(path) {
        attr := FileOps.Attr(path)
        if (attr = "")
            throw ElementError(Lang("%1% '%2%' does not exist.", Lang("Source folder"), path))
        if (!FileOps.IsFolder(attr))
            throw ElementError(Lang("%1% '%2%' is not a folder.", Lang("Source folder"), path))
    }

    ; True when a file (not a folder) exists at the path: the destination of a copy, move or rename that must not be
    ; overwritten (v1: "already exists").
    static ExistsAsFile(path) {
        attr := FileOps.Attr(path)
        return attr != "" && !FileOps.IsFolder(attr)
    }

    ; The exception for a wildcard in a path that does not allow one (the rename of one file).
    static NoWildcard(path) => ElementError(Lang("Wildcards are not allowed in '%1%'.", path))

    ; The full path of a path (GetFullPathNameW): "." and ".." are resolved. Used to compare paths, never to act on them.
    static _Full(path) {
        buf := Buffer(2048)
        n := DllCall("GetFullPathNameW", "str", path, "uint", 1024, "ptr", buf, "ptr", 0, "uint")
        return (n > 0 && n < 1024) ? StrGet(buf, n, "UTF-16") : path
    }

    ; Refuses a path that could reach a whole drive: an empty path, a drive root ("C:", "C:\", "C:\*") and a path relative
    ; to the root of the drive ("\x"). label is the Lang text of the parameter. v1 took an empty path as the working
    ; directory, which an empty working directory made the drive root (MIGRATION M-0119).
    static Guard(label, raw, path) {
        if (Trim(String(raw)) = "")
            throw ElementError(Lang("The path of '%1%' is empty.", label))
        trimmed := RTrim(path, "\*")
        if (trimmed = "" || RegExMatch(trimmed, "^[A-Za-z]:$") || (SubStr(trimmed, 1, 1) = "\" && SubStr(trimmed, 2, 1) != "\"))
            throw ElementError(Lang("'%1%' is a drive root and is not allowed here.", path))
        full := RTrim(FileOps._Full(trimmed), "\")
        if (RegExMatch(full, "^[A-Za-z]:$"))
            throw ElementError(Lang("'%1%' is a drive root and is not allowed here.", path))
    }

    ; Refuses the working directory of the flow itself (a folder deleted with its contents would take everything).
    static GuardWorkingDir(path, workingDir) {
        if (workingDir = "")
            return
        full := RTrim(FileOps._Full(RTrim(path, "\*")), "\")
        if (StrLower(full) = StrLower(RTrim(FileOps._Full(workingDir), "\")))
            throw ElementError(Lang("'%1%' is the working directory of the flow and is not allowed here.", path))
    }
}
