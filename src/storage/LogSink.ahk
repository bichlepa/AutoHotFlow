#Requires AutoHotkey v2.0
#Include StoragePaths.ahk
#Include AtomicFile.ahk

; Log files in Log/ (WI-12, v1 "Logger.ahk", PROTOCOL 4.6). Every entry is written to Log.txt and to
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

    ; Appends the entry to Log.txt and Log_<source>.txt in logDir.
    static Append(logDir, stamp, thread, source, text) {
        if (!DirExist(logDir))
            DirCreate(logDir)
        line := LogSink.Line(stamp, thread, source, text)
        for fileName in ["Log.txt", "Log_" LogSink.SafeName(source) ".txt"] {
            filePath := logDir "\" fileName
            LogSink._RotateIfBig(filePath)
            FileAppend(line, filePath, "UTF-8-RAW")
        }
    }

    ; Replaces characters that are not allowed in file names (v1 sources like "Flow 369404488" are fine).
    static SafeName(source) => RegExReplace(String(source), '[\\/:*?"<>|\x00-\x1F]', "_")

    static _RotateIfBig(filePath) {
        if (SubStr(filePath, -8) = "_old.txt")
            return
        if (FileExist(filePath) != "" && FileGetSize(filePath) > LogSink.MAX_BYTES)
            FileMove(filePath, SubStr(filePath, 1, -4) "_old.txt", true)
    }
}
