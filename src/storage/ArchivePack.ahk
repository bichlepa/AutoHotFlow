#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\ErrCode.ahk
#Include StoragePaths.ahk
#Include VarFiles.ahk
#Include ArchiveTar.ahk

; cmd.storage.ahf.pack (WI-0081, PROTOCOL 4.6): writes an .ahf file (a ZIP archive, as v1 writes it, flat at the root) with the
; flow files as saved and the static variables of those flows. The archive is built in a job folder of the data folder
; (Archive/pack-<n>-<ms>/) and moved to the target when tar has written it. Step is called by the queue (see Storage._CmdAhfPack):
; the first call copies the files and starts tar, the next calls ask whether tar has finished (retry until then).
; Nothing is written next to the target before the archive is complete.
class ArchivePack {
    static seq := 0

    __New(dataDir, flowIds, path) {
        this.dataDir := dataDir
        this.flowIds := flowIds
        this.path := path
        this.job := ""
        this.zip := ""
        this.tar := ""
        this.started := false
    }

    ; One step of the operation: a Map(retry, message) while tar runs, else the payload Map(count). A failure cleans up the job folder.
    Step() {
        try {
            return this._Step()
        } catch as e {
            this.Cleanup()
            throw e
        }
    }

    _Step() {
        if (!this.started) {
            this._Stage()
            this.started := true
            this.tar.Start()
            return Map("retry", true, "message", "tar is writing the archive")
        }
        if (!this.tar.Finished())
            return Map("retry", true, "message", "tar is writing the archive")
        if (!this.tar.Ok())
            throw AhfError("the archive could not be written: " this.tar.Output(), ErrCode.INTERNAL)
        try {
            FileMove(this.zip, this.path, 1)
        } catch as e {
            throw AhfError("the archive cannot be written to '" this.path "': " e.Message, ErrCode.INTERNAL)
        }
        count := this.flowIds.Length
        this.Cleanup()
        return Map("count", count)
    }

    ; Copies the flow files and the static variables into the job folder and prepares the tar run.
    _Stage() {
        ArchivePack.seq += 1
        this.job := StoragePaths.ArchiveDir(this.dataDir) "\pack-" ArchivePack.seq "-" A_TickCount
        staging := this.job "\files"
        DirCreate(staging)
        items := []
        seen := Map()
        for flowId in this.flowIds {
            if (!(flowId is String) || flowId = "")
                throw AhfError("cmd.storage.ahf.pack: every flow ID must be a text", ErrCode.BAD_PAYLOAD)
            StoragePaths.CheckName(flowId, "flow ID")
            if (seen.Has(flowId))
                continue
            seen[flowId] := true
            src := StoragePaths.Flow(this.dataDir, "Flows/" flowId ".json")
            if (FileExist(src) = "")
                throw AhfError("flow file '" flowId ".json' not found", ErrCode.NOT_FOUND)
            FileCopy(src, staging "\" flowId ".json", 1)
            items.Push('"' flowId '.json"')
            for name in VarFiles.List(this.dataDir, "static", flowId)["names"]
                this._CopyVar(staging, flowId, name)
        }
        if (DirExist(staging "\Variables"))
            items.Push("Variables")
        this.zip := this.job "\out.zip"
        args := '--format zip -cf "' this.zip '" -C "' staging '"'
        for item in items
            args .= " " item
        this.tar := ArchiveTar(this.job, "tar", args)
    }

    ; The two files of one static variable, in the layout of the data folder (Variables/<flowId>/<name>.ahfvd|.ahfvar).
    _CopyVar(staging, flowId, name) {
        stem := VarFiles.Stem(this.dataDir, "static", flowId, name)
        dir := staging "\Variables\" flowId
        DirCreate(dir)
        FileCopy(stem ".ahfvd", dir "\" name ".ahfvd", 1)
        FileCopy(stem ".ahfvar", dir "\" name ".ahfvar", 1)
    }

    Cleanup() {
        if (this.job = "")
            return
        try {
            DirDelete(this.job, true)
        } catch {
            ; a folder that is still in use (tar still running) is left; the next start of storage finds it in Archive/
        }
        this.job := ""
    }
}
