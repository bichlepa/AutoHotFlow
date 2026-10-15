#Requires AutoHotkey v2.0
; Unit tests for the access control of src/core/ipc/PipeListener.ahk (F-0017).
#Include lib\Assert.ahk
#Include ..\..\src\core\ipc\PipeListener.ahk

; Returns the DACL of the waiting pipe instance as an SDDL string.
DaclOf(listener) {
    need := 0
    DllCall("advapi32\GetKernelObjectSecurity", "ptr", listener._h, "uint", 4, "ptr", 0, "uint", 0, "uint*", &need)
    sd := Buffer(need, 0)
    if (!DllCall("advapi32\GetKernelObjectSecurity", "ptr", listener._h, "uint", 4, "ptr", sd, "uint", need, "uint*", &need))
        throw Error("GetKernelObjectSecurity failed: " A_LastError)
    pStr := 0
    if (!DllCall("advapi32\ConvertSecurityDescriptorToStringSecurityDescriptorW", "ptr", sd, "uint", 1, "uint", 4
        , "ptr*", &pStr, "ptr", 0))
        throw Error("ConvertSecurityDescriptorToStringSecurityDescriptorW failed: " A_LastError)
    s := StrGet(pStr, "UTF-16")
    DllCall("LocalFree", "ptr", pStr)
    return s
}

CheckNoBroadAccess() {
    l := PipeListener("ahf.sectest." A_TickCount)
    dacl := DaclOf(l)
    l.Close()
    for sid in ["WD", "AN", "BU", "IU", "AU", "NU"]
        Assert.True(!InStr(dacl, ";" sid ")"), "DACL grants access to " sid ": " dacl)
    Assert.True(InStr(dacl, ";SY)"), "system is missing in the DACL: " dacl)
}

CheckOwnerCanConnect() {
    name := "ahf.sectest." A_TickCount "b"
    l := PipeListener(name)
    ; GENERIC_READ | GENERIC_WRITE, OPEN_EXISTING
    h := DllCall("CreateFileW", "str", PipeConnection.FullName(name), "uint", 0xC0000000, "uint", 0, "ptr", 0
        , "uint", 3, "uint", 0, "ptr", 0, "ptr")
    err := A_LastError
    if (h != -1)
        DllCall("CloseHandle", "ptr", h)
    l.Close()
    Assert.True(h != -1, "the owner cannot open the pipe (error " err ")")
}

TestRun.Init()

TestRun.Case("The pipe grants nothing to Everyone, anonymous, users or other broad groups", CheckNoBroadAccess)
TestRun.Case("The user who created the pipe can still connect with read and write", CheckOwnerCanConnect)

TestRun.Finish()
