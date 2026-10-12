#Requires AutoHotkey v2.0
; Unit tests for src/core/ProcInfo.ahk, Snapshot.ahk and Peer.Stats (WI-28): the building blocks of cmd.diag.snapshot.
#Include lib\Assert.ahk
#Include ..\..\src\core\Snapshot.ahk
#Include ..\..\src\core\Role.ahk

CheckProcessFacts() {
    Assert.True(ProcInfo.Rss() > 1000000, "a running AHK process has more than 1 MB working set")
    Assert.True(ProcInfo.Handles() > 5)
    started := ProcInfo.StartedAt()
    Assert.True(RegExMatch(started, "^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$"), "start time format: " started)
    ; this process started a moment ago (the test run), in UTC
    ago := DateDiff(A_NowUTC, StrReplace(StrReplace(StrReplace(started, "-"), " "), ":"), "Seconds")
    Assert.True(ago >= 0 && ago < 120, "started " ago " s ago")
    Assert.True(ProcInfo.UptimeMs() >= 0 && ProcInfo.UptimeMs() < 120000)
}

CheckGeneralPart() {
    snap := Snapshot.General("editor:Flow 1", "editor")
    Assert.Equal(snap["schema"], 1)
    Assert.Equal(snap["name"], "editor:Flow 1")
    Assert.Equal(snap["role"], "editor")
    Assert.Equal(snap["bits"], 64)
    Assert.Equal(snap["ahkVersion"], A_AhkVersion)
    Assert.Equal(snap["version"], AhfVersion.Current)
    Assert.Equal(snap["pid"], DllCall("GetCurrentProcessId", "uint"))
    for key in ["startedAt", "uptimeMs", "rssBytes", "handles"]
        Assert.True(snap.Has(key), key)
}

CheckLogPartCutsEntriesAndText() {
    Log.Configure("")
    Log.ring := []
    loop 150
        Log.Write("a1", "t", (A_Index = 150) ? "last " Format("{:1000}", "x") : "entry " A_Index)
    part := Snapshot.LogPart(3, 4)
    Assert.Equal(part["queued"], 3)
    Assert.Equal(part["dropped"], 4)
    Assert.Equal(part["recent"].Length, 100)
    last := part["recent"][100]
    Assert.True(StrLen(last["text"]) = 503, "the text is cut to 500 characters and a mark: " StrLen(last["text"]))
    Assert.True(RegExMatch(last["ts"], "^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$"), last["ts"])
    Assert.Equal(part["recent"][1]["text"], "entry 51")
}

CheckErrorsPartKeepsTheNewest() {
    list := []
    loop 30
        list.Push(Map("ts", "t", "errorType", "ValueError", "message", "m" A_Index, "file", "f.ahk", "line", A_Index
            , "stack", "s", "mode", "Return"))
    part := Snapshot.ErrorsPart(30, list)
    Assert.Equal(part["count"], 30)
    Assert.Equal(part["recent"].Length, 20)
    Assert.Equal(part["recent"][1]["message"], "m11")
    Assert.Equal(part["recent"][20]["line"], 30)
    ; missing fields do not break it
    part := Snapshot.ErrorsPart(1, [Map("message", "only a message")])
    Assert.Equal(part["recent"][1]["line"], 0)
    Assert.Equal(part["recent"][1]["file"], "")
}

CheckRoleSnapshotBuildsWithoutAPeerAndSurvivesABrokenHook() {
    r := Role(Map())
    snap := r.Snapshot()
    Assert.Equal(snap["role"], "supervisor")        ; the default role name of the class without arguments
    Assert.Equal(snap["info"].Count, 0)
    Assert.Equal(snap["errors"]["count"], 0)
    Assert.Equal(snap["peer"].Count, 0)
    b := BrokenRole(Map())
    info := b.Snapshot()["info"]
    Assert.True(InStr(info["error"], "broken hook"), "the failure of DiagInfo becomes info.error")
}

class BrokenRole extends Role {
    DiagInfo() {
        throw ValueError("broken hook")
    }
}

CheckPeerStatsOfAPeerThatNeverConnected() {
    p := Peer("stats-test", "no-such-pipe")
    stats := p.Stats()
    Assert.Equal(stats["status"], "idle")
    for key in ["pending", "lateReplies", "badFrames", "droppedSends", "queuedFrames", "queuedBytes", "handlerErrors"]
        Assert.Equal(stats[key], 0, key)
    p.Subscribe("process")
    p.Subscribe("engine")
    Assert.Equal(p.Topics().Length, 2)
}

TestRun.Init()

TestRun.Case("process facts: memory, handles, start time, uptime", CheckProcessFacts)
TestRun.Case("the general part has the schema, names, versions and the process id", CheckGeneralPart)
TestRun.Case("the log part keeps the newest 100 entries and cuts long texts", CheckLogPartCutsEntriesAndText)
TestRun.Case("the errors part keeps the newest 20 and tolerates missing fields", CheckErrorsPartKeepsTheNewest)
TestRun.Case("a role builds its snapshot without a peer; a failing hook becomes info.error", CheckRoleSnapshotBuildsWithoutAPeerAndSurvivesABrokenHook)
TestRun.Case("Peer.Stats and Topics work before the connection exists", CheckPeerStatsOfAPeerThatNeverConnected)

TestRun.Finish()
