#Requires AutoHotkey v2.0
#Include ..\Errors.ahk
#Include ..\Log.ahk
#Include ..\Time.ahk
#Include Frame.ahk

; One end of a named pipe connection (byte mode, overlapped I/O), used by clients and by the hub.
; Never blocks: reads and writes are overlapped, completion is polled with bWait = false.
;
;   conn := PipeConnection.Connect(name, 3000)      ; client side
;   conn := listener.Accept()                       ; server side (PipeListener)
;   conn.OnFrame := (conn, text) => ...
;   conn.OnClose := (conn, reason) => ...           ; once; reason see below
;   conn.SendFrame(text)  -> true | false
;   conn.Pump()           ; called on wake and by the fallback timer (see Wake.ahk)
;   conn.CloseWhenFlushed(1000, (flushed) => ExitApp())   ; end after the send queue is written (WI-30)
;
; Close reasons: "peer_closed" (end of stream, the normal end), "broken" (I/O error),
; "queue_overflow" (send queue limit hit), "protocol_error" (bad frame header), "local" (Close()).
;
; Ending: Close() drops what waits in the send queue (only frames already written into the pipe stay readable for
; the peer). The last frames of a process (its events, sys.bye) are ended with CloseWhenFlushed instead.
; A peer that has gone may have left frames in the pipe that are not read yet (its sys.bye). A write that fails
; because the peer is gone therefore closes only the write side (the send queue is dropped, SendFrame refuses);
; reading goes on to the end of the stream, which closes the connection with "peer_closed" (WI-30, F-26).
class PipeConnection {
    static WAKE_MESSAGE := 0x8001
    ; Reads handled in one Pump before it yields (64 KiB each). Bounds the time a busy peer can
    ; keep the message loop away; the rest is picked up by a follow-up timer.
    static MAX_READS_PER_PUMP := 64
    ; Period of the timer that writes the send queue while CloseWhenFlushed waits (the timer resolution is ~15.6 ms).
    static DRAIN_POLL_MS := 10
    ; After a write found the peer gone, the rest of its frames is read; the end of the stream follows at once
    ; (the peer's handle is closed). Should it not come, the connection is closed this long after (a Pump checks it).
    static WRITE_GONE_MAX_MS := 1000
    ; Handles whose I/O could not be confirmed as cancelled stay referenced here, so the memory
    ; the kernel may still write to is never freed.
    static _graveyard := []

    OnFrame := ""
    OnClose := ""
    PeerHwnd := 0
    maxQueueBytes := 8 * 1024 * 1024
    maxQueueFrames := 1000
    handlerErrors := 0
    ; Name the connection was created with (for log lines).
    Name := ""

    ; Use PipeConnection.Connect() or PipeListener.Accept(). `handle` is a pipe handle opened with
    ; FILE_FLAG_OVERLAPPED; the connection owns it from here on.
    __New(handle, name := "") {
        this._h := handle
        this.Name := name
        this._open := true
        this._closeReason := ""
        this._closeNotified := false
        this._reader := FrameReader()
        this._readBuf := Buffer(65536)
        this._readOv := Buffer(4 * 8, 0)
        this._readEv := DllCall("CreateEventW", "ptr", 0, "int", 1, "int", 0, "ptr", 0, "ptr")
        NumPut("ptr", this._readEv, this._readOv, 2 * A_PtrSize + 8)   ; OVERLAPPED.hEvent
        this._readPending := false
        this._writeOv := Buffer(4 * 8, 0)
        this._writeEv := DllCall("CreateEventW", "ptr", 0, "int", 1, "int", 0, "ptr", 0, "ptr")
        NumPut("ptr", this._writeEv, this._writeOv, 2 * A_PtrSize + 8)
        this._writePending := false
        this._writeOffset := 0         ; bytes of queue[1] already written
        this._queue := []              ; frames (Buffer); queue[1] is the one being written
        this._queueBytes := 0
        this._pumping := false
        this._pumpAgain := false
        this._writing := false
        this._writeAgain := false
        this._pollFn := ObjBindMethod(this, "Pump")
        this._notifyFn := ObjBindMethod(this, "_NotifyClose")
        this._draining := false        ; CloseWhenFlushed runs: no new frames
        this._drainFn := ""            ; its timer (a bound method: a cycle, broken when the drain ends)
        this._drainDone := ""          ; its callback, "" once it has been called
        this._drainUntil := 0
        this._drainStart := 0
        this._writeGoneAt := 0         ; Time.NowMs() when a write found the peer gone (write side closed), else 0
    }

    IsOpen => this._open
    IsDraining => this._draining
    QueuedBytes => this._queueBytes
    QueuedFrames => this._queue.Length
    CloseReason => this._closeReason

    ; "\\.\pipe\" + name. A name that already has the prefix is returned unchanged.
    static FullName(name) {
        bs := Chr(92)
        prefix := bs bs "." bs "pipe" bs
        return (SubStr(name, 1, StrLen(prefix)) = prefix) ? name : prefix name
    }

    ; Opens the client end. Retries while the server does not exist yet (ERROR_FILE_NOT_FOUND) or
    ; has no free instance (ERROR_PIPE_BUSY), for at most timeoutMs. Does not pump messages: the
    ; waits are kernel sleeps (DllCall Sleep), not AHK's Sleep. Throws AhfTimeoutError on timeout.
    static Connect(pipeName, timeoutMs := 3000) {
        full := PipeConnection.FullName(pipeName)
        start := Time.NowMs()
        loop {
            ; GENERIC_READ|GENERIC_WRITE, no sharing, OPEN_EXISTING, FILE_FLAG_OVERLAPPED
            h := DllCall("CreateFileW", "str", full, "uint", 0xC0000000, "uint", 0, "ptr", 0
                , "uint", 3, "uint", 0x40000000, "ptr", 0, "ptr")
            err := A_LastError
            if (h != -1 && h != 0)
                return PipeConnection(h, full)
            if (err != 2 && err != 231)
                throw AhfError("PipeConnection.Connect: CreateFileW failed for " full " (error " err ")", ErrCode.INTERNAL)
            remaining := timeoutMs - (Time.NowMs() - start)
            if (remaining <= 0)
                throw AhfTimeoutError("PipeConnection.Connect: " full " not available after " timeoutMs " ms (error " err ")")
            if (err = 231)
                DllCall("WaitNamedPipeW", "str", full, "uint", Min(Ceil(remaining), 50))
            else
                DllCall("Sleep", "uint", Min(Ceil(remaining), 10))
        }
    }

    ; Queues a frame and tries to write at once. Never blocks.
    ; Returns false if the connection is closed or ending (CloseWhenFlushed), or the queue limit was hit; in the
    ; latter case the connection is closed with reason "queue_overflow" and OnClose is raised right after the
    ; current call stack unwinds (not inside this call, so the caller's loop is not re-entered).
    ; Throws ProtocolError if the text is empty or larger than the frame limit (programming error).
    SendFrame(text) {
        if (!this._open || this._draining || this._writeGoneAt)
            return false
        frame := FrameWriter.Encode(text)
        size := frame.Size
        ; Reap writes the kernel has already finished, so frames the peer has read do not count
        ; as backlog just because nobody pumped yet.
        if (this._queue.Length > 0) {
            reason := this._DriveWriteGuarded()
            if (reason != "") {
                this._Fail(reason, true)
                return false
            }
        }
        ; The frame being written (queue[1]) is bounded by the frame limit and is the kernel's
        ; business; the limit applies to what waits behind it. A frame is accepted while that
        ; backlog is below maxQueueBytes, so one large frame can always be sent, and memory is
        ; bounded by the head frame plus maxQueueBytes plus one frame.
        backlog := (this._queue.Length > 0) ? this._queueBytes - this._queue[1].Size : 0
        if (this._queue.Length >= this.maxQueueFrames || backlog >= this.maxQueueBytes) {
            this._Fail("queue_overflow", true)
            return false
        }
        this._queue.Push(frame)
        this._queueBytes += size
        reason := this._DriveWriteGuarded()
        if (reason != "") {
            this._Fail(reason, true)
            return false
        }
        if (this._writeGoneAt)
            return false                        ; the peer is gone, the frame was dropped (see _WriteSideGone)
        if (this.PeerHwnd != 0)
            DllCall("PostMessageW", "ptr", this.PeerHwnd, "uint", PipeConnection.WAKE_MESSAGE, "ptr", 0, "ptr", 0)
        if (this._queue.Length > 0)
            SetTimer(this._pollFn, -1)
        return true
    }

    ; Completes finished reads and writes. Calls OnFrame per complete frame and OnClose once.
    ; Re-entrant calls (from a handler, or an interrupting wake) only mark "pump again".
    Pump() {
        ; Critical only around the guard, so that checking and setting the flag cannot be
        ; interrupted by another thread (wake message, timer). Restored right away.
        prev := Critical("On")
        if (!this._open || this._pumping) {
            if (this._open)
                this._pumpAgain := true
            Critical(prev)
            return
        }
        this._pumping := true
        Critical(prev)
        try {
            loop {
                this._pumpAgain := false
                reason := this._PumpRead()
                if (reason = "" && this._open) {
                    reason := this._DriveWriteGuarded()
                }
                if (reason = "" && this._open && this._writeGoneAt
                    && Time.NowMs() - this._writeGoneAt >= PipeConnection.WRITE_GONE_MAX_MS)
                    reason := "peer_closed"         ; the end of the stream did not come (see WRITE_GONE_MAX_MS)
                if (reason != "")
                    this._Fail(reason, false)
                if (!this._open)
                    break
                prev := Critical("On")  ; reason: reading _pumpAgain and clearing _pumping must not be interrupted
                again := this._pumpAgain
                if (!again)
                    this._pumping := false
                Critical(prev)
                if (!again)
                    break
            }
        } finally {
            this._pumping := false
        }
        if (this._open && this._queue.Length > 0)
            SetTimer(this._pollFn, -1)
    }

    ; Idempotent. Cancels pending I/O, closes the handles, drops queued frames (frames already
    ; written to the pipe stay readable for the peer) and raises OnClose("local") once.
    Close() {
        if (!this._open)
            return
        this._Fail("local", false)
    }

    ; Ends the connection after the send queue is written (WI-30): the last frames of a process (its events, sys.bye)
    ; must not be dropped as Close drops them. From now on SendFrame refuses new frames. A timer (DRAIN_POLL_MS)
    ; writes the queue on; the connection is closed with Close (OnClose "local") as soon as the queue is empty, or
    ; when timeoutMs has passed (the rest is dropped), or earlier with the reason of an I/O error (peer gone).
    ; Never blocks and never waits without a limit: no FlushFileBuffers (it waits for the reader of the pipe without
    ; any limit). Frames written into the pipe stay readable for the peer after the close.
    ; onDone(flushed) is called exactly once, from the timer and never inside this call; flushed is true when every
    ; queued frame was written. Pump keeps working meanwhile (incoming frames still reach OnFrame).
    ; Returns false (and never calls onDone) when the connection is closed already or an end is already running.
    CloseWhenFlushed(timeoutMs, onDone := "") {
        if (!this._open || this._draining)
            return false
        this._draining := true
        this._drainDone := IsObject(onDone) ? onDone : ""
        this._drainStart := Time.NowMs()
        this._drainUntil := this._drainStart + Max(0, timeoutMs)
        this._drainFn := ObjBindMethod(this, "_Drain")
        ; Collect what the kernel has finished and start the next write now; the decision waits for the timer,
        ; so onDone never runs inside the caller.
        reason := this._DriveWriteGuarded()
        if (reason != "")
            this._Fail(reason, true)
        SetTimer(this._drainFn, PipeConnection.DRAIN_POLL_MS)
        return true
    }

    ; --- internals ---------------------------------------------------------------------------

    ; Timer of CloseWhenFlushed: writes on, and ends the connection once the queue is empty or the time is up.
    _Drain() {
        if (!this._draining || !IsObject(this._drainFn))
            return
        if (this._open) {
            reason := this._DriveWriteGuarded()
            if (reason != "")
                this._Fail(reason, false)
            else if (this._queue.Length > 0 && Time.NowMs() < this._drainUntil)
                return                              ; the peer has not read enough yet: try again on the next tick
        }
        flushed := this._open && !this._writeGoneAt && this._queue.Length = 0
        if (this._open && !flushed)
            Log.Write("a1", "ipc", "closing " this.Name " with " this._queue.Length " frames unwritten after "
                . Round(Time.NowMs() - this._drainStart) " ms")
        SetTimer(this._drainFn, 0)
        this._drainFn := ""                         ; breaks the cycle object -> bound method -> object (F-07)
        this.Close()
        cb := this._drainDone
        this._drainDone := ""
        if (!IsObject(cb))
            return
        try {
            cb(flushed)
        } catch as e {
            this.handlerErrors += 1
            Log.Write("a0", "ipc", "CloseWhenFlushed callback failed: " Type(e) ": " e.Message)
        }
    }

    ; Reads what has completed. Returns "" or a close reason (not yet applied).
    _PumpRead() {
        reads := 0
        while (this._open) {
            if (!this._readPending) {
                reason := this._StartRead()
                if (reason != "")
                    return reason
            }
            got := 0
            ok := DllCall("GetOverlappedResult", "ptr", this._h, "ptr", this._readOv, "uint*", &got, "int", 0)
            err := A_LastError
            if (!ok) {
                if (err = 996)              ; ERROR_IO_INCOMPLETE: nothing there yet
                    return ""
                this._readPending := false
                return PipeConnection._ReasonForError(err)
            }
            this._readPending := false
            if (got = 0)                    ; end of stream in byte mode
                return "peer_closed"
            this._reader.Feed(this._readBuf, got)
            try {
                loop {
                    text := this._reader.Next()
                    if (text = "")
                        break
                    this._Deliver(text)
                    if (!this._open)
                        return ""
                }
            } catch ProtocolError as e {
                Log.Write("a0", "ipc", "protocol error on " this.Name ": " e.Message)
                return "protocol_error"
            }
            reads += 1
            if (reads >= PipeConnection.MAX_READS_PER_PUMP) {
                SetTimer(this._pollFn, -1)  ; yield to the message loop, continue right after
                return ""
            }
        }
        return ""
    }

    _StartRead() {
        DllCall("ResetEvent", "ptr", this._readEv)
        ok := DllCall("ReadFile", "ptr", this._h, "ptr", this._readBuf, "uint", this._readBuf.Size
            , "ptr", 0, "ptr", this._readOv)
        err := A_LastError
        if (!ok && err != 997)              ; ERROR_IO_PENDING is the normal case
            return PipeConnection._ReasonForError(err)
        this._readPending := true
        return ""
    }

    ; Serialises the write path (SendFrame can be interrupted by a Pump thread and vice versa).
    _DriveWriteGuarded() {
        prev := Critical("On")  ; reason: checking and setting _writing must not be interrupted
        if (this._writing) {
            this._writeAgain := true
            Critical(prev)
            return ""
        }
        this._writing := true
        Critical(prev)
        reason := ""
        try {
            loop {
                this._writeAgain := false
                reason := this._DriveWrite()
                if (reason = "peer_closed") {
                    this._WriteSideGone()
                    reason := ""
                    break
                }
                if (reason != "" || !this._open)
                    break
                prev := Critical("On")  ; reason: reading _writeAgain and clearing _writing must not be interrupted
                again := this._writeAgain
                if (!again)
                    this._writing := false
                Critical(prev)
                if (!again)
                    break
            }
        } finally {
            this._writing := false
        }
        return reason
    }

    ; A write found the peer gone. Its last frames may still lie unread in the pipe: only the write side is closed
    ; (the queue cannot be written any more and is dropped); a Pump reads on to the end of the stream.
    _WriteSideGone() {
        if (this._writeGoneAt)
            return
        this._writeGoneAt := Time.NowMs()
        this._writePending := false
        this._writeOffset := 0
        this._queue := []
        this._queueBytes := 0
        if (IsObject(this._pollFn))
            SetTimer(this._pollFn, -1)
    }

    ; Writes queued frames while the pipe accepts them. Returns "" or a close reason.
    _DriveWrite() {
        while (this._open && !this._writeGoneAt && this._queue.Length > 0) {
            buf := this._queue[1]
            if (!this._writePending) {
                DllCall("ResetEvent", "ptr", this._writeEv)
                ok := DllCall("WriteFile", "ptr", this._h, "ptr", buf.Ptr + this._writeOffset
                    , "uint", buf.Size - this._writeOffset, "ptr", 0, "ptr", this._writeOv)
                err := A_LastError
                if (!ok && err != 997)
                    return PipeConnection._ReasonForError(err)
                this._writePending := true
            }
            n := 0
            ok := DllCall("GetOverlappedResult", "ptr", this._h, "ptr", this._writeOv, "uint*", &n, "int", 0)
            err := A_LastError
            if (!ok) {
                if (err = 996)              ; still pending: the peer has not read enough yet
                    return ""
                this._writePending := false
                return PipeConnection._ReasonForError(err)
            }
            this._writePending := false
            this._writeOffset += n
            if (this._writeOffset >= buf.Size) {
                this._queue.RemoveAt(1)
                this._queueBytes -= buf.Size
                this._writeOffset := 0
            }
        }
        return ""
    }

    ; 109 (broken pipe), 232 (pipe is being closed) and 233 (no process on the other end) mean the
    ; peer is gone, which is a normal end. Everything else is an I/O error.
    static _ReasonForError(err) {
        return (err = 109 || err = 232 || err = 233) ? "peer_closed" : "broken"
    }

    ; Closes the connection and raises OnClose, immediately or after the current thread.
    _Fail(reason, deferNotify) {
        if (!this._open)
            return
        this._Teardown(reason)
        if (deferNotify)
            SetTimer(this._notifyFn, -1)
        else
            this._NotifyClose()
    }

    _Teardown(reason) {
        this._open := false
        this._closeReason := reason
        SetTimer(this._pollFn, 0)
        ; Break the cycle object -> bound method -> object (AHK counts references, so it would never
        ; be freed). The timer is off, nothing schedules the poll again while the connection is closed.
        this._pollFn := ""
        ; Cancel everything that is outstanding on this handle. Buffers must stay valid until the
        ; kernel has finished with them, so wait (bounded) for the cancelled operations.
        DllCall("CancelIoEx", "ptr", this._h, "ptr", 0)
        stuck := false
        if (this._readPending && DllCall("WaitForSingleObject", "ptr", this._readEv, "uint", 2000) != 0)
            stuck := true
        if (this._writePending && DllCall("WaitForSingleObject", "ptr", this._writeEv, "uint", 2000) != 0)
            stuck := true
        if (stuck)
            PipeConnection._graveyard.Push([this._readBuf, this._readOv, this._writeOv, this._queue])
        DllCall("CloseHandle", "ptr", this._h)
        DllCall("CloseHandle", "ptr", this._readEv)
        DllCall("CloseHandle", "ptr", this._writeEv)
        this._readPending := false
        this._writePending := false
        this._queue := []
        this._queueBytes := 0
        this._reader.Reset()
    }

    _NotifyClose() {
        if (this._closeNotified)
            return
        this._closeNotified := true
        ; The notify timer (if any) has fired or is being run by this call: drop the self reference.
        this._notifyFn := ""
        handler := this.OnClose
        if (!IsObject(handler))
            return
        try {
            handler(this, this._closeReason)
        } catch as e {
            this.handlerErrors += 1
            Log.Write("a0", "ipc", "OnClose handler failed: " Type(e) ": " e.Message)
        }
    }

    _Deliver(text) {
        handler := this.OnFrame
        if (!IsObject(handler))
            return
        try {
            handler(this, text)
        } catch as e {
            ; A failing handler must not stop frame processing or leave the state machine half done.
            this.handlerErrors += 1
            Log.Write("a0", "ipc", "OnFrame handler failed: " Type(e) ": " e.Message)
        }
    }
}
