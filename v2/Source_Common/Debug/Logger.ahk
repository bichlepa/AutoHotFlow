#Requires AutoHotkey v2.0

class Logger {
    static LogPath := A_AppData . "\AutoHotFlow\Log\Log.txt"

    static Log(source, message) {
        logDir := A_AppData . "\AutoHotFlow\Log"
        if !DirExist(logDir)
            DirExpand(logDir)

        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        entry := "[" . timestamp . "] [" . source . "] " . message . "`n"

        ; Async write queue simulation
        try {
            FileAppend(entry, Logger.LogPath, "UTF-8")
        } catch {
            ; Non-blocking fallback
        }
    }
}
