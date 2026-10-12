#Requires AutoHotkey v2.0
#Include ..\Errors.ahk

; Frame format of the IPC pipes (doc/PROTOCOL.md section 1):
;   uint32 little endian length N, followed by N bytes of UTF-8 text.
; An empty frame (N = 0) is not valid: every message is a JSON object.
class FrameWriter {
    ; Maximum frame body size in bytes (16 MiB). Larger payloads are split by the application.
    static MAX_FRAME := 16 * 1024 * 1024

    ; Returns a Buffer that holds the complete frame (header and body), ready for WriteFile.
    ; Throws ProtocolError if the text is empty or its UTF-8 form exceeds MAX_FRAME.
    static Encode(text) {
        text := String(text)
        size := StrPut(text, "UTF-8") - 1          ; bytes without the terminator
        if (size <= 0)
            throw ProtocolError("FrameWriter: empty frame", ErrCode.BAD_PAYLOAD)
        if (size > FrameWriter.MAX_FRAME)
            throw ProtocolError("FrameWriter: frame of " size " bytes exceeds " FrameWriter.MAX_FRAME, ErrCode.BAD_PAYLOAD)
        buf := Buffer(4 + size + 1)                ; one spare byte, StrPut writes a terminator
        NumPut("UInt", size, buf, 0)
        StrPut(text, buf.Ptr + 4, size + 1, "UTF-8")
        buf.Size := 4 + size                       ; drop the spare byte, contents are kept
        return buf
    }
}
