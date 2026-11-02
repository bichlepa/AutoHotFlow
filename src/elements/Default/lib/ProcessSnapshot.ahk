#Requires AutoHotkey v2.0

; The process list of the trigger host (WI-0132, Trigger_Process_starts and Trigger_Process_closes): the process IDs
; and base names of the processes that can be opened with PROCESS_QUERY_LIMITED_INFORMATION. It replaces the list of v1
; (Source_Elements/Default/lib/Process list, EnumProcesses with the debug privilege); a process that cannot be opened
; is missing from the list, so a protected process is neither seen starting nor closing (MIGRATION M-0176).
class ProcessSnapshot {
    static MAX_PROCESSES := 4096          ; room for the array of EnumProcesses (DWORDs); more than the machine has

    ; The processes now running: a Map pid -> base name (for example "notepad.exe"). An empty Map if the list cannot be
    ; read.
    static Take() {
        list := Map()
        buf := Buffer(ProcessSnapshot.MAX_PROCESSES * 4, 0)
        needed := 0
        if (!DllCall("Psapi.dll\EnumProcesses", "Ptr", buf, "UInt", buf.Size, "UInt*", &needed))
            return list
        count := Min(needed // 4, ProcessSnapshot.MAX_PROCESSES)
        Loop count {
            pid := NumGet(buf, (A_Index - 1) * 4, "UInt")
            if (pid = 0)
                continue
            name := ProcessSnapshot._NameOf(pid)
            if (name != "")
                list[pid] := name
        }
        return list
    }

    ; The processes of a snapshot that match a filter: "" matches every process, a text matches the base name (not
    ; case-sensitive, as AutoHotkey compares names) or the process ID. Returns a Map pid -> base name.
    static Matching(snapshot, filter) {
        found := Map()
        for pid, name in snapshot {
            if (filter = "" || name = filter || pid = filter)
                found[pid] := name
        }
        return found
    }

    ; The base name of a process, "" when it cannot be opened or its image name cannot be read. The handle is closed
    ; in every case.
    static _NameOf(pid) {
        h := DllCall("OpenProcess", "UInt", 0x1000, "Int", 0, "UInt", pid, "Ptr")     ; PROCESS_QUERY_LIMITED_INFORMATION
        if (!h)
            return ""
        try {
            size := 1024
            path := Buffer(size * 2, 0)
            if (!DllCall("Kernel32\QueryFullProcessImageNameW", "Ptr", h, "UInt", 0, "Ptr", path, "UInt*", &size))
                return ""
            SplitPath(StrGet(path, size, "UTF-16"), &name)
            return name
        } finally {
            DllCall("CloseHandle", "Ptr", h)
        }
    }
}
