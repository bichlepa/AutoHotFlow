#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ..\core\Time.ahk

; One run of tar.exe for the .ahf archives (WI-0081, PROTOCOL 4.6, decision in work_items/phase3/WI-0081). The process is
; started without waiting (Run, never RunWait): cmd.exe runs tar with its output in a file and writes "ok" or "fail" into a
; second file when tar has ended, so the process of storage can ask again later (Finished, Ok) and no call blocks.
;
; The files of one run sit in the job folder (the folder of the operation, see ArchivePack and ArchiveUnpack): <name>.out
; (the output of tar, names or errors) and <name>.code ("ok" or "fail"). Nothing else is written by this class.
class ArchiveTar {
    static TIMEOUT_MS := 20000     ; a run that is still going after this long is killed (the manager asks for 30 s)
    static POLL_MS := 100          ; the operation asks again this often while tar runs (the queue's retry delay)
    static OUTPUT_MAX := 4000      ; characters of the output that an error message shows

    static Exe() => A_WinDir "\System32\tar.exe"

    ; dir: the job folder. name: a file name without extension, unique in dir. args: the arguments of tar, quoted by the caller.
    __New(dir, name, args) {
        this.out := dir "\" name ".out"
        this.code := dir "\" name ".code"
        this.args := args
        this.pid := 0
        this.deadline := Time.NowMs() + ArchiveTar.TIMEOUT_MS
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

    ; True when tar has ended (the answer file exists, or the process is gone). Throws internal when the run is over its time:
    ; the process is then killed.
    Finished() {
        if (FileExist(this.code) != "")
            return true
        if (!ProcessExist(this.pid))
            return true
        if (Time.NowMs() > this.deadline) {
            try {
                ProcessClose(this.pid)
            } catch {
                ; the process ended meanwhile: nothing to kill
            }
            throw AhfError("tar.exe did not finish in " ArchiveTar.TIMEOUT_MS " ms", ErrCode.INTERNAL)
        }
        return false
    }

    ; True when tar wrote "ok".
    Ok() {
        if (FileExist(this.code) = "")
            return false
        return Trim(FileRead(this.code), " `r`n`t") = "ok"
    }

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
        return Trim(FileRead(this.out), " `r`n`t")
    }
}
