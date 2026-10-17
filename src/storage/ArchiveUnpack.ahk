#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\ErrCode.ahk
#Include StoragePaths.ahk
#Include AtomicFile.ahk
#Include VarFiles.ahk
#Include ArchiveTar.ahk
#Include ArchiveEntries.ahk

; cmd.storage.ahf.unpack (WI-0081, PROTOCOL 4.6, REQ-SEC-060): reads an .ahf file (a ZIP archive, v1 or v2). Nothing is written
; next to the file; the archive is extracted into a job folder of the data folder (Archive/unpack-<n>-<ms>/) and the job folder
; is removed after the read. Order: (1) the names of the archive are listed by tar and checked against the layout (ArchiveEntries),
; (2) only then the archive is extracted, (3) the extracted tree is checked again, file by file, and a link is refused,
; (4) the flows and the static variables are read. Any refusal leaves nothing behind (Step cleans up on failure).
class ArchiveUnpack {
    static seq := 0

    __New(dataDir, path) {
        this.dataDir := dataDir
        this.path := path
        this.job := ""
        this.root := ""
        this.tar := ""
        this.state := "start"
    }

    ; One step: a Map(retry, message) while tar runs, else the payload Map(flows, vars).
    Step() {
        try {
            return this._Step()
        } catch as e {
            this.Cleanup()
            throw e
        }
    }

    _Step() {
        if (this.state = "start") {
            this._NewJob()
            this.tar := ArchiveTar(this.job, "list", '-tf "' this.path '"')
            this.tar.Start()
            this.state := "listing"
            return Map("retry", true, "message", "tar is listing the archive")
        }
        if (this.state = "listing") {
            if (!this.tar.Finished())
                return Map("retry", true, "message", "tar is listing the archive")
            if (!this.tar.Ok())
                throw AhfError("the file is not a ZIP archive that can be read: " this.tar.Output(), ErrCode.BAD_PAYLOAD)
            ArchiveEntries.Check(StrSplit(this.tar.Text(), "`n", "`r"))     ; the whole listing, never a cut one
            this.root := this.job "\files"
            DirCreate(this.root)
            this.tar := ArchiveTar(this.job, "extract", '-xf "' this.path '" -C "' this.root '"')
            this.tar.Start()
            this.state := "extracting"
            return Map("retry", true, "message", "tar is extracting the archive")
        }
        if (!this.tar.Finished())
            return Map("retry", true, "message", "tar is extracting the archive")
        if (!this.tar.Ok())
            throw AhfError("the archive could not be extracted: " this.tar.Output(), ErrCode.BAD_PAYLOAD)
        this._CheckTree()
        payload := this._Read()
        this.Cleanup()
        return payload
    }

    ; Every extracted file and folder must have an allowed name, and no link may be in the tree.
    _CheckTree() {
        loop files, this.root "\*", "DFR" {
            rel := SubStr(A_LoopFilePath, StrLen(this.root) + 2)
            rel := StrReplace(rel, "\", "/")
            if (InStr(A_LoopFileAttrib, "L"))
                throw AhfError("a link in the archive is not allowed, the file is refused", ErrCode.DENIED)
            if (InStr(A_LoopFileAttrib, "D"))
                rel .= "/"
            if (!ArchiveEntries.IsAllowed(rel))
                throw AhfError("the entry '" rel "' is not allowed in an .ahf file, the file is refused", ErrCode.DENIED)
        }
    }

    ; Map(flows, vars): the flows (sorted by key) and the static variables of the extracted tree.
    _Read() {
        keys := []
        loop files, this.root "\*.json"
            keys.Push(SubStr(A_LoopFileName, 1, -5))
        flows := []
        for key in StoragePaths.SortStrings(keys)
            flows.Push(Map("key", key, "text", AtomicFile.ReadText(this.root "\" key ".json")))
        vars := []
        varsDir := this.root "\Variables"
        folders := []
        if (DirExist(varsDir)) {
            loop files, varsDir "\*", "D" {
                if (InStr(A_LoopFileAttrib, "D"))
                    folders.Push(A_LoopFileName)
            }
        }
        for key in StoragePaths.SortStrings(folders) {
            for name in VarFiles.List(this.root, "static", key)["names"] {
                got := VarFiles.Get(this.root, "static", key, name)
                vars.Push(Map("flowKey", key, "name", name, "type", got.Get("type", "normal")
                    , "content", got.Get("content", "")))
            }
        }
        return Map("flows", flows, "vars", vars)
    }

    _NewJob() {
        ArchiveUnpack.seq += 1
        this.job := StoragePaths.ArchiveDir(this.dataDir) "\unpack-" ArchiveUnpack.seq "-" A_TickCount
        DirCreate(this.job)
    }

    Cleanup() {
        if (this.job = "")
            return
        try {
            DirDelete(this.job, true)
        } catch {
            ; a folder still in use (tar still running) is left; the start of storage removes Archive/
        }
        this.job := ""
    }
}
