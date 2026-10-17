#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\ErrCode.ahk
#Include ..\core\Time.ahk

; One run of tar.exe for the .ahf archives (WI-0081, PROTOCOL 4.6, decision in work_items/phase3/WI-0081). The process is
; started without waiting (Run, never RunWait): cmd.exe runs tar with its output in a file and writes "ok" or "fail" into a
; second file when tar has ended, so the process of storage can ask again later (Finished, Ok) and no call blocks.
;
; The files of one run sit in the job folder (the folder of the operation, see ArchivePack and ArchiveUnpack): <name>.out
; (the output of tar, names or errors) and <name>.code ("ok" or "fail"). Nothing else is written by this class.
;
; A run that is over its time is killed with its child processes (taskkill /T). A job folder that a process still holds open
; cannot be removed at once: it is kept in `leftovers` and the next job removes it (Sweep).
class ArchiveTar {
    static TIMEOUT_MS := 20000     ; one tar run that is still going after this long is killed (PROTOCOL 4.6)
    static POLL_MS := 100          ; the operation asks again this often while tar runs (the queue's retry delay)
    static OUTPUT_MAX := 4000      ; characters of the output that an error message shows
    static TAR := ""               ; the tar.exe to run; "" = the one of Windows (--archive-tar, tests only)
    static leftovers := []         ; job folders that could not be removed yet

    static Exe() => (ArchiveTar.TAR != "") ? ArchiveTar.TAR : A_WinDir "\System32\tar.exe"

    ; A text that goes into the command line of cmd.exe: a percent sign expands there, a quote ends the argument.
    static CheckText(text, what) {
        if (InStr(text, "%") || InStr(text, '"') || InStr(text, "`n") || InStr(text, "`r"))
            throw AhfError(what " '" text "' has a % sign, a quote or a line break, which cmd.exe cannot pass to tar.exe",
                ErrCode.BAD_PAYLOAD)
    }

    ; dir: the job folder. name: a file name without extension, unique in dir. args: the arguments of tar, quoted by the caller.
    ; timeoutMs: the limit of this run (0 = TIMEOUT_MS).
    __New(dir, name, args, timeoutMs := 0) {
        this.out := dir "\" name ".out"
        this.code := dir "\" name ".code"
        this.args := args
        this.pid := 0
        this.limitMs := (timeoutMs > 0) ? timeoutMs : ArchiveTar.TIMEOUT_MS
        this.deadline := Time.NowMs() + this.limitMs
        this.timedOut := false
    }

    ; Starts tar.exe hidden. Throws internal when cmd.exe cannot be started.
    Start() {
        cmdLine := A_ComSpec ' /d /c ""' ArchiveTar.Exe() '" ' this.args ' > "' this.out '" 2>&1 && (echo ok> "' this.code '") || (echo fail> "' this.code '")"'
        try {
            Run(cmdLine, , "Hide", &pid)
        } catch as e {
            throw AhfError("tar.exe cannot be started: " e.Message, ErrCode.INTERNAL)
        }
        this.pid := pid
    }

    ; True when tar has ended (the answer has its text, or the process is gone). Throws internal when the run is over its time;
    ; the run and its child processes are then killed first.
    Finished() {
        if (!ProcessExist(this.pid))
            return true
        if (this._Answer() != "")
            return true
        if (Time.NowMs() > this.deadline) {
            this.timedOut := true           ; the job waits for its folder to be free before it answers (ArchiveJob)
            this.Kill()
            throw AhfError("tar.exe did not finish in " this.limitMs " ms", ErrCode.INTERNAL)
        }
        return false
    }

    ; Kills the run with its child processes (tar.exe under cmd.exe). A run that ended already is no error.
    Kill() {
        try {
            Run('taskkill /T /F /PID ' this.pid, , "Hide")
        } catch {
            ; taskkill cannot be started: the run is left to end on its own; its job folder is then kept (Discard)
        }
    }

    ; True when tar wrote "ok".
    Ok() => this._Answer() = "ok"

    ; The output of tar as an error text, bounded.
    Output() {
        text := this.Text()
        if (StrLen(text) > ArchiveTar.OUTPUT_MAX)
            text := SubStr(text, 1, ArchiveTar.OUTPUT_MAX) "..."
        return text
    }

    ; The whole output of tar, unbounded: the names of a listing are checked completely, never cut.
    Text() {
        if (FileExist(this.out) = "")
            return ""
        try {
            return Trim(FileRead(this.out), " `r`n`t")
        } catch as e {
            return "(the output of tar cannot be read: " e.Message ")"
        }
    }

    ; The answer word of the run ("ok" or "fail"), "" while there is none. The file exists before cmd has written its word
    ; into it, and a locked file cannot be read yet: both are "no answer yet".
    _Answer() {
        if (FileExist(this.code) = "")
            return ""
        try {
            return Trim(FileRead(this.code), " `r`n`t")
        } catch {
            ; the file is still being written or locked: the next call asks again
            return ""
        }
    }

    ; Removes a job folder. A folder that a process still holds open stays in leftovers (removed by Sweep).
    static Discard(dir) {
        if (!ArchiveTar.TryDiscard(dir))
            ArchiveTar.leftovers.Push(dir)      ; a process still holds a file of it: Sweep removes it later
    }

    ; True when the folder is gone (removed now, or never there). False while a process still holds a file of it.
    static TryDiscard(dir) {
        if (!DirExist(dir))
            return true
        try {
            DirDelete(dir, true)
            return true
        } catch {
            return false                        ; still held: the caller asks again
        }
    }

    ; Tries again to remove the job folders that were kept.
    static Sweep() {
        keep := []
        for dir in ArchiveTar.leftovers {
            if (!DirExist(dir))
                continue
            try {
                DirDelete(dir, true)
            } catch {
                keep.Push(dir)                  ; still held: the next job tries again
            }
        }
        ArchiveTar.leftovers := keep
    }
}
