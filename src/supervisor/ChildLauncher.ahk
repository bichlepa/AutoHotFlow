#Requires AutoHotkey v2.0
#Include ..\core\Errors.ahk
#Include ChildPipe.ahk

; Starts a role process with its stdout and stderr redirected into an anonymous pipe (WI-0023).
; Run() cannot do that: a process started by Run has no usable stderr (F-0004), so load errors, the
; last words of a role and the reason for an early exit were lost. CreateProcessW can.
;
;   info := ChildLauncher.Start(commandLine)     ; Map: pid, process (handle), reader (ChildPipe)
;
; What happens (all through DllCall, doc/HOW-TO.md "CreateProcessW mit umgeleiteten Handles"):
;   - CreatePipe makes the pipe; the read end is made non-inheritable (SetHandleInformation), only the
;     write end is inheritable. stdout and stderr of the child are the same write end (one stream).
;   - stdin is the device NUL (inheritable), so the child never waits for input.
;   - PROC_THREAD_ATTRIBUTE_HANDLE_LIST names exactly these two handles: the child inherits nothing else,
;     in particular no pipe of the hub and no process handle of another child, whatever their flags are.
;   - The window is hidden (STARTF_USESHOWWINDOW, SW_HIDE) like with Run(..., "Hide").
;   - The write end and NUL are closed in the supervisor right after the start, the thread handle too.
; The caller owns the process handle and the reader and closes them (Children._OnGone).
class ChildLauncher {
    static PIPE_BUFFER := 262144          ; bytes the child can write before it has to wait for us
    static STARTUPINFOEX_SIZE := 112      ; 64-bit layout of STARTUPINFOEXW
    static EXTENDED_STARTUPINFO_PRESENT := 0x00080000
    static CREATE_UNICODE_ENVIRONMENT := 0x00000400
    static PROC_THREAD_ATTRIBUTE_HANDLE_LIST := 0x00020002
    static STARTF_USESHOWWINDOW := 0x1
    static STARTF_USESTDHANDLES := 0x100
    static HANDLE_FLAG_INHERIT := 0x1

    ; Throws AhfError (internal) when the process cannot be started; nothing is leaked then.
    static Start(commandLine) {
        sa := Buffer(24, 0)
        NumPut("uint", 24, sa, 0)
        NumPut("int", 1, sa, 16)                       ; bInheritHandle
        hRead := 0
        hWrite := 0
        if (!DllCall("CreatePipe", "ptr*", &hRead, "ptr*", &hWrite, "ptr", sa, "uint", ChildLauncher.PIPE_BUFFER))
            throw AhfError("CreatePipe failed (error " A_LastError ")", ErrCode.INTERNAL)
        hNul := 0
        attr := ""
        listed := false
        try {
            ; the read end stays with the supervisor only
            DllCall("SetHandleInformation", "ptr", hRead, "uint", ChildLauncher.HANDLE_FLAG_INHERIT, "uint", 0)
            hNul := DllCall("CreateFileW", "str", "NUL", "uint", 0x80000000, "uint", 3, "ptr", sa, "uint", 3
                , "uint", 0, "ptr", 0, "ptr")          ; GENERIC_READ, share read+write, OPEN_EXISTING
            if (hNul = -1) {
                hNul := 0
                throw AhfError("could not open NUL (error " A_LastError ")", ErrCode.INTERNAL)
            }
            attr := ChildLauncher._AttributeList([hWrite, hNul])
            listed := true
            si := Buffer(ChildLauncher.STARTUPINFOEX_SIZE, 0)
            NumPut("uint", ChildLauncher.STARTUPINFOEX_SIZE, si, 0)
            NumPut("uint", ChildLauncher.STARTF_USESHOWWINDOW | ChildLauncher.STARTF_USESTDHANDLES, si, 60)
            NumPut("ushort", 0, si, 64)                ; SW_HIDE
            NumPut("ptr", hNul, si, 80)                ; hStdInput
            NumPut("ptr", hWrite, si, 88)              ; hStdOutput
            NumPut("ptr", hWrite, si, 96)              ; hStdError
            NumPut("ptr", attr["buffer"].Ptr, si, 104)     ; lpAttributeList
            cmdBuf := Buffer((StrLen(commandLine) + 1) * 2, 0)   ; CreateProcessW may write into the command line
            StrPut(commandLine, cmdBuf, "UTF-16")
            pi := Buffer(24, 0)
            flags := ChildLauncher.EXTENDED_STARTUPINFO_PRESENT | ChildLauncher.CREATE_UNICODE_ENVIRONMENT
            ok := DllCall("CreateProcessW", "ptr", 0, "ptr", cmdBuf, "ptr", 0, "ptr", 0, "int", 1, "uint", flags
                , "ptr", 0, "ptr", 0, "ptr", si, "ptr", pi)
            err := A_LastError
            if (!ok)
                throw AhfError("CreateProcessW failed (error " err ")", ErrCode.INTERNAL)
        } catch as e {
            DllCall("CloseHandle", "ptr", hRead)
            ChildLauncher._Release(attr, listed, hWrite, hNul)
            throw e
        }
        ChildLauncher._Release(attr, listed, hWrite, hNul)
        DllCall("CloseHandle", "ptr", NumGet(pi, A_PtrSize, "ptr"))      ; hThread
        return Map("pid", NumGet(pi, 2 * A_PtrSize, "uint"), "process", NumGet(pi, 0, "ptr"), "reader", ChildPipe(hRead))
    }

    ; Builds the attribute list with PROC_THREAD_ATTRIBUTE_HANDLE_LIST for the given handles.
    ; Returns Map("buffer", Buffer of the list, "handles", Buffer of the handle array); both must live
    ; until CreateProcessW has returned.
    static _AttributeList(handleArray) {
        size := 0
        DllCall("InitializeProcThreadAttributeList", "ptr", 0, "uint", 1, "uint", 0, "uptr*", &size)   ; fails, sets size
        buf := Buffer(size, 0)
        if (!DllCall("InitializeProcThreadAttributeList", "ptr", buf, "uint", 1, "uint", 0, "uptr*", &size))
            throw AhfError("InitializeProcThreadAttributeList failed (error " A_LastError ")", ErrCode.INTERNAL)
        handles := Buffer(handleArray.Length * A_PtrSize, 0)
        for i, h in handleArray
            NumPut("ptr", h, handles, (i - 1) * A_PtrSize)
        if (!DllCall("UpdateProcThreadAttribute", "ptr", buf, "uint", 0, "uptr", ChildLauncher.PROC_THREAD_ATTRIBUTE_HANDLE_LIST
            , "ptr", handles, "uptr", handles.Size, "ptr", 0, "ptr", 0)) {
            err := A_LastError
            DllCall("DeleteProcThreadAttributeList", "ptr", buf)
            throw AhfError("UpdateProcThreadAttribute failed (error " err ")", ErrCode.INTERNAL)
        }
        return Map("buffer", buf, "handles", handles)
    }

    static _Release(attr, listed, hWrite, hNul) {
        if (listed)
            DllCall("DeleteProcThreadAttributeList", "ptr", attr["buffer"])
        DllCall("CloseHandle", "ptr", hWrite)
        if (hNul != 0)
            DllCall("CloseHandle", "ptr", hNul)
    }
}
