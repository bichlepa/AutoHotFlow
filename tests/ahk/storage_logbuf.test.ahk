#Requires AutoHotkey v2.0
#SingleInstance Off
; Unit test for the line buffers of the log files in src/storage/Storage.ahk (F-0088).
; In the process the queue timer (_FinishLogBundle) can interrupt the handler of evt.log.append between two
; lines of _LogToFile and remove the buffer of the file. The test stands in for that interruption: RacyMap removes
; a key right after the first read of it, which is the worst moment for a "check, then read" code.
#Include lib\Assert.ahk
#Include ..\..\src\storage\Storage.ahk

class RacyMap extends Map {
    armed := false

    Has(key) {
        found := super.Has(key)
        this._Interrupt(key)
        return found
    }

    Get(key, default := unset) {
        value := IsSet(default) ? super.Get(key, default) : super.Get(key)
        this._Interrupt(key)
        return value
    }

    ; The interruption: the key is gone after its first read.
    _Interrupt(key) {
        if (this.armed && super.Has(key)) {
            this.armed := false
            this.Delete(key)
        }
    }
}

class FakePeer {
    sent := []
    Send(to, type, payload := "") {
        this.sent.Push(type)
        return "id"
    }
}

NewStorage(dataDir) {
    st := Storage(Map("role", "storage", "data", dataDir))
    st.peer := FakePeer()
    st.logBuffers := RacyMap()
    return st
}

ReadLog(dataDir, name) {
    path := dataDir "\Log\" name
    return FileExist(path) ? FileRead(path, "UTF-8") : ""
}

CountText(haystack, needle) {
    return (StrLen(haystack) - StrLen(StrReplace(haystack, needle, ""))) // StrLen(needle)
}

CheckLineIsNotLostWhenTheBufferVanishesAfterTheCheck() {
    dataDir := A_Temp "\ahf_logbuf_" A_TickCount
    DirCreate(dataDir)
    try {
        st := NewStorage(dataDir)
        ; The first line creates the buffers of Log.txt and Log_echo.txt; their operations wait for the queue timer.
        st._EnqueueLogEntry("2026-10-15 12:00:00", "a1", "echo", "echo:a", "entry one", "")
        st.logBuffers.armed := true
        ; The second line finds the buffer of Log.txt and loses it right after the first read.
        st._EnqueueLogEntry("2026-10-15 12:00:01", "a1", "echo", "echo:a", "entry two", "")
        deadline := A_TickCount + 5000
        while (st.logQueuedEntries > 0 && A_TickCount < deadline)
            Sleep(20)
        Sleep(100)
        for name in ["Log.txt", "Log_echo.txt"] {
            text := ReadLog(dataDir, name)
            Assert.Equal(CountText(text, "entry one"), 1, name " has entry one")
            Assert.Equal(CountText(text, "entry two"), 1, name " has entry two")
        }
        Assert.Equal(st.logQueuedEntries, 0, "no entry stays counted as queued")
        Assert.Equal(st.logLinesLost, 0)
    } finally {
        try DirDelete(dataDir, true)
    }
}

CheckLinesOfOneBurstAreWrittenOnceAndInOrder() {
    dataDir := A_Temp "\ahf_logbuf_" A_TickCount
    DirCreate(dataDir)
    try {
        st := NewStorage(dataDir)
        loop 300 {
            st._EnqueueLogEntry("2026-10-15 12:00:00", "a1", "echo", "echo:a", "entry " Format("{:04}", A_Index), "")
            if (Mod(A_Index, 50) = 0)
                Sleep(15)       ; lets the queue timer run in between, so buffers are removed and created again
        }
        deadline := A_TickCount + 5000
        while (st.logQueuedEntries > 0 && A_TickCount < deadline)
            Sleep(20)
        Sleep(100)
        text := ReadLog(dataDir, "Log.txt")
        previous := 0
        pos := 1
        while (RegExMatch(text, "entry (\d{4})", &m, pos)) {
            Assert.True(Integer(m[1]) = previous + 1, "entry " m[1] " follows entry " previous)
            previous := Integer(m[1])
            pos := m.Pos + m.Len
        }
        Assert.Equal(previous, 300)
        Assert.Equal(st.logQueuedEntries, 0)
    } finally {
        try DirDelete(dataDir, true)
    }
}

TestRun.Case("a log line is not lost when the buffer of the file vanishes after the check (F-0088)", CheckLineIsNotLostWhenTheBufferVanishesAfterTheCheck)
TestRun.Case("a burst of lines is written once and in order", CheckLinesOfOneBurstAreWrittenOnceAndInOrder)

TestRun.Finish()
