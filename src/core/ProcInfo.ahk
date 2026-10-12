#Requires AutoHotkey v2.0
#Include Errors.ahk
#Include AhfVersion.ahk

; Facts about the own process, for the snapshot (doc/PROTOCOL.md 4.9). Every call is a quick Windows API
; call on the pseudo handle of the current process; nothing blocks and nothing throws (a failed call gives 0).
;
;   ProcInfo.Rss()         working set in bytes (GetProcessMemoryInfo)
;   ProcInfo.Handles()     number of open handles (GetProcessHandleCount)
;   ProcInfo.StartedAt()   process start, UTC, "yyyy-MM-dd HH:mm:ss" (GetProcessTimes)
;   ProcInfo.UptimeMs()    milliseconds since the process start
;   ProcInfo.General()     Map: pid, startedAt, uptimeMs, version, ahkVersion, bits, rssBytes, handles
class ProcInfo {
    ; PROCESS_MEMORY_COUNTERS on 64 bit: cb(4) PageFaultCount(4) then eight SIZE_T; WorkingSetSize is the 4th field.
    static COUNTERS_SIZE := 72
    static WORKING_SET_OFFSET := 16
    ; 100 ns units between 1601-01-01 (FILETIME) and the second.
    static TICKS_PER_SECOND := 10000000

    static Rss() {
        buf := Buffer(ProcInfo.COUNTERS_SIZE, 0)
        NumPut("uint", ProcInfo.COUNTERS_SIZE, buf, 0)
        if (!DllCall("psapi\GetProcessMemoryInfo", "ptr", DllCall("GetCurrentProcess", "ptr"), "ptr", buf
            , "uint", ProcInfo.COUNTERS_SIZE, "int"))
            return 0
        return NumGet(buf, ProcInfo.WORKING_SET_OFFSET, "uptr")
    }

    static Handles() {
        count := 0
        if (!DllCall("GetProcessHandleCount", "ptr", DllCall("GetCurrentProcess", "ptr"), "uint*", &count, "int"))
            return 0
        return count
    }

    ; FILETIME of the creation of this process as an Integer (100 ns since 1601), 0 when the call fails.
    static CreationTicks() {
        created := Buffer(8, 0)
        other := Buffer(8, 0)
        if (!DllCall("GetProcessTimes", "ptr", DllCall("GetCurrentProcess", "ptr"), "ptr", created, "ptr", other
            , "ptr", other, "ptr", other, "int"))
            return 0
        return NumGet(created, 0, "int64")
    }

    static NowTicks() {
        now := Buffer(8, 0)
        DllCall("GetSystemTimeAsFileTime", "ptr", now)
        return NumGet(now, 0, "int64")
    }

    static StartedAt() {
        ticks := ProcInfo.CreationTicks()
        if (ticks <= 0)
            return ""
        return FormatTime(DateAdd("16010101000000", ticks // ProcInfo.TICKS_PER_SECOND, "Seconds"), "yyyy-MM-dd HH:mm:ss")
    }

    static UptimeMs() {
        ticks := ProcInfo.CreationTicks()
        if (ticks <= 0)
            return 0
        return Max(0, (ProcInfo.NowTicks() - ticks) // 10000)
    }

    static General() {
        return Map("pid", DllCall("GetCurrentProcessId", "uint"), "startedAt", ProcInfo.StartedAt()
            , "uptimeMs", ProcInfo.UptimeMs(), "version", AhfVersion.Current, "ahkVersion", A_AhkVersion
            , "bits", A_PtrSize * 8, "rssBytes", ProcInfo.Rss(), "handles", ProcInfo.Handles())
    }
}
