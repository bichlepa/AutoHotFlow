#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\ErrCode.ahk
#Include StoragePaths.ahk
#Include VarFiles.ahk
#Include ..\core\Time.ahk
#Include ArchiveTar.ahk

; cmd.storage.ahf.pack (WI-0081, PROTOCOL 4.6): writes an .ahf file (a ZIP archive, as v1 writes it, flat at the root) with the
; flow files as saved and the static variables of those flows. The archive is built in a job folder of the data folder
; (Archive/pack-<n>-<ms>/) and moved to the target when tar has written it. Step is called by the queue (see Storage._CmdAhfPack):
; the first call copies the files and starts tar, the next calls ask whether tar has finished (retry until then).
; Nothing is written next to the target before the archive is complete.
class ArchivePack {
    static seq := 0
    static FREE_MS := 1000         ; the time a failed job waits for its folder to be free (a killed tar.exe)

    ; timeoutMs: the limit of the tar run (the queue waits longer than that, see Storage._DeferBackground).
    __New(dataDir, flowIds, path, timeoutMs := 0) {
        ArchiveTar.CheckText(dataDir, "the data folder")
        ArchiveTar.CheckText(path, "the file")
        this.dataDir := dataDir
        this.flowIds := flowIds
        this.path := path
        this.timeoutMs := timeoutMs
        this.job := ""
        this.zip := ""
        this.tar := ""
        this.started := false
        this.failure := ""
        this.freeUntil := 0
    }

    ; One step of the operation: a Map(retry, message) while tar runs, else the payload Map(count). A failure cleans up the job folder.
    Step() {
        if (IsObject(this.failure))
            return this._AwaitFree()
        try {
            return this._Step()
        } catch as e {
            if (IsObject(this.tar) && this.tar.timedOut && this.job != "") {
                ; a killed tar.exe may still hold a file of the folder: the answer waits until the folder is free
                this.failure := e
                this.freeUntil := Time.NowMs() + ArchivePack.FREE_MS
                return this._AwaitFree()
            }
            this.Cleanup()
            throw e
        }
    }

    ; The answer of a failed run, given when its job folder is free (or after FREE_MS, the folder then goes to leftovers).
    _AwaitFree() {
        if (ArchiveTar.TryDiscard(this.job) || Time.NowMs() > this.freeUntil) {
            this.Cleanup()
            e := this.failure
            this.failure := ""
            throw e
        }
        return Map("retry", true, "message", "waiting for a killed tar.exe to let go of the job folder")
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
        ArchiveTar.Sweep()
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
            if (SubStr(flowId, 1, 1) = "-" || SubStr(flowId, 1, 1) = "@")
                throw AhfError("flow ID '" flowId "' starts with a character that tar.exe reads as an option", ErrCode.BAD_PAYLOAD)
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
        this.tar := ArchiveTar(this.job, "tar", args, this.timeoutMs)
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
        ArchiveTar.Discard(this.job)
        this.job := ""
    }
}
