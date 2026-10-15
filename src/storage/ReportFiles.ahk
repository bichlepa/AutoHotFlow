#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include StoragePaths.ahk
#Include AtomicFile.ahk

; Crash and diagnostic reports in <data>/Reports/ (WI-0028, doc/PROTOCOL.md 4.9). The supervisor builds the
; contents (it never writes files) and sends them as cmd.storage.report.write; this class writes them.
;
;   Reports/<yyyyMMdd-HHmmss>_<reason>/        one folder per report ("-2", "-3" ... when the name exists)
;       <files of the request>                  e.g. report.json, summary.txt (written atomically)
;       Log.txt, Log_old.txt                    copies of the common log (Log/), when readable
;
; At most KEEP folders stay; after a write the oldest (by name, the stamp sorts by time) are deleted.
; Every name is checked before it becomes part of a path, so a request cannot leave Reports/.
class ReportFiles {
    static KEEP := 20
    static STAMP := "^\d{8}-\d{6}$"
    static REASON := "^[A-Za-z0-9._-]{1,60}$"
    static FILE_NAME := "^[A-Za-z0-9._-]{1,100}$"
    static FOLDER := "^\d{8}-\d{6}_"
    static LOG_FILES := ["Log.txt", "Log_old.txt"]
    ; Written by this class itself from the log folder; a request must not use these names.
    static RESERVED := Map("log.txt", 1, "log_old.txt", 1)
    static MAX_SUFFIX := 50

    static Dir(dataDir) => dataDir "\Reports"

    ; Writes one report. files: Map of file name -> text. Returns Map: path ("Reports/<folder>", relative, with
    ; slash), dir (absolute), removed (old folders deleted), logs (names of the log files copied).
    ; Throws AhfError: bad_payload for a bad stamp, reason or file name, internal when a file cannot be written.
    static Write(dataDir, stamp, reason, files) {
        stamp := String(stamp)
        reason := String(reason)
        if (!RegExMatch(stamp, ReportFiles.STAMP))
            throw AhfError("report stamp '" stamp "' is not yyyyMMdd-HHmmss", ErrCode.BAD_PAYLOAD)
        if (!RegExMatch(reason, ReportFiles.REASON))
            throw AhfError("report reason '" reason "' is not 1 to 60 of A-Z a-z 0-9 . _ -", ErrCode.BAD_PAYLOAD)
        if (!(files is Map) || files.Count = 0)
            throw AhfError("report files must be a non-empty object", ErrCode.BAD_PAYLOAD)
        for name, text in files {
            if (!RegExMatch(name, ReportFiles.FILE_NAME) || name = "." || name = ".." || ReportFiles.RESERVED.Has(StrLower(name)))
                throw AhfError("report file name '" name "' is not allowed", ErrCode.BAD_PAYLOAD)
            if (IsObject(text))
                throw AhfError("report file '" name "' must be text", ErrCode.BAD_PAYLOAD)
        }
        root := ReportFiles.Dir(dataDir)
        try {
            DirCreate(root)
        } catch as e {
            throw AhfError("cannot create '" root "': " e.Message, ErrCode.INTERNAL)
        }
        folder := ReportFiles._FreeName(root, stamp "_" reason)
        dir := root "\" folder
        try {
            DirCreate(dir)
            for name, text in files
                AtomicFile.Write(dir "\" name, String(text))
        } catch as e {
            throw AhfError("cannot write the report '" folder "': " e.Message, ErrCode.INTERNAL)
        }
        logs := ReportFiles._CopyLogs(dataDir, dir)
        removed := ReportFiles.Prune(root, ReportFiles.KEEP)
        return Map("path", "Reports/" folder, "dir", dir, "removed", removed, "logs", logs)
    }

    ; Names of the report folders below root, oldest first.
    static Folders(root) {
        names := []
        if (!DirExist(root))
            return names
        loop files root "\*", "D" {
            if (RegExMatch(A_LoopFileName, ReportFiles.FOLDER))
                names.Push(A_LoopFileName)
        }
        return StoragePaths.SortStrings(names)
    }

    ; Deletes the oldest report folders until at most keep are left. Returns the number deleted.
    static Prune(root, keep) {
        names := ReportFiles.Folders(root)
        removed := 0
        loop Max(0, names.Length - keep) {
            try {
                DirDelete(root "\" names[A_Index], true)
                removed += 1
            } catch {
                ; held by a viewer: it goes with the next report
            }
        }
        return removed
    }

    static _FreeName(root, base) {
        name := base
        suffix := 1
        while (DirExist(root "\" name) && suffix < ReportFiles.MAX_SUFFIX) {
            suffix += 1
            name := base "-" suffix
        }
        return name
    }

    ; Copies the common log files into the report folder. A file that is missing or cannot be copied is skipped.
    static _CopyLogs(dataDir, dir) {
        copied := []
        for name in ReportFiles.LOG_FILES {
            source := StoragePaths.LogDir(dataDir) "\" name
            if (FileExist(source) = "")
                continue
            try {
                FileCopy(source, dir "\" name, true)
                copied.Push(name)
            } catch {
                ; the file is locked by another process: the snapshot's log ring has the newest lines anyway
            }
        }
        return copied
    }
}
