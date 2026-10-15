#Requires AutoHotkey v2.0
; Unit tests for src/supervisor/DiagReport.ahk and ReportText.ahk (WI-0028): collecting the snapshots with a deadline per
; role, the wait for storage, the automatic triggers and their rate limit. Hub and children are fakes that record calls.
; Report a local that hides a class or a built-in function (F-0078). Must stand before the first include.
#Warn All, StdOut
#Include lib\Assert.ahk
#Include ..\..\src\supervisor\DiagReport.ahk
#Include ..\..\src\core\Role.ahk

class FakeAnswer {
    __New(payload) {
        this.payload := payload
    }
}

class FakeReportHub {
    __New() {
        this.links := Map()
        this.requests := []
        this.timers := []
    }
    HasLink(name) => this.links.Has(name)
    Request(name, type, payload, cb, timeoutMs) {
        this.requests.Push(Map("to", name, "type", type, "payload", payload, "cb", cb, "timeoutMs", timeoutMs))
    }
    ; The first unanswered request of a type (to a name, or any when name is "")
    Find(type, name := "") {
        for r in this.requests
            if (r["type"] = type && (name = "" || r["to"] = name) && !r.Has("answered"))
                return r
        return ""
    }
    Answer(r, payload) {
        r["answered"] := true
        r["cb"].Call(FakeAnswer(payload))
    }
    Lost(r) {
        r["answered"] := true
        r["cb"].Call("")
    }
}

class FakeChildren {
    __New() {
        this.states := Map()
        this.shuttingDown := false
    }
    Names() {
        names := []
        for n, _ in this.states
            names.Push(n)
        return names
    }
    State(name) => this.states[name]
}

SnapOf(name, role) => Map("schema", 1, "name", name, "role", role, "pid", 100, "startedAt", "2026-01-01 00:00:00"
    , "uptimeMs", 5, "version", "v", "ahkVersion", "2.0", "bits", 64, "rssBytes", 2000000, "handles", 50
    , "log", Map("queued", 0, "dropped", 0, "sinkErrors", 0, "lastSinkError", "", "level", 2, "recent", [])
    , "errors", Map("count", 0, "recent", [])
    , "peer", Map("status", "ready", "pending", 0, "lateReplies", 0, "badFrames", 0, "droppedSends", 0
        , "queuedFrames", 0, "queuedBytes", 0, "handlerErrors", 0)
    , "info", Map())

SupSnap() {
    s := SnapOf("supervisor", "supervisor")
    s.Delete("peer")
    s.Delete("info")
    s["children"] := [Map("name", "engine", "role", "engine", "state", "ready", "pid", 11, "exitCode", "", "restarts", 0
        , "startedAt", "x", "busy", 0, "killReason", "", "output", [])]
    s["hub"] := Map("links", [], "droppedAnswers", 0, "pending", 0)
    return s
}

NewReport(&hub, &children) {
    hub := FakeReportHub()
    children := FakeChildren()
    Log.Configure("")
    return DiagReport(hub, children, () => SupSnap(), "t")
}

CheckAsksEveryConnectedRoleAndNotesTheOthers() {
    r := NewReport(&hub, &children)
    children.states["engine"] := "ready"
    children.states["storage"] := "ready"
    children.states["manager"] := "crashed"
    children.states["worker:1"] := "exited"
    children.states["worker:2"] := "starting"
    hub.links["engine"] := true
    hub.links["storage"] := true
    job := r.Request("manual")
    asked := []
    for q in hub.requests
        asked.Push(q["to"])
    Assert.Equal(hub.requests.Length, 2)
    Assert.True(hub.Find("cmd.diag.snapshot", "engine") != "")
    Assert.True(hub.Find("cmd.diag.snapshot", "storage") != "")
    Assert.Equal(hub.requests[1]["timeoutMs"], DiagReport.SNAPSHOT_MS, "every question has a deadline")
    names := ""
    for m in job["missing"]
        names .= m["name"] "=" m["why"] ";"
    Assert.Equal(names, "manager=not connected (crashed);worker:2=not connected (starting);", "exited children are not listed")
}

CheckAssemblesAfterTheLastAnswerAndWritesThroughStorage() {
    r := NewReport(&hub, &children)
    children.states["engine"] := "ready"
    children.states["storage"] := "ready"
    hub.links["engine"] := true
    hub.links["storage"] := true
    result := ""
    r.Request("manual", false, (p) => result := p)
    hub.Answer(hub.Find("cmd.diag.snapshot", "engine"), Map("ok", true, "snapshot", SnapOf("engine", "engine")))
    Assert.Equal(hub.Find("cmd.storage.report.write"), "", "not before the last answer")
    hub.Answer(hub.Find("cmd.diag.snapshot", "storage"), Map("ok", true, "snapshot", SnapOf("storage", "storage")))
    w := hub.Find("cmd.storage.report.write", "storage")
    Assert.True(w != "", "all answers are in: the report goes to storage")
    Assert.Equal(w["timeoutMs"], DiagReport.WRITE_TIMEOUT_MS)
    p := w["payload"]
    Assert.True(RegExMatch(p["stamp"], "^\d{8}-\d{6}$"))
    Assert.Equal(p["reason"], "manual")
    Assert.True(p["files"].Has("report.json") && p["files"].Has("summary.txt"))
    parsed := Json.Parse(p["files"]["report.json"])
    Assert.Equal(parsed["snapshots"].Count, 3, "engine, storage and the supervisor itself")
    Assert.True(parsed["snapshots"].Has("supervisor"))
    Assert.Equal(parsed["meta"]["auto"], 0)
    Assert.True(InStr(p["files"]["summary.txt"], "engine  (pid 100"))
    Assert.Equal(result, "", "the caller waits for the write")
    hub.Answer(w, Map("ok", true, "path", "Reports/x", "dir", "C:\x"))
    Assert.Equal(result["path"], "Reports/x")
    Assert.Equal(result["roles"], 3)
    Assert.Equal(r.Stats()["written"], 1)
}

CheckNoAnswerAndLostLinkAreNotedAndNothingWaits() {
    r := NewReport(&hub, &children)
    children.states["engine"] := "ready"
    children.states["storage"] := "ready"
    children.states["manager"] := "ready"
    hub.links["engine"] := true
    hub.links["storage"] := true
    hub.links["manager"] := true
    job := r.Request("manual")
    hub.Answer(hub.Find("cmd.diag.snapshot", "engine"), Map("ok", false, "error", Map("code", "timeout", "message", "x")))
    hub.Lost(hub.Find("cmd.diag.snapshot", "storage"))
    hub.Answer(hub.Find("cmd.diag.snapshot", "manager"), Map("ok", false, "error", Map("code", "denied", "message", "x")))
    why := Map()
    for m in job["missing"]
        why[m["name"]] := m["why"]
    Assert.Equal(why["engine"], "no answer within 2000 ms")
    Assert.Equal(why["storage"], "connection lost before the answer")
    Assert.Equal(why["manager"], "error: denied")
    Assert.True(hub.Find("cmd.storage.report.write") != "", "the report is written with what there is")
}

CheckARoleWithoutSnapshotInTheAnswerCountsAsMissing() {
    r := NewReport(&hub, &children)
    children.states["engine"] := "ready"
    hub.links["engine"] := true
    job := r.Request("manual")
    hub.Answer(hub.Find("cmd.diag.snapshot"), Map("ok", true))
    Assert.Equal(job["missing"].Length, 1)
}

CheckAReportWithoutAnyChildIsStillBuilt() {
    r := NewReport(&hub, &children)
    result := ""
    r.Request("manual", false, (p) => result := p)
    Sleep(50)                                   ; the timer that builds it
    Assert.True(hub.Find("cmd.storage.report.write") = "", "storage is not connected: the report waits")
    Assert.Equal(r.Stats()["unwritten"], 1)
}

CheckAReportWaitsForStorageAndIsWrittenWhenItIsBack() {
    r := NewReport(&hub, &children)
    r.storageWaitMs := 100000
    children.states["engine"] := "ready"
    hub.links["engine"] := true
    result := ""
    r.Request("manual", false, (p) => result := p)
    hub.Answer(hub.Find("cmd.diag.snapshot"), Map("ok", true, "snapshot", SnapOf("engine", "engine")))
    Assert.Equal(hub.Find("cmd.storage.report.write"), "", "storage is away")
    Assert.Equal(r.Stats()["unwritten"], 1)
    Assert.Equal(result, "")
    hub.links["storage"] := true
    r.OnStorageHello()
    w := hub.Find("cmd.storage.report.write", "storage")
    Assert.True(w != "", "written as soon as storage says hello")
    Assert.Equal(r.Stats()["unwritten"], 0)
    hub.Answer(w, Map("ok", true, "path", "Reports/late", "dir", "d"))
    Assert.Equal(result["path"], "Reports/late")
}

CheckTheCallerIsAnsweredAfterTheWaitAndTheReportStaysForTheNextTime() {
    r := NewReport(&hub, &children)
    r.storageWaitMs := 30
    result := ""
    job := r.Request("manual", false, (p) => result := p)
    Sleep(100)                                  ; build timer, then the wait of 30 ms
    Assert.True(IsObject(result), "answered after the wait")
    Assert.Equal(result["ok"], false)
    Assert.Equal(result["error"]["code"], "peer_gone")
    Assert.Equal(r.Stats()["unwritten"], 1, "the report is kept")
    hub.links["storage"] := true
    r.OnStorageHello()
    w := hub.Find("cmd.storage.report.write", "storage")
    Assert.True(w != "", "and written later")
    Assert.Equal(w["payload"]["stamp"], job["stamp"], "under its own stamp")
    hub.Answer(w, Map("ok", true, "path", "Reports/p", "dir", "d"))
    Assert.Equal(r.Stats()["written"], 1)
    Assert.Equal(result["ok"], false, "the caller is not answered twice")
}

; WI-0033 (F-0015): the supervisor stood still; the wait for storage keeps its rest of the time.
CheckAStandStillMovesTheWaitForStorage() {
    r := NewReport(&hub, &children)
    r.storageWaitMs := 600
    result := ""
    r.Request("manual", false, (p) => result := p)
    Sleep(100)                                  ; build timer; the wait of 600 ms has begun
    Assert.Equal(r.Stats()["unwritten"], 1)
    r.Shift(Time.NowMs(), 1000)                 ; the wait is now due about 1.5 s from now
    Sleep(900)
    Assert.Equal(result, "", "the caller is not answered before the moved time")
    Sleep(1000)
    Assert.True(IsObject(result), "answered after the moved time")
    Assert.Equal(result["error"]["code"], "peer_gone")
    Assert.Equal(r.Stats()["unwritten"], 1, "the report is kept")
}

CheckTheWaitingListIsBounded() {
    r := NewReport(&hub, &children)
    r.storageWaitMs := 100000
    answers := []
    loop DiagReport.KEEP_UNWRITTEN + 2
        r.Request("r" A_Index, false, (p) => answers.Push(p))
    Sleep(100)
    Assert.Equal(r.Stats()["unwritten"], DiagReport.KEEP_UNWRITTEN)
    Assert.Equal(answers.Length, 2, "the two oldest are given up and answered")
    Assert.Equal(answers[1]["ok"], false)
}

CheckAWriteThatFindsStorageGoneIsKept() {
    r := NewReport(&hub, &children)
    r.storageWaitMs := 100000
    hub.links["storage"] := true
    result := ""
    r.Request("manual", false, (p) => result := p)
    Sleep(50)
    w := hub.Find("cmd.storage.report.write")
    Assert.True(w != "")
    hub.links.Delete("storage")
    hub.Answer(w, Map("ok", false, "error", Map("code", "peer_gone", "message", "x")))
    Assert.Equal(r.Stats()["unwritten"], 1, "storage vanished during the write: wait for it")
    Assert.Equal(result, "")
}

CheckAWriteErrorIsPassedOn() {
    r := NewReport(&hub, &children)
    hub.links["storage"] := true
    result := ""
    r.Request("manual", false, (p) => result := p)
    Sleep(50)
    hub.Answer(hub.Find("cmd.storage.report.write"), Map("ok", false, "error", Map("code", "internal", "message", "disk full")))
    Assert.Equal(result["ok"], false)
    Assert.Equal(result["error"]["code"], "internal")
    Assert.Equal(r.Stats()["unwritten"], 0)
}

CheckAutomaticReportsAreRateLimited() {
    r := NewReport(&hub, &children)
    Assert.True(r.Auto("crashed", "engine"), "the first one starts")
    Assert.True(!r.Auto("hung", "storage"), "the next one within the minute is held back")
    Assert.Equal(r.Stats()["autoSuppressed"], 1)
    r._lastAutoMs := Time.NowMs() - DiagReport.AUTO_MIN_INTERVAL_MS - 1
    Assert.True(r.Auto("crashed", "storage"), "after the interval the next one starts")
    Sleep(50)
}

CheckNoAutomaticReportWhileTheSessionEnds() {
    r := NewReport(&hub, &children)
    children.shuttingDown := true
    Assert.True(!r.Auto("crashed", "engine"))
    Assert.Equal(r.Stats()["autoSuppressed"], 0, "an ending session is not a suppressed report")
    Assert.Equal(hub.requests.Length, 0)
}

CheckABurstOfErrorsStartsAReportButFewDoNot() {
    r := NewReport(&hub, &children)
    loop DiagReport.ERROR_BURST - 1
        Assert.True(!r.NoteError("engine"))
    Assert.True(r.NoteError("engine"), "the tenth error in the window starts a report")
    Assert.True(!r.NoteError("engine"), "the counter starts again")
    loop 20
        r.NoteError("storage")
    Sleep(50)
}

CheckReasonsAreMadeSafeForFolderNames() {
    Assert.Equal(DiagReport.SafeReason("crashed-echo:a"), "crashed-echo-a")
    Assert.Equal(DiagReport.SafeReason("a/b\c d"), "a-b-c-d")
    Assert.Equal(DiagReport.SafeReason(""), "report")
    Assert.Equal(StrLen(DiagReport.SafeReason(Format("{:100}", "")  "x")), 60)
}

CheckSummaryIsReadableAndListsMissingRoles() {
    meta := Map("reason", "manual", "auto", 0, "createdAt", "2026-10-12 10:00:00", "session", "main", "version", "v1", "ahkVersion", "2.0.19")
    snaps := Map("supervisor", SupSnap(), "engine", SnapOf("engine", "engine"))
    snaps["engine"]["errors"] := Map("count", 1, "recent", [Map("ts", "t", "errorType", "ValueError", "message", "boom", "file", "f.ahk", "line", 7, "stack", "", "mode", "Return")])
    snaps["engine"]["info"] := Map("flows", [Map("flowId", "f")], "instances", [Map("instanceId", "inst-1", "flowId", "f", "state", "running"
        , "threads", [Map("threadId", "thr-1", "elementId", "e2", "state", "running", "result", "")])], "seq", 5
        , "workers", Map("size", 4, "warm", 1, "slots", [Map("name", "worker:1", "state", "idle", "execId", "")], "spawning", 0, "failures", 0))
    text := ReportText.Build(meta, snaps, [Map("name", "storage", "why", "no answer within 2000 ms")])
    for needle in ["AutoHotFlow diagnostic report", "reason:   manual  (manual)", "roles with a snapshot: 2   without: 1"
        , "== Processes (supervisor", "engine  (pid 100", "inst-1 of f running", "thr-1=e2/running", "worker:1=idle"
        , "== Roles without a snapshot ==", "storage: no answer within 2000 ms", "ValueError: boom (f.ahk, line 7)"]
        Assert.True(InStr(text, needle), "summary has '" needle "'")
}

TestRun.Init()

TestRun.Case("every connected role is asked with a deadline, the others are noted", CheckAsksEveryConnectedRoleAndNotesTheOthers)
TestRun.Case("the report is built after the last answer and written through storage", CheckAssemblesAfterTheLastAnswerAndWritesThroughStorage)
TestRun.Case("a missing answer or a lost link is noted and nothing waits", CheckNoAnswerAndLostLinkAreNotedAndNothingWaits)
TestRun.Case("an answer without a snapshot counts as missing", CheckARoleWithoutSnapshotInTheAnswerCountsAsMissing)
TestRun.Case("a report without any child is still built (and waits for storage)", CheckAReportWithoutAnyChildIsStillBuilt)
TestRun.Case("a report waits for storage and is written when it is back", CheckAReportWaitsForStorageAndIsWrittenWhenItIsBack)
TestRun.Case("the caller is answered after the wait, the report is kept for the next time", CheckTheCallerIsAnsweredAfterTheWaitAndTheReportStaysForTheNextTime)
TestRun.Case("a stand-still of the supervisor moves the wait for storage (WI-0033)", CheckAStandStillMovesTheWaitForStorage)
TestRun.Case("the list of unwritten reports is bounded", CheckTheWaitingListIsBounded)
TestRun.Case("a write that finds storage gone is kept", CheckAWriteThatFindsStorageGoneIsKept)
TestRun.Case("an error answer of storage is passed on", CheckAWriteErrorIsPassedOn)
TestRun.Case("automatic reports: one per interval, the rest is counted", CheckAutomaticReportsAreRateLimited)
TestRun.Case("no automatic report while the session ends", CheckNoAutomaticReportWhileTheSessionEnds)
TestRun.Case("ten unhandled errors of one role start a report", CheckABurstOfErrorsStartsAReportButFewDoNot)
TestRun.Case("reasons become safe folder names", CheckReasonsAreMadeSafeForFolderNames)
TestRun.Case("the summary is readable and lists missing roles and errors", CheckSummaryIsReadableAndListsMissingRoles)

TestRun.Finish()
