#Requires AutoHotkey v2.0
#Include StoragePaths.ahk
#Include AtomicFile.ahk

; Log files in Log/ (WI-0012, v1 "Logger.ahk", PROTOCOL 4.6). Every entry is written to Log.txt and to
; Log_<source>.txt, in the v1 line format:
;   CRLF, "--- yyyy MM dd HH:mm:ss ~<thread>~<source>~ <text>"
; thread is the name of the sending role (v1 showed the AHK thread; v2 has one thread per process).
; The time is local, as in v1. The sender's ts is UTC (Role._Enqueue) and is converted here.
; A file over MAX_BYTES is renamed to <name>_old.txt before the next append (v1 log_cleanup, which
; checked every 50 entries; v2 checks on each append, the cost is one size query per file).
class LogSink {
    static MAX_BYTES := 102400   ; 100 KB, as v1 (Logger.ahk:256, "temp>100" in KB)

    ; Local time "yyyy MM dd HH:mm:ss" for a UTC text "yyyy-MM-dd HH:mm:ss". Falls back to now.
    static LocalStamp(utcText) {
        digits := RegExReplace(String(utcText), "\D")
        if (StrLen(digits) != 14)
            return FormatTime(A_Now, "yyyy MM dd HH:mm:ss")
        offset := DateDiff(A_Now, A_NowUTC, "Seconds")
        return FormatTime(DateAdd(digits, offset, "Seconds"), "yyyy MM dd HH:mm:ss")
    }

    ; One entry as written to the files (starts with CRLF, like v1).
    static Line(stamp, thread, source, text) {
        return "`r`n--- " stamp " ~" thread "~" source "~ " AtomicFile.Crlf(String(text))
    }

    ; File names of an entry: the common log and the log of its source.
    static FileNames(source) => ["Log.txt", "Log_" LogSink.SafeName(source) ".txt"]

    ; Appends the entry to one file in logDir (rotating first). Returns "" when written, or the text
    ; of the error when another process holds the file (sharing or lock violation, access denied by a
    ; scanner): the caller retries later (F-0003). Any other error is thrown.
    ; FileAppend is not used: it opens the file without sharing, so any other open handle (a viewer,
    ; a scanner) made it fail with error 32. FileOpen without the deny flags shares read and write.
    static AppendTo(logDir, fileName, line) {
        try {
            if (!DirExist(logDir))
                DirCreate(logDir)
            filePath := logDir "\" fileName
            LogSink._RotateIfBig(filePath)
            file := FileOpen(filePath, "a", "UTF-8-RAW")
            try {
                file.Write(line)
            } finally {
                file.Close()
            }
        } catch OSError as e {
            if (LogSink.IsBusy(e))
                return Type(e) ": " e.Message
            throw e
        }
        return ""
    }

    ; True for the errors of a file that another process holds: 5 access denied, 32 sharing violation,
    ; 33 lock violation. (A_LastError is not used, FileOpen sets e.Number.)
    static IsBusy(e) => e.Number = 5 || e.Number = 32 || e.Number = 33

    ; Replaces characters that are not allowed in file names (v1 sources like "Flow 369404488" are fine).
    static SafeName(source) => RegExReplace(String(source), '[\\/:*?"<>|\x00-\x1F]', "_")

    static _RotateIfBig(filePath) {
        if (SubStr(filePath, -8) = "_old.txt")
            return
        try {
            if (FileExist(filePath) != "" && FileGetSize(filePath) > LogSink.MAX_BYTES)
                FileMove(filePath, SubStr(filePath, 1, -4) "_old.txt", true)
        } catch OSError {
            ; The file is held by another process. Rotation is skipped, the entry is still written;
            ; the next entry tries again.
        }
    }
}
