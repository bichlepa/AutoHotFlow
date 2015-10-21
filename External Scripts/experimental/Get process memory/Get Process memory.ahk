;From http://www.autohotkey.com/board/topic/44824-finding-a-process-ram-memory-usage/

;=============================================================================================================
; Func: GetProcessMemory_All
; Get all Process Memory Usage Counters.  Mimics what's shown in Task Manager.
;
; Params:
;   ProcName    - Name of Process (e.g. Firefox.exe)
;
; Returns:
;   String with all values in KB as one big string.  Use a Regular Expression to parse out the value you want.
;-------------------------------------------------------------------------------------------------------------
GetProcessMemory_All(ProcName) {
    Process, Exist, %ProcName%
    pid := Errorlevel

    ; get process handle
    hProcess := DllCall( "OpenProcess", UInt, 0x10|0x400, Int, false, UInt, pid )

    ; get memory info
    PROCESS_MEMORY_COUNTERS_EX := VarSetCapacity(memCounters, 44, 0)
    DllCall( "psapi.dll\GetProcessMemoryInfo", UInt, hProcess, UInt, &memCounters, UInt, PROCESS_MEMORY_COUNTERS_EX )
    DllCall( "CloseHandle", UInt, hProcess )

    list := "cb,PageFaultCount,PeakWorkingSetSize,WorkingSetSize,QuotaPeakPagedPoolUsage"
          . ",QuotaPagedPoolUsage,QuotaPeakNonPagedPoolUsage,QuotaNonPagedPoolUsage"
          . ",PagefileUsage,PeakPagefileUsage,PrivateUsage"

    n := 0
    Loop, Parse, list, `,
    {
        n += 4
        SetFormat, Float, 0.0 ; round up K
        this := A_Loopfield
        this := NumGet( memCounters, (A_Index = 1 ? 0 : n-4), "UInt") / 1024

        ; omit cb
        If A_Index != 1
            info .= A_Loopfield . ": " . this . " K" . ( A_Loopfield != "" ? "`n" : "" )
    }

    Return "[" . pid . "] " . pname . "`n`n" . info ; for everything
}

Loop 1000
	ToolTip % GetProcessMemory_All(Task-Manager)