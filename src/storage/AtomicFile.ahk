#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk

; Atomic replacement of a file (ARCHITECTURE 6.3). The text goes to a temp file in the same folder,
; then MoveFileEx with MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH replaces the target. A crash
; leaves the old or the new file, never a half-written one. v1 used FileDelete + FileAppend, which
; loses the file when it crashes in between (Save.ahk:145-146).
class AtomicFile {
    static REPLACE_FLAGS := 0x9   ; MOVEFILE_REPLACE_EXISTING (1) | MOVEFILE_WRITE_THROUGH (8)

    ; Writes text as UTF-8 without BOM (FileOpen "UTF-8-RAW"). Throws AhfError (internal) on failure.
    static Write(filePath, text) {
        tmpPath := filePath ".ahf-" DllCall("GetCurrentProcessId", "UInt") ".tmp"
        handle := ""
        try {
            handle := FileOpen(tmpPath, "w", "UTF-8-RAW")
            handle.Write(text)
            handle.Close()
        } catch as e {
            if (IsObject(handle))
                handle.Close()
            AtomicFile._Remove(tmpPath)
            throw AhfError("cannot write '" filePath "': " e.Message, ErrCode.INTERNAL)
        }
        ok := DllCall("MoveFileExW", "Str", tmpPath, "Str", filePath, "UInt", AtomicFile.REPLACE_FLAGS, "Int")
        err := A_LastError
        if (!ok) {
            AtomicFile._Remove(tmpPath)
            throw AhfError("cannot replace '" filePath "' (system error " err ")", ErrCode.INTERNAL)
        }
    }

    ; Deletes the temp files "<name>.ahf-<pid>.tmp" below root (recursive) whose process does not run
    ; any more: a hard stop between the temp write and the rename leaves them (WI-25). A file of a
    ; running process (also our own, a write may be in progress) stays. Best effort: a file that cannot
    ; be deleted stays. Returns the number of deleted files.
    static RemoveStaleTemps(root) {
        removed := 0
        if (!DirExist(root))
            return 0
        try {
            loop files root "\*.tmp", "FR" {
                if (!RegExMatch(A_LoopFileName, "\.ahf-(\d+)\.tmp$", &m) || AtomicFile.ProcessRuns(Integer(m[1])))
                    continue
                try {
                    FileDelete(A_LoopFileFullPath)
                    removed += 1
                } catch {
                    ; held by someone or already gone: next start tries again
                }
            }
        } catch {
            ; the folder vanished while scanning
        }
        return removed
    }

    ; True while a process with this id exists. An id that cannot be opened because of missing rights
    ; (access denied) counts as running, so a file is never removed on a doubt.
    static ProcessRuns(pid) {
        synchronize := 0x100000
        handle := DllCall("OpenProcess", "UInt", synchronize, "Int", 0, "UInt", pid, "Ptr")
        if (!handle)
            return A_LastError != 87   ; ERROR_INVALID_PARAMETER: no such process
        stillRunning := (DllCall("WaitForSingleObject", "Ptr", handle, "UInt", 0, "UInt") = 0x102)   ; WAIT_TIMEOUT
        DllCall("CloseHandle", "Ptr", handle)
        return stillRunning
    }

    ; Reads a text file as UTF-8. A leading BOM (v1 writes one for some files) is dropped.
    static ReadText(filePath) {
        text := FileRead(filePath, "UTF-8")
        if (SubStr(text, 1, 1) = Chr(0xFEFF))
            text := SubStr(text, 2)
        return text
    }

    ; Line ends as in v1 files: CRLF. Input may have LF or CRLF. JSON strings never contain raw
    ; line breaks, so the replacement cannot touch string contents.
    static Crlf(text) => StrReplace(StrReplace(text, "`r`n", "`n"), "`n", "`r`n")

    ; Best effort. A leftover temp file is harmless (its name is never read), so a failure here is ignored.
    static _Remove(tmpPath) {
        if (FileExist(tmpPath) != "") {
            try {
                FileDelete(tmpPath)
            } catch {
                ; left behind on purpose: the next write of this file by the same process overwrites it
            }
        }
    }
}
