;by jNizM
;from http://ahkscript.org/boards/viewtopic.php?p=33959#p33959

MemoryLoad()
{
    static MEMORYSTATUSEX, init := VarSetCapacity(MEMORYSTATUSEX, 64, 0) && NumPut(64, MEMORYSTATUSEX, "UInt")
    if !(DllCall("Kernel32.dll\GlobalMemoryStatusEx", "Ptr", &MEMORYSTATUSEX))
        return DllCall("kernel32.dll\GetLastError")
    return NumGet(MEMORYSTATUSEX, 4, "UInt")
}