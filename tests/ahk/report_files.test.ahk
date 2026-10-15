#Requires AutoHotkey v2.0
; Unit tests for src/storage/ReportFiles.ahk (WI-0028): the Reports/ folder written by storage.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\storage\ReportFiles.ahk

NewDataDir() {
    dir := A_Temp "\ahf-reportfiles-" DllCall("GetCurrentProcessId", "uint") "-" A_TickCount
    DirCreate(dir "\Log")
    return dir
}

Stamp(n) => "20260101-" Format("{:06d}", n)

CheckWritesTheFilesAndCopiesTheLogs() {
    data := NewDataDir()
    FileAppend("log line`r`n", data "\Log\Log.txt", "UTF-8-RAW")
    FileAppend("old line`r`n", data "\Log\Log_old.txt", "UTF-8-RAW")
    FileAppend("not copied`r`n", data "\Log\Log_engine.txt", "UTF-8-RAW")
    r := ReportFiles.Write(data, "20260101-120000", "manual", Map("report.json", "{`"a`":1}", "summary.txt", "hello `u{00FC}"))
    Assert.Equal(r["path"], "Reports/20260101-120000_manual")
    Assert.Equal(r["dir"], data "\Reports\20260101-120000_manual")
    Assert.Equal(r["removed"], 0)
    Assert.Equal(r["logs"].Length, 2)
    Assert.Equal(FileRead(r["dir"] "\report.json", "UTF-8"), "{`"a`":1}")
    Assert.Equal(FileRead(r["dir"] "\summary.txt", "UTF-8"), "hello `u{00FC}")
    Assert.Equal(FileRead(r["dir"] "\Log.txt", "UTF-8"), "log line`r`n")
    Assert.True(FileExist(r["dir"] "\Log_old.txt") != "")
    Assert.Equal(FileExist(r["dir"] "\Log_engine.txt"), "", "only the common log is copied")
    DirDelete(data, true)
}

CheckWithoutLogsTheReportIsStillWritten() {
    data := A_Temp "\ahf-reportfiles-nolog-" A_TickCount
    r := ReportFiles.Write(data, Stamp(1), "x", Map("a.txt", "a"))
    Assert.Equal(r["logs"].Length, 0)
    Assert.True(FileExist(r["dir"] "\a.txt") != "")
    DirDelete(data, true)
}

CheckTheSameNameGetsASuffix() {
    data := NewDataDir()
    a := ReportFiles.Write(data, Stamp(5), "same", Map("a.txt", "1"))
    b := ReportFiles.Write(data, Stamp(5), "same", Map("a.txt", "2"))
    c := ReportFiles.Write(data, Stamp(5), "same", Map("a.txt", "3"))
    Assert.Equal(a["path"], "Reports/20260101-000005_same")
    Assert.Equal(b["path"], "Reports/20260101-000005_same-2")
    Assert.Equal(c["path"], "Reports/20260101-000005_same-3")
    Assert.Equal(FileRead(a["dir"] "\a.txt"), "1", "an earlier report is never overwritten")
    DirDelete(data, true)
}

CheckOnlyTheNewest20AreKept() {
    data := NewDataDir()
    removedTotal := 0
    loop 25 {
        r := ReportFiles.Write(data, Stamp(A_Index), "r", Map("a.txt", "x"))
        removedTotal += r["removed"]
    }
    names := ReportFiles.Folders(data "\Reports")
    Assert.Equal(names.Length, 20)
    Assert.Equal(removedTotal, 5)
    Assert.Equal(names[1], "20260101-000006_r", "the oldest five are gone")
    Assert.Equal(names[20], "20260101-000025_r")
    DirDelete(data, true)
}

CheckOtherFoldersInReportsAreLeftAlone() {
    data := NewDataDir()
    DirCreate(data "\Reports\keep-me")
    loop 22
        ReportFiles.Write(data, Stamp(A_Index), "r", Map("a.txt", "x"))
    Assert.True(DirExist(data "\Reports\keep-me") != "", "a folder that is not a report is not deleted")
    Assert.Equal(ReportFiles.Folders(data "\Reports").Length, 20)
    DirDelete(data, true)
}

CheckBadNamesAreRefused() {
    data := NewDataDir()
    good := Map("a.txt", "x")
    Assert.Throws(() => ReportFiles.Write(data, "2026-01-01", "x", good), AhfError)
    Assert.Throws(() => ReportFiles.Write(data, Stamp(1), "", good), AhfError)
    Assert.Throws(() => ReportFiles.Write(data, Stamp(1), "a b", good), AhfError)
    Assert.Throws(() => ReportFiles.Write(data, Stamp(1), "..\x", good), AhfError)
    Assert.Throws(() => ReportFiles.Write(data, Stamp(1), "x", Map()), AhfError)
    Assert.Throws(() => ReportFiles.Write(data, Stamp(1), "x", Map("..\evil.txt", "x")), AhfError)
    Assert.Throws(() => ReportFiles.Write(data, Stamp(1), "x", Map("sub/evil.txt", "x")), AhfError)
    Assert.Throws(() => ReportFiles.Write(data, Stamp(1), "x", Map("Log.txt", "x")), AhfError)
    Assert.Throws(() => ReportFiles.Write(data, Stamp(1), "x", Map("a.txt", Map())), AhfError)
    e := Assert.Throws(() => ReportFiles.Write(data, Stamp(1), "x", Map("a:b.txt", "x")), AhfError)
    Assert.Equal(e.code, ErrCode.BAD_PAYLOAD)
    Assert.Equal(DirExist(data "\Reports"), "", "nothing was created for refused requests")
    DirDelete(data, true)
}

TestRun.Init()

TestRun.Case("a report folder holds the files and copies of the common log", CheckWritesTheFilesAndCopiesTheLogs)
TestRun.Case("a report without log files is still written", CheckWithoutLogsTheReportIsStillWritten)
TestRun.Case("an existing folder name gets a suffix, nothing is overwritten", CheckTheSameNameGetsASuffix)
TestRun.Case("only the newest 20 reports are kept", CheckOnlyTheNewest20AreKept)
TestRun.Case("folders that are no reports are never deleted", CheckOtherFoldersInReportsAreLeftAlone)
TestRun.Case("bad stamps, reasons and file names are refused before anything is created", CheckBadNamesAreRefused)

TestRun.Finish()
