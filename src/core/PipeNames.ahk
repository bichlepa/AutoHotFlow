#Requires AutoHotkey v2.0
#Include Errors.ahk

; The names the supervisor and the second instance use to find each other (WI-22 point 5, doc/PROTOKOLL.md 1).
; One place for all of them: the roles do not build the hub name, they get it with --hub=<name>.
;
;   PipeNames.Hub("main")     -> "ahf.s1.u1a2b3c4d.main.hub"
;   PipeNames.Mutex("main")   -> "Local\AHF.supervisor.main"
;
; Named pipes live in one namespace for the whole machine, mutexes in one per Windows session ("Local\").
; With the plain name "ahf.<session>.hub" a second user (fast user switching, terminal server) found no
; mutex of the first one, tried to serve the same pipe name and failed. The pipe name therefore carries the
; Windows session id and a short tag of the user (FNV-1a hash of the user SID, 8 hex digits).
; The Python twin of the pipe name is tests/support/pipenames.py.
class PipeNames {
    static Hub(session) => "ahf.s" PipeNames.WindowsSession() ".u" PipeNames.UserTag() "." session ".hub"

    ; Explicit "Local\" so that the scope does not depend on the defaults of the process.
    static Mutex(session) => "Local\AHF.supervisor." session

    ; Id of the Windows session of this process (0 = services session, 1 or more = interactive users).
    static WindowsSession() {
        id := 0
        if (!DllCall("ProcessIdToSessionId", "uint", DllCall("GetCurrentProcessId", "uint"), "uint*", &id, "int"))
            return 0
        return id
    }

    ; 8 hex digits identifying the user. Falls back to the user name if the SID cannot be read.
    static UserTag() {
        text := PipeNames.UserSidText()
        if (text = "")
            text := A_ComputerName "\" A_UserName
        h := 0x811C9DC5
        loop parse, text
            h := ((h ^ Ord(A_LoopField)) * 0x01000193) & 0xFFFFFFFF
        return Format("{:08x}", h)
    }

    ; "S-1-5-21-..." of the user of this process, "" on failure.
    static UserSidText() {
        token := 0
        if (!DllCall("advapi32\OpenProcessToken", "ptr", DllCall("GetCurrentProcess", "ptr"), "uint", 0x8
            , "ptr*", &token, "int"))
            return ""
        try {
            need := 0
            DllCall("advapi32\GetTokenInformation", "ptr", token, "int", 1, "ptr", 0, "uint", 0, "uint*", &need, "int")
            if (need = 0)
                return ""
            buf := Buffer(need)
            if (!DllCall("advapi32\GetTokenInformation", "ptr", token, "int", 1, "ptr", buf, "uint", need
                , "uint*", &need, "int"))
                return ""
            pText := 0
            if (!DllCall("advapi32\ConvertSidToStringSidW", "ptr", NumGet(buf, 0, "ptr"), "ptr*", &pText, "int"))
                return ""
            text := StrGet(pText, "UTF-16")
            DllCall("LocalFree", "ptr", pText)
            return text
        } finally {
            DllCall("CloseHandle", "ptr", token)
        }
    }
}
