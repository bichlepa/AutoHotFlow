#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Json.ahk
#Include StoragePaths.ahk
#Include AtomicFile.ahk

; Flow files in Flows/ (WI-12, ARCHITECTURE 7, MIGRATION M-07). Text in, text out: storage never
; interprets the flow beyond checking that it is a JSON object, the engine parses it.
;
; Backup (M-07): before an existing file is replaced, its content is copied to
; Flows/backup/<name>_backup_<yyyyMMddHHmmss><ms>.json. At most MAX_BACKUPS are kept, the oldest go
; first (v1 Save.ahk:124-146 kept the same number, but never created a backup, see M-07).
; A failed backup stops the write: the old file is then still in place and nothing is lost.
class FlowFiles {
    static BACKUP_DIR := "backup"
    static MAX_BACKUPS := 10
    static EPOCH := "19700101000000"

    ; Flow files directly in Flows/ (not recursive). Each entry: Map(path, name, mtime).
    static List(dataDir) {
        dirPath := StoragePaths.FlowsDir(dataDir)
        found := []
        if (!DirExist(dirPath))
            return found
        pattern := dirPath "\*.json"
        loop files, pattern {
            found.Push(Map("path", "Flows/" A_LoopFileName, "name", SubStr(A_LoopFileName, 1, -5)
                , "mtime", DateDiff(A_LoopFileTimeModified, FlowFiles.EPOCH, "Seconds")))
        }
        names := []
        for entry in found
            names.Push(entry["name"])
        ; Sorted by name: sort the entries through their names.
        sorted := []
        for name in StoragePaths.SortStrings(names) {
            for entry in found {
                if (entry["name"] = name) {
                    sorted.Push(entry)
                    break
                }
            }
        }
        return sorted
    }

    ; Text of a flow file. Throws not_found when the file does not exist.
    static Read(dataDir, flowPath) {
        filePath := StoragePaths.Flow(dataDir, flowPath)
        if (FileExist(filePath) = "")
            throw AhfError("flow file '" flowPath "' not found", ErrCode.NOT_FOUND)
        return AtomicFile.ReadText(filePath)
    }

    ; Writes a flow file atomically with CRLF line ends. text must be a JSON object (bad_payload otherwise).
    static Write(dataDir, flowPath, text, backup) {
        filePath := StoragePaths.Flow(dataDir, flowPath)
        root := ""
        try {
            root := Json.Parse(String(text))
        } catch as e {
            throw AhfError("flow text is not valid JSON: " e.Message, ErrCode.BAD_PAYLOAD)
        }
        if (!(root is Map))
            throw AhfError("flow text is not a JSON object", ErrCode.BAD_PAYLOAD)
        if (backup && FileExist(filePath) != "")
            FlowFiles._Backup(filePath)
        AtomicFile.Write(filePath, AtomicFile.Crlf(String(text)))
    }

    ; Copies the current file into backup/ and removes the oldest backups above MAX_BACKUPS.
    static _Backup(filePath) {
        SplitPath(filePath, , &dirPath, , &stem)
        backupDir := dirPath "\" FlowFiles.BACKUP_DIR
        DirCreate(backupDir)
        stamp := Format("{}{:03}", A_Now, A_MSec)
        target := backupDir "\" stem "_backup_" stamp ".json"
        n := 1
        while (FileExist(target) != "") {
            n += 1
            target := backupDir "\" stem "_backup_" stamp "_" n ".json"
        }
        FileCopy(filePath, target)
        FlowFiles._Prune(backupDir, stem)
        return target
    }

    ; Keeps the MAX_BACKUPS newest backups of one flow. The names sort by time (fixed-width stamp).
    static _Prune(backupDir, stem) {
        pattern := backupDir "\" stem "_backup_*.json"
        found := []
        loop files, pattern
            found.Push(A_LoopFileName)
        StoragePaths.SortStrings(found)
        while (found.Length > FlowFiles.MAX_BACKUPS)
            FileDelete(backupDir "\" found.RemoveAt(1))
    }
}
