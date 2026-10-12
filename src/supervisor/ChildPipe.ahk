#Requires AutoHotkey v2.0

; Read end of the anonymous pipe that carries stdout and stderr of one child (WI-23, ChildLauncher).
; Nothing here blocks: PeekNamedPipe tells how many bytes are there, ReadFile then takes exactly those.
; Reading an anonymous pipe is not file I/O in the sense of CONVENTIONS section 3 (no file is opened).
;
;   pipe := ChildPipe(hRead)
;   lines := pipe.ReadLines(65536)   ; new complete lines (Array of strings), at most 64 KB are read
;   lines := pipe.Drain()            ; everything that is left, also a last line without newline
;   pipe.Close()
;
; Lines are cut at the byte 0x0A (a UTF-8 multibyte character never contains it), then decoded as UTF-8,
; a trailing CR is removed and empty lines are skipped. A line longer than MAX_LINE bytes is cut there.
class ChildPipe {
    static MAX_LINE := 8192

    __New(handle) {
        this.handle := handle
        this._pending := Buffer(0)
    }

    ; Takes up to maxBytes from the pipe and returns the complete lines among the bytes read so far.
    ReadLines(maxBytes := 65536) {
        lines := []
        if (this.handle = 0)
            return lines
        total := 0
        while (total < maxBytes) {
            avail := 0
            if (!DllCall("PeekNamedPipe", "ptr", this.handle, "ptr", 0, "uint", 0, "ptr", 0, "uint*", &avail, "ptr", 0))
                break                       ; broken pipe: the writer is gone and nothing is left
            if (avail = 0)
                break
            want := Min(avail, maxBytes - total)
            chunk := Buffer(want)
            got := 0
            if (!DllCall("ReadFile", "ptr", this.handle, "ptr", chunk, "uint", want, "uint*", &got, "ptr", 0) || got = 0)
                break
            total += got
            this._Append(chunk, got, lines)
        }
        return lines
    }

    ; All lines that are left, including a last one without newline. Used when the process has ended.
    Drain() {
        lines := []
        loop {
            more := this.ReadLines(1048576)
            if (more.Length = 0)
                break
            for line in more
                lines.Push(line)
        }
        if (this._pending.Size > 0) {
            this._Split(StrGet(this._pending, this._pending.Size, "UTF-8"), lines)
            this._pending := Buffer(0)
        }
        return lines
    }

    Close() {
        if (this.handle != 0) {
            DllCall("CloseHandle", "ptr", this.handle)
            this.handle := 0
        }
    }

    _Append(chunk, got, lines) {
        oldSize := this._pending.Size
        all := Buffer(oldSize + got)
        if (oldSize > 0)
            DllCall("RtlMoveMemory", "ptr", all, "ptr", this._pending, "uptr", oldSize)
        DllCall("RtlMoveMemory", "ptr", all.Ptr + oldSize, "ptr", chunk, "uptr", got)
        ; the last newline: everything before it is complete lines, the rest waits for more bytes
        last := all.Size - 1
        while (last >= 0 && NumGet(all, last, "UChar") != 10)
            last -= 1
        if (last < 0) {
            if (all.Size > ChildPipe.MAX_LINE) {
                this._Split(StrGet(all, all.Size, "UTF-8"), lines)
                this._pending := Buffer(0)
            } else {
                this._pending := all
            }
            return
        }
        this._Split(StrGet(all, last, "UTF-8"), lines)
        rest := all.Size - last - 1
        if (rest > ChildPipe.MAX_LINE) {
            this._Split(StrGet(all.Ptr + last + 1, rest, "UTF-8"), lines)
            rest := 0
        }
        this._pending := Buffer(rest)
        if (rest > 0)
            DllCall("RtlMoveMemory", "ptr", this._pending, "ptr", all.Ptr + last + 1, "uptr", rest)
    }

    _Split(text, lines) {
        for line in StrSplit(text, "`n") {
            line := RTrim(line, "`r")
            if (line != "")
                lines.Push(line)
        }
    }
}
