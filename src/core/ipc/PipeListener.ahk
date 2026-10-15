#Requires AutoHotkey v2.0
#Include ..\Errors.ahk
#Include PipeConnection.ahk

; Server side of a named pipe: always keeps exactly one instance waiting for a client.
;
;   listener := PipeListener("ahf.<session>.hub")
;   while (conn := listener.Accept()) {   ; non blocking, "" if nobody connected
;       ...
;   }
;   listener.Close()
;
; The first instance is created with FILE_FLAG_FIRST_PIPE_INSTANCE, so creating a listener on a
; name that is already served (another supervisor, a squatter) throws instead of sharing it.
class PipeListener {
    static BUFFER_SIZE := 65536
    ; Protected DACL: full access for the system (SY) and the owner (OW), nobody else.
    static SDDL := "D:P(A;;GA;;;SY)(A;;GA;;;OW)"

    __New(pipeName) {
        this.Name := PipeConnection.FullName(pipeName)
        this._h := 0
        this._ev := 0
        this._ov := ""
        this._connected := false      ; ConnectNamedPipe finished synchronously (client was already there)
        this._first := true
        this._closed := false
        this._CreateInstance()
    }

    IsOpen => !this._closed

    ; Returns a PipeConnection when a client has connected, otherwise "". Then immediately creates
    ; the next waiting instance, so the name never has a gap in which a client sees "not found".
    Accept() {
        if (this._closed)
            return ""
        if (this._h = 0) {
            try {
                this._CreateInstance()
            } catch {
                return ""
            }
        }
        if (!this._connected) {
            if (DllCall("WaitForSingleObject", "ptr", this._ev, "uint", 0) != 0)
                return ""
            n := 0
            ok := DllCall("GetOverlappedResult", "ptr", this._h, "ptr", this._ov, "uint*", &n, "int", 0)
            if (!ok) {
                ; The connect attempt failed (a client came and went): start over on a new instance.
                this._DropInstance()
                return ""
            }
        }
        oldHandle := this._h
        oldEvent := this._ev
        this._h := 0
        this._ev := 0
        this._connected := false
        try {
            this._CreateInstance()
        } catch as e {
            ; Keep serving the client we have. The next Accept tries again.
            Log.Write("a0", "ipc", "PipeListener " this.Name ": next instance failed: " e.Message)
        }
        DllCall("CloseHandle", "ptr", oldEvent)
        return PipeConnection(oldHandle, this.Name)
    }

    ; Closes the waiting instance. Connections that were accepted are not affected.
    Close() {
        if (this._closed)
            return
        this._closed := true
        this._DropInstance()
    }

    _CreateInstance() {
        ; PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED (| FILE_FLAG_FIRST_PIPE_INSTANCE for the first)
        openMode := 0x40000003 | (this._first ? 0x00080000 : 0)
        ; PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS
        ; Explicit DACL (F-0017): only the owner of the pipe (the user of this process) and the system
        ; get access. The default DACL would give read access to Everyone and anonymous.
        psd := 0
        if (!DllCall("advapi32\ConvertStringSecurityDescriptorToSecurityDescriptorW"
            , "str", PipeListener.SDDL, "uint", 1, "ptr*", &psd, "ptr", 0))
            throw AhfError("PipeListener: cannot build the security descriptor for " this.Name " (error " A_LastError ")", ErrCode.INTERNAL)
        ; SECURITY_ATTRIBUTES: DWORD nLength; LPVOID lpSecurityDescriptor; BOOL bInheritHandle
        sa := Buffer(A_PtrSize = 8 ? 24 : 12, 0)
        NumPut("uint", sa.Size, sa, 0)
        NumPut("ptr", psd, sa, A_PtrSize)
        h := DllCall("CreateNamedPipeW", "str", this.Name, "uint", openMode, "uint", 0x8
            , "uint", 255, "uint", PipeListener.BUFFER_SIZE, "uint", PipeListener.BUFFER_SIZE
            , "uint", 0, "ptr", sa, "ptr")
        err := A_LastError
        DllCall("LocalFree", "ptr", psd)
        if (h = -1 || h = 0)
            throw AhfError("PipeListener: CreateNamedPipeW failed for " this.Name " (error " err ")", ErrCode.INTERNAL)
        this._first := false
        ev := DllCall("CreateEventW", "ptr", 0, "int", 1, "int", 0, "ptr", 0, "ptr")
        ov := Buffer(4 * 8, 0)
        NumPut("ptr", ev, ov, 2 * A_PtrSize + 8)
        ok := DllCall("ConnectNamedPipe", "ptr", h, "ptr", ov)
        err := A_LastError
        this._connected := false
        if (!ok && err = 535) {             ; ERROR_PIPE_CONNECTED: the client was faster than us
            this._connected := true
        } else if (!ok && err != 997) {     ; anything but ERROR_IO_PENDING
            DllCall("CloseHandle", "ptr", ev)
            DllCall("CloseHandle", "ptr", h)
            throw AhfError("PipeListener: ConnectNamedPipe failed for " this.Name " (error " err ")", ErrCode.INTERNAL)
        }
        this._h := h
        this._ev := ev
        this._ov := ov
    }

    ; Cancels the pending connect and releases the handles of the waiting instance.
    _DropInstance() {
        if (this._h != 0) {
            DllCall("CancelIoEx", "ptr", this._h, "ptr", 0)
            if (!this._connected)
                DllCall("WaitForSingleObject", "ptr", this._ev, "uint", 1000)
            DllCall("CloseHandle", "ptr", this._h)
            DllCall("CloseHandle", "ptr", this._ev)
        }
        this._h := 0
        this._ev := 0
        this._connected := false
    }
}
