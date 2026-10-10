#Requires AutoHotkey v2.0
#Include ..\Errors.ahk
#Include FrameWriter.ahk

; Reassembles frames from arbitrary chunks of bytes (a pipe delivers a byte stream, not messages).
; Feed() appends bytes, Next() returns the next complete frame as text or "" if none is complete.
; A bad header (length above the limit, or zero) throws ProtocolError: the stream cannot be
; resynchronised, so the caller must close the connection.
class FrameReader {
    static INITIAL_SIZE := 65536
    ; A buffer that grew above this size is released once it is empty again.
    static SHRINK_ABOVE := 1048576

    __New(maxFrame := FrameWriter.MAX_FRAME) {
        this._maxFrame := maxFrame
        this._buf := Buffer(FrameReader.INITIAL_SIZE)
        this._start := 0        ; offset of the first unread byte
        this._end := 0          ; offset behind the last byte
    }

    ; Number of buffered bytes that do not yet form a returned frame.
    Buffered => this._end - this._start

    ; Appends n bytes. `data` is a Buffer (n defaults to its size) or a raw pointer (n is required).
    Feed(data, n := unset) {
        if (data is Buffer) {
            ptr := data.Ptr
            if (!IsSet(n))
                n := data.Size
        } else {
            ptr := data
            if (!IsSet(n))
                throw ValueError("FrameReader.Feed: n is required for a pointer")
        }
        if (n <= 0)
            return
        if (this._end + n > this._buf.Size) {
            avail := this._end - this._start
            if (avail + n <= this._buf.Size) {
                ; Enough room after moving the unread bytes to the front.
                if (avail > 0)
                    DllCall("RtlMoveMemory", "ptr", this._buf.Ptr, "ptr", this._buf.Ptr + this._start, "uptr", avail)
            } else {
                newSize := Max(this._buf.Size * 2, avail + n)
                nb := Buffer(newSize)
                if (avail > 0)
                    DllCall("RtlMoveMemory", "ptr", nb.Ptr, "ptr", this._buf.Ptr + this._start, "uptr", avail)
                this._buf := nb
            }
            this._start := 0
            this._end := avail
        }
        DllCall("RtlMoveMemory", "ptr", this._buf.Ptr + this._end, "ptr", ptr, "uptr", n)
        this._end += n
    }

    ; Returns the next complete frame as a String, or "" if there is none yet.
    Next() {
        avail := this._end - this._start
        if (avail < 4)
            return ""
        len := NumGet(this._buf, this._start, "UInt")
        if (len > this._maxFrame)
            throw ProtocolError("FrameReader: frame length " len " exceeds limit " this._maxFrame, ErrCode.BAD_PAYLOAD)
        if (len = 0)
            throw ProtocolError("FrameReader: empty frame", ErrCode.BAD_PAYLOAD)
        if (avail < 4 + len)
            return ""
        text := StrGet(this._buf.Ptr + this._start + 4, len, "UTF-8")
        this._start += 4 + len
        if (this._start = this._end) {
            this._start := 0
            this._end := 0
            if (this._buf.Size > FrameReader.SHRINK_ABOVE)
                this._buf := Buffer(FrameReader.INITIAL_SIZE)
        }
        return text
    }

    ; Drops all buffered bytes.
    Reset() {
        this._start := 0
        this._end := 0
    }
}
