#Requires AutoHotkey v2.0
; Unit tests for src/core/ipc/Frame.ahk (FrameWriter, FrameReader), WI-0004. Pure logic, no pipe.
#Include lib\Assert.ahk
#Include ..\..\src\core\ipc\Frame.ahk

; Concatenates the frames of the given texts into one Buffer.
Wire(texts*) {
    total := 0
    frames := []
    for t in texts {
        f := FrameWriter.Encode(t)
        frames.Push(f)
        total += f.Size
    }
    out := Buffer(total)
    pos := 0
    for f in frames {
        DllCall("RtlMoveMemory", "ptr", out.Ptr + pos, "ptr", f.Ptr, "uptr", f.Size)
        pos += f.Size
    }
    return out
}

; Returns all frames the reader can deliver now.
Drain(reader) {
    out := []
    loop {
        t := reader.Next()
        if (t = "")
            break
        out.Push(t)
    }
    return out
}

Repeat(ch, n) {
    s := ch
    while (StrLen(s) < n)
        s := s s
    return SubStr(s, 1, n)
}

CheckHeaderAndBody() {
    f := FrameWriter.Encode("abc")
    Assert.Equal(f.Size, 7)
    Assert.Equal(NumGet(f, 0, "UInt"), 3)
    Assert.Equal(NumGet(f, 4, "UChar"), 97)
    Assert.Equal(NumGet(f, 6, "UChar"), 99)
}

CheckHeaderIsLittleEndian() {
    f := FrameWriter.Encode(Repeat("x", 0x010203))
    Assert.Equal(NumGet(f, 0, "UChar"), 0x03)
    Assert.Equal(NumGet(f, 1, "UChar"), 0x02)
    Assert.Equal(NumGet(f, 2, "UChar"), 0x01)
    Assert.Equal(NumGet(f, 3, "UChar"), 0x00)
}

CheckLengthIsInBytes() {
    text := "a" Chr(0xE9) Chr(0x20AC) Chr(0xD83D) Chr(0xDE00)   ; 1 + 2 + 3 + 4 bytes in UTF-8
    f := FrameWriter.Encode(text)
    Assert.Equal(NumGet(f, 0, "UInt"), 10)
    Assert.Equal(f.Size, 14)
    r := FrameReader()
    r.Feed(f)
    Assert.Equal(r.Next(), text)
}

CheckEmptyTextIsRejected() {
    Assert.Throws(() => FrameWriter.Encode(""), ProtocolError)
}

CheckOversizeEncodeIsRejected() {
    Assert.Throws(() => FrameWriter.Encode(Repeat("x", FrameWriter.MAX_FRAME + 1)), ProtocolError)
}

CheckMaxSizeRoundTrip() {
    text := Repeat("m", FrameWriter.MAX_FRAME)
    r := FrameReader()
    r.Feed(FrameWriter.Encode(text))
    got := r.Next()
    Assert.Equal(StrLen(got), FrameWriter.MAX_FRAME)
    Assert.True(got == text)
    Assert.Equal(r.Buffered, 0)
}

CheckSingleFrame() {
    r := FrameReader()
    r.Feed(Wire("hello"))
    Assert.Equal(r.Next(), "hello")
    Assert.Equal(r.Next(), "")
}

CheckPartialHeaderAndBody() {
    w := Wire("partial frame")
    r := FrameReader()
    r.Feed(w.Ptr, 2)                       ; half of the header
    Assert.Equal(r.Next(), "")
    r.Feed(w.Ptr + 2, 2)                   ; header complete, no body
    Assert.Equal(r.Next(), "")
    r.Feed(w.Ptr + 4, 5)                   ; part of the body
    Assert.Equal(r.Next(), "")
    r.Feed(w.Ptr + 9, w.Size - 9)
    Assert.Equal(r.Next(), "partial frame")
}

CheckByteByByte() {
    w := Wire("one", "two " Chr(0xE9), "three")
    r := FrameReader()
    got := []
    loop w.Size {
        r.Feed(w.Ptr + A_Index - 1, 1)
        for t in Drain(r)
            got.Push(t)
    }
    Assert.Equal(got.Length, 3)
    Assert.Equal(got[1], "one")
    Assert.Equal(got[2], "two " Chr(0xE9))
    Assert.Equal(got[3], "three")
}

CheckSeveralFramesInOneFeed() {
    r := FrameReader()
    r.Feed(Wire("a", "bb", "ccc"))
    got := Drain(r)
    Assert.Equal(got.Length, 3)
    Assert.Equal(got[3], "ccc")
}

CheckSplitInsideMultibyteChar() {
    text := "x" Chr(0x20AC) "y"                       ; the euro sign takes three bytes
    w := Wire(text)
    r := FrameReader()
    r.Feed(w.Ptr, 6)                                    ; header, "x", first byte of the euro sign
    Assert.Equal(r.Next(), "")
    r.Feed(w.Ptr + 6, w.Size - 6)
    Assert.Equal(r.Next(), text)
}

CheckBufferGrowsAndIsReused() {
    big := Repeat("g", 300000)
    r := FrameReader()
    loop 3 {
        r.Feed(Wire(big, "small"))
        Assert.True(r.Next() == big)
        Assert.Equal(r.Next(), "small")
    }
    Assert.Equal(r.Buffered, 0)
}

CheckCompactionKeepsOrder() {
    ; Many small frames fed so that unread bytes sit in the middle of the buffer when it must move.
    r := FrameReader()
    expected := 0
    sent := 0
    seen := 0
    loop 5000 {
        r.Feed(Wire("frame-" A_Index))
        sent += 1
        if (Mod(A_Index, 3) = 0) {
            loop 2 {
                t := r.Next()
                if (t = "")
                    break
                seen += 1
                Assert.Equal(t, "frame-" seen)
            }
        }
    }
    for t in Drain(r) {
        seen += 1
        Assert.Equal(t, "frame-" seen)
    }
    Assert.Equal(seen, sent)
}

CheckLimitIsEnforcedFromTheHeader() {
    r := FrameReader()
    hdr := Buffer(4)
    NumPut("UInt", FrameWriter.MAX_FRAME + 1, hdr, 0)
    r.Feed(hdr)                                         ; no body at all: the header is enough
    Assert.Throws(() => r.Next(), ProtocolError)
}

CheckHugeLengthIsRejected() {
    r := FrameReader()
    hdr := Buffer(4)
    NumPut("UInt", 0xFFFFFFFF, hdr, 0)
    r.Feed(hdr)
    Assert.Throws(() => r.Next(), ProtocolError)
}

CheckZeroLengthIsRejected() {
    r := FrameReader()
    hdr := Buffer(4, 0)
    r.Feed(hdr)
    Assert.Throws(() => r.Next(), ProtocolError)
}

CheckCustomLimit() {
    r := FrameReader(10)
    r.Feed(Wire("0123456789"))
    Assert.Equal(r.Next(), "0123456789")
    r.Feed(Wire("01234567890"))
    Assert.Throws(() => r.Next(), ProtocolError)
}

CheckPointerNeedsLength() {
    r := FrameReader()
    w := Wire("x")
    Assert.Throws(() => r.Feed(w.Ptr), ValueError)
}

TestRun.Case("header and body", CheckHeaderAndBody)
TestRun.Case("header is little endian", CheckHeaderIsLittleEndian)
TestRun.Case("length counts UTF-8 bytes", CheckLengthIsInBytes)
TestRun.Case("empty text is rejected", CheckEmptyTextIsRejected)
TestRun.Case("oversize encode is rejected", CheckOversizeEncodeIsRejected)
TestRun.Case("16 MiB frame round trip", CheckMaxSizeRoundTrip)
TestRun.Case("single frame", CheckSingleFrame)
TestRun.Case("partial header and body", CheckPartialHeaderAndBody)
TestRun.Case("byte by byte", CheckByteByByte)
TestRun.Case("several frames in one feed", CheckSeveralFramesInOneFeed)
TestRun.Case("split inside a multibyte character", CheckSplitInsideMultibyteChar)
TestRun.Case("buffer grows and is reused", CheckBufferGrowsAndIsReused)
TestRun.Case("compaction keeps order", CheckCompactionKeepsOrder)
TestRun.Case("limit is enforced from the header", CheckLimitIsEnforcedFromTheHeader)
TestRun.Case("huge length is rejected", CheckHugeLengthIsRejected)
TestRun.Case("zero length is rejected", CheckZeroLengthIsRejected)
TestRun.Case("custom limit", CheckCustomLimit)
TestRun.Case("pointer needs length", CheckPointerNeedsLength)
TestRun.Finish()
