#Requires AutoHotkey v2.0
; Unit tests for src/supervisor/ChildLauncher.ahk and ChildPipe.ahk (WI-0023): a process started with its
; stdout/stderr in an anonymous pipe, the non-blocking line reader, and the handles that must not leak.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\supervisor\ChildLauncher.ahk

; Waits (up to ms) until the process handle is signalled. Returns true when it has ended.
EndedWithin(handle, ms) => DllCall("WaitForSingleObject", "ptr", handle, "uint", ms, "uint") = 0

HandleCount() {
    n := 0
    DllCall("GetProcessHandleCount", "ptr", DllCall("GetCurrentProcess", "ptr"), "uint*", &n)
    return n
}

Cmd(text) => '"' A_ComSpec '" /c ' text

; An anonymous pipe made by the test itself: returns [reader (ChildPipe), write handle].
OwnPipe() {
    hRead := 0
    hWrite := 0
    DllCall("CreatePipe", "ptr*", &hRead, "ptr*", &hWrite, "ptr", 0, "uint", 65536)
    return [ChildPipe(hRead), hWrite]
}

WriteBytes(hWrite, bytes) {
    buf := Buffer(bytes.Length)
    for i, b in bytes
        NumPut("UChar", b, buf, i - 1)
    written := 0
    DllCall("WriteFile", "ptr", hWrite, "ptr", buf, "uint", bytes.Length, "uint*", &written, "ptr", 0)
}

CheckStdoutAndStderrAreRead() {
    info := ChildLauncher.Start(Cmd('"echo to-stdout& echo to-stderr 1>&2"'))
    Assert.True(info["pid"] > 0)
    Assert.True(EndedWithin(info["process"], 10000), "the child did not end")
    lines := info["reader"].Drain()
    DllCall("CloseHandle", "ptr", info["process"])
    info["reader"].Close()
    text := ""
    for line in lines
        text .= line "|"
    Assert.True(InStr(text, "to-stdout"), "stdout missing: " text)
    Assert.True(InStr(text, "to-stderr"), "stderr missing: " text)
}

CheckStdinIsNul() {
    ; findstr reads stdin; with NUL it gets end of input at once. With an inherited console it would wait.
    info := ChildLauncher.Start(Cmd('findstr x'))
    ended := EndedWithin(info["process"], 10000)
    if (!ended)
        DllCall("TerminateProcess", "ptr", info["process"], "uint", 1)
    DllCall("CloseHandle", "ptr", info["process"])
    info["reader"].Close()
    Assert.True(ended, "the child waits for input")
}

CheckExitCodeIsAvailable() {
    info := ChildLauncher.Start(Cmd('exit 7'))
    Assert.True(EndedWithin(info["process"], 10000))
    code := 0
    DllCall("GetExitCodeProcess", "ptr", info["process"], "uint*", &code)
    DllCall("CloseHandle", "ptr", info["process"])
    info["reader"].Close()
    Assert.Equal(code, 7)
}

CheckFailedStartThrowsAndLeaksNothing() {
    before := HandleCount()
    loop 20 {
        try {
            ChildLauncher.Start('"C:\does\not\exist\nothing.exe" arg')
            Assert.True(false, "no error")
        } catch AhfError {
        }
    }
    Assert.True(HandleCount() <= before + 2, "handles before " before " after " HandleCount())
}

CheckHandlesStayFlatOverManyStarts() {
    loop 3 {                                     ; warm up: one-off allocations of the first calls
        info := ChildLauncher.Start(Cmd('exit 0'))
        EndedWithin(info["process"], 10000)
        info["reader"].Drain()
        DllCall("CloseHandle", "ptr", info["process"])
        info["reader"].Close()
    }
    before := HandleCount()
    loop 40 {
        info := ChildLauncher.Start(Cmd('echo x'))
        EndedWithin(info["process"], 10000)
        info["reader"].Drain()
        DllCall("CloseHandle", "ptr", info["process"])
        info["reader"].Close()
    }
    Assert.True(HandleCount() <= before + 2, "handles before " before " after " HandleCount())
}

CheckIncompleteLineWaitsForItsNewline() {
    p := OwnPipe()
    WriteBytes(p[2], [72, 101, 108])                                  ; "Hel"
    Assert.Equal(p[1].ReadLines().Length, 0)
    WriteBytes(p[2], [108, 111, 13, 10, 87, 111])                     ; "lo" CR LF "Wo"
    lines := p[1].ReadLines()
    Assert.Equal(lines.Length, 1)
    Assert.Equal(lines[1], "Hello")
    WriteBytes(p[2], [114, 108, 100])                                 ; "rld" without newline
    Assert.Equal(p[1].ReadLines().Length, 0)
    last := p[1].Drain()
    Assert.Equal(last.Length, 1)
    Assert.Equal(last[1], "World")
    DllCall("CloseHandle", "ptr", p[2])
    p[1].Close()
}

CheckUtf8CharacterSplitAcrossReads() {
    p := OwnPipe()
    ; U+00FC "u with diaeresis" = C3 BC, U+2713 check mark = E0002 9C 93; each is cut between its bytes
    WriteBytes(p[2], [97, 0xC3])
    Assert.Equal(p[1].ReadLines().Length, 0)
    WriteBytes(p[2], [0xBC, 0xE2, 0x9C])
    Assert.Equal(p[1].ReadLines().Length, 0)
    WriteBytes(p[2], [0x93, 98, 10])
    lines := p[1].ReadLines()
    Assert.Equal(lines.Length, 1)
    Assert.Equal(lines[1], "a" Chr(0xFC) Chr(0x2713) "b")
    DllCall("CloseHandle", "ptr", p[2])
    p[1].Close()
}

CheckEmptyLinesAreSkippedAndSeveralLinesComeTogether() {
    p := OwnPipe()
    WriteBytes(p[2], [97, 10, 10, 13, 10, 98, 13, 10, 99, 10])
    lines := p[1].ReadLines()
    Assert.Equal(lines.Length, 3)
    Assert.Equal(lines[1] lines[2] lines[3], "abc")
    DllCall("CloseHandle", "ptr", p[2])
    p[1].Close()
}

CheckVeryLongLineIsCut() {
    p := OwnPipe()
    bytes := []
    loop ChildPipe.MAX_LINE + 100
        bytes.Push(120)
    WriteBytes(p[2], bytes)
    lines := p[1].ReadLines()
    Assert.Equal(lines.Length, 1)
    Assert.Equal(StrLen(lines[1]), ChildPipe.MAX_LINE + 100)
    DllCall("CloseHandle", "ptr", p[2])
    p[1].Close()
}

CheckReadAfterTheWriterIsGoneEndsQuietly() {
    p := OwnPipe()
    WriteBytes(p[2], [111, 107, 10])
    DllCall("CloseHandle", "ptr", p[2])
    Assert.Equal(p[1].ReadLines()[1], "ok")
    Assert.Equal(p[1].ReadLines().Length, 0)        ; broken pipe: no error, no lines
    p[1].Close()
    Assert.Equal(p[1].ReadLines().Length, 0)        ; closed reader: no error
}

TestRun.Init()

TestRun.Case("stdout and stderr of the child arrive in the reader", CheckStdoutAndStderrAreRead)
TestRun.Case("stdin of the child is NUL, it does not wait for input", CheckStdinIsNul)
TestRun.Case("the exit code is read from the process handle", CheckExitCodeIsAvailable)
TestRun.Case("a failed start throws and leaks no handle", CheckFailedStartThrowsAndLeaksNothing)
TestRun.Case("handles stay flat over 40 starts", CheckHandlesStayFlatOverManyStarts)
TestRun.Case("an incomplete line waits for its newline", CheckIncompleteLineWaitsForItsNewline)
TestRun.Case("a UTF-8 character cut between two reads is decoded whole", CheckUtf8CharacterSplitAcrossReads)
TestRun.Case("empty lines are skipped and several lines come together", CheckEmptyLinesAreSkippedAndSeveralLinesComeTogether)
TestRun.Case("a line without newline beyond the limit is emitted at once", CheckVeryLongLineIsCut)
TestRun.Case("reading after the writer is gone or the reader is closed is quiet", CheckReadAfterTheWriterIsGoneEndsQuietly)

TestRun.Finish()
