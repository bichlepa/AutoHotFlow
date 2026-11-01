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
    static CREATE_SUSPENDED := 0x00000004
    static JOB_KILL_ON_CLOSE := 0x00002000
    static INPUT_MAX := 262144            ; StartWithInput: largest input (bytes); the stdin pipe is this size plus 4 KB

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

    ; Starts a process whose stdin is filled once by the caller (the script host, WI-0130): input is written into the stdin
    ; pipe, then the write end is closed, so the child reads the input up to its end. stdout and stderr are two anonymous
    ; pipes with their own readers. The process runs in a job object with KILL_ON_JOB_CLOSE: when the caller closes the job
    ; handle (or the caller process dies), the process ends. The process is created suspended and joins the job before it runs.
    ; input is a Buffer of at most INPUT_MAX bytes (the pipe buffer holds it, so the write never waits).
    ;   info := ChildLauncher.StartWithInput(commandLine, input)  ; Map: pid, process, job, stdout, stderr (ChildPipe)
    static StartWithInput(commandLine, input) {
        if (input.Size > ChildLauncher.INPUT_MAX)
            throw AhfError("the input of " input.Size " bytes is larger than " ChildLauncher.INPUT_MAX, ErrCode.INTERNAL)
        sa := Buffer(24, 0)
        NumPut("uint", 24, sa, 0)
        NumPut("int", 1, sa, 16)                       ; bInheritHandle
        hInRead := 0, hInWrite := 0, hOutRead := 0, hOutWrite := 0, hErrRead := 0, hErrWrite := 0
        job := 0, attr := "", pi := 0
        try {
            if (!DllCall("CreatePipe", "ptr*", &hInRead, "ptr*", &hInWrite, "ptr", sa, "uint", ChildLauncher.INPUT_MAX + 4096))
                throw AhfError("CreatePipe (stdin) failed (error " A_LastError ")", ErrCode.INTERNAL)
            if (!DllCall("CreatePipe", "ptr*", &hOutRead, "ptr*", &hOutWrite, "ptr", sa, "uint", ChildLauncher.PIPE_BUFFER))
                throw AhfError("CreatePipe (stdout) failed (error " A_LastError ")", ErrCode.INTERNAL)
            if (!DllCall("CreatePipe", "ptr*", &hErrRead, "ptr*", &hErrWrite, "ptr", sa, "uint", ChildLauncher.PIPE_BUFFER))
                throw AhfError("CreatePipe (stderr) failed (error " A_LastError ")", ErrCode.INTERNAL)
            DllCall("SetHandleInformation", "ptr", hInWrite, "uint", ChildLauncher.HANDLE_FLAG_INHERIT, "uint", 0)
            DllCall("SetHandleInformation", "ptr", hOutRead, "uint", ChildLauncher.HANDLE_FLAG_INHERIT, "uint", 0)
            DllCall("SetHandleInformation", "ptr", hErrRead, "uint", ChildLauncher.HANDLE_FLAG_INHERIT, "uint", 0)
            job := DllCall("CreateJobObjectW", "ptr", 0, "ptr", 0, "ptr")
            if (job = 0)
                throw AhfError("CreateJobObjectW failed (error " A_LastError ")", ErrCode.INTERNAL)
            limits := Buffer(144, 0)                    ; JOBOBJECT_EXTENDED_LIMIT_INFORMATION, 64 bit
            NumPut("uint", ChildLauncher.JOB_KILL_ON_CLOSE, limits, 16)   ; BasicLimitInformation.LimitFlags
            if (!DllCall("SetInformationJobObject", "ptr", job, "int", 9, "ptr", limits, "uint", limits.Size))
                throw AhfError("SetInformationJobObject failed (error " A_LastError ")", ErrCode.INTERNAL)
            attr := ChildLauncher._AttributeList([hInRead, hOutWrite, hErrWrite])
            si := Buffer(ChildLauncher.STARTUPINFOEX_SIZE, 0)
            NumPut("uint", ChildLauncher.STARTUPINFOEX_SIZE, si, 0)
            NumPut("uint", ChildLauncher.STARTF_USESHOWWINDOW | ChildLauncher.STARTF_USESTDHANDLES, si, 60)
            NumPut("ushort", 0, si, 64)                ; SW_HIDE
            NumPut("ptr", hInRead, si, 80)
            NumPut("ptr", hOutWrite, si, 88)
            NumPut("ptr", hErrWrite, si, 96)
            NumPut("ptr", attr["buffer"].Ptr, si, 104)
            cmdBuf := Buffer((StrLen(commandLine) + 1) * 2, 0)
            StrPut(commandLine, cmdBuf, "UTF-16")
            pi := Buffer(24, 0)
            flags := ChildLauncher.EXTENDED_STARTUPINFO_PRESENT | ChildLauncher.CREATE_UNICODE_ENVIRONMENT | ChildLauncher.CREATE_SUSPENDED
            if (!DllCall("CreateProcessW", "ptr", 0, "ptr", cmdBuf, "ptr", 0, "ptr", 0, "int", 1, "uint", flags
                , "ptr", 0, "ptr", 0, "ptr", si, "ptr", pi))
                throw AhfError("CreateProcessW failed (error " A_LastError ")", ErrCode.INTERNAL)
            process := NumGet(pi, 0, "ptr")
            thread := NumGet(pi, A_PtrSize, "ptr")
            if (!DllCall("AssignProcessToJobObject", "ptr", job, "ptr", process)) {
                err := A_LastError
                DllCall("TerminateProcess", "ptr", process, "uint", 1)
                DllCall("CloseHandle", "ptr", thread)
                DllCall("CloseHandle", "ptr", process)
                throw AhfError("AssignProcessToJobObject failed (error " err ")", ErrCode.INTERNAL)
            }
            DllCall("ResumeThread", "ptr", thread)
            DllCall("CloseHandle", "ptr", thread)
        } catch as e {
            for h in [hInRead, hInWrite, hOutRead, hOutWrite, hErrRead, hErrWrite]
                if (h != 0)
                    DllCall("CloseHandle", "ptr", h)
            if (job != 0)
                DllCall("CloseHandle", "ptr", job)
            if (IsObject(attr))
                DllCall("DeleteProcThreadAttributeList", "ptr", attr["buffer"])
            throw e
        }
        ; the child's ends and the attribute list are no longer needed here
        DllCall("DeleteProcThreadAttributeList", "ptr", attr["buffer"])
        DllCall("CloseHandle", "ptr", hInRead)
        DllCall("CloseHandle", "ptr", hOutWrite)
        DllCall("CloseHandle", "ptr", hErrWrite)
        ChildLauncher._WriteAll(hInWrite, input)
        DllCall("CloseHandle", "ptr", hInWrite)
        return Map("pid", NumGet(pi, 2 * A_PtrSize, "uint"), "process", process, "job", job
            , "stdout", ChildPipe(hOutRead), "stderr", ChildPipe(hErrRead))
    }

    ; Closes the job of a process that ended by itself (WI-0130): the kill-on-close flag is cleared first, so the processes
    ; that the script started keep running, as in v1. A job that is still needed is closed by the caller with CloseHandle.
    static ReleaseJob(job) {
        if (job = 0)
            return
        limits := Buffer(144, 0)                    ; LimitFlags 0: no kill on close
        DllCall("SetInformationJobObject", "ptr", job, "int", 9, "ptr", limits, "uint", limits.Size)
        DllCall("CloseHandle", "ptr", job)
    }

    ; Writes all bytes of input to a pipe. The pipe buffer holds them (INPUT_MAX), so the call does not wait for the reader.
    static _WriteAll(handle, input) {
        written := 0
        if (input.Size = 0)
            return
        if (!DllCall("WriteFile", "ptr", handle, "ptr", input, "uint", input.Size, "uint*", &written, "ptr", 0)
            || written != input.Size)
            throw AhfError("could not write the input to the child (error " A_LastError ")", ErrCode.INTERNAL)
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
