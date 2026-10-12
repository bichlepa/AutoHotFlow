#Requires AutoHotkey v2.0
; Unit tests for src/core/Debug.ahk (WI-28): Debug.Dump never blocks and never throws, and Render makes readable,
; bounded JSON of anything. The send path through a ready peer is covered by tests/fault/test_debug_dump.py.
#Include lib\Assert.ahk
#Include ..\..\src\core\Role.ahk

class FakePeer {
    __New() {
        this.status := "ready"
        this.sent := []
        this.fail := false
    }
    Send(to, type, payload) {
        if (this.fail)
            return ""
        this.sent.Push(Map("to", to, "type", type, "payload", payload))
        return "id" this.sent.Length
    }
}

; A role object with a fake peer, installed as Role.Current for the duration of the check.
WithRole(&peer) {
    peer := FakePeer()
    r := Role(Map())
    r.peer := peer
    Role.Current := r
    Debug.sent := 0
    Debug.dropped := 0
    Debug.failed := 0
    Debug._windowStart := 0
    Debug._windowCount := 0
}

CheckNoRoleNoConnectionNothingHappens() {
    Role.Current := ""
    Assert.Equal(Debug.Dump(Map("a", 1), "t"), false, "no role: nothing is sent, nothing is thrown")
    WithRole(&peer)
    peer.status := "reconnecting"
    Assert.Equal(Debug.Dump(1), false)
    Assert.Equal(peer.sent.Length, 0)
    Role.Current := ""
}

CheckSendsOneEventToTheDebugTopic() {
    WithRole(&peer)
    Assert.Equal(Debug.Dump(Map("name", "x", "list", [1, "two", 3.5]), "my title"), true)
    Assert.Equal(peer.sent.Length, 1)
    m := peer.sent[1]
    Assert.Equal(m["to"], "topic:debug")
    Assert.Equal(m["type"], "evt.debug.dump")
    p := m["payload"]
    Assert.Equal(p["title"], "my title")
    Assert.True(RegExMatch(p["ts"], "^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$"))
    Assert.True(p["truncated"] == Json.False, "a real JSON false, not 0")
    parsed := Json.Parse(p["json"])
    Assert.Equal(parsed["name"], "x")
    Assert.Equal(parsed["list"][2], "two")
    Assert.Equal(Debug.sent, 1)
    Role.Current := ""
}

CheckARefusedSendIsNotAnError() {
    WithRole(&peer)
    peer.fail := true
    Assert.Equal(Debug.Dump(1), false)
    Assert.Equal(Debug.failed, 0, "a send that the peer refuses is not a failure of Dump")
    Role.Current := ""
}

CheckRateLimitDropsTheRestAndCountsIt() {
    WithRole(&peer)
    loop Debug.MAX_PER_SECOND + 30
        Debug.Dump(A_Index)
    Assert.Equal(peer.sent.Length, Debug.MAX_PER_SECOND)
    Assert.Equal(Debug.dropped, 30)
    Debug._windowStart := Debug._windowStart - 2000          ; a second later
    Assert.Equal(Debug.Dump("again"), true)
    Role.Current := ""
}

CheckEverythingCanBeRenderedWithoutThrowing() {
    WithRole(&peer)
    cyc := Map("name", "loop")
    cyc["self"] := cyc
    arr := [1]
    arr.Push(arr)
    for value in [cyc, arr, StrLen, ObjBindMethod(peer, "Send"), peer, {a: 1, b: [1, 2]}, Json.Null, Json.True, ""
        , 0, 1.5, "text", Map(), [], Buffer(4)] {
        Assert.Equal(Debug.Dump(value, "v"), true, Type(value))
    }
    Assert.Equal(Debug.failed, 0)
    Role.Current := ""
}

CheckCyclesFunctionsAndInstancesBecomeMarkers() {
    cyc := Map("name", "loop")
    cyc["self"] := cyc
    j := Json.Parse(Debug.Render(cyc)["json"])
    Assert.Equal(j["self"], "<cycle>")
    j := Json.Parse(Debug.Render(Map("f", StrLen, "o", Role(Map()), "b", Buffer(2)))["json"])
    Assert.Equal(j["f"], "<Func>")
    Assert.Equal(j["o"], "<Role>")
    Assert.Equal(j["b"], "<Buffer>")
}

CheckPlainObjectsAndSharedChildrenAreNotCycles() {
    shared := Map("x", 1)
    j := Json.Parse(Debug.Render(Map("a", shared, "b", shared, "o", {p: 1}))["json"])
    Assert.Equal(j["a"]["x"], 1)
    Assert.Equal(j["b"]["x"], 1, "the same object twice is not a cycle")
    Assert.Equal(j["o"]["p"], 1)
}

CheckDepthAndSizeAreBounded() {
    deep := Map("leaf", 1)
    loop 30
        deep := Map("next", deep)
    text := Debug.Render(deep)["json"]
    Assert.True(InStr(text, "too deep"), "levels below MAX_DEPTH are cut")
    big := []
    loop 500
        big.Push(A_Index)
    j := Json.Parse(Debug.Render(big)["json"])
    Assert.Equal(j.Length, Debug.MAX_ITEMS + 1, "200 items and one note")
    Assert.True(InStr(j[Debug.MAX_ITEMS + 1], "300 more"))
    m := Map()
    loop 300
        m["k" Format("{:03d}", A_Index)] := A_Index
    j := Json.Parse(Debug.Render(m)["json"])
    Assert.Equal(j.Count, Debug.MAX_ITEMS + 1)
}

CheckLongTextIsCutAndMarked() {
    r := Debug.Render(Format("{:200000}", ""))
    Assert.Equal(r["cut"], 1)
    Assert.True(StrLen(r["json"]) <= Debug.MAX_CHARS + 20)
    Assert.Equal(Debug.Render("short")["cut"], 0)
}

TestRun.Init()

TestRun.Case("without a role or a ready connection Dump does nothing and does not throw", CheckNoRoleNoConnectionNothingHappens)
TestRun.Case("Dump sends one evt.debug.dump to the topic debug with readable JSON", CheckSendsOneEventToTheDebugTopic)
TestRun.Case("a send the peer refuses is not an error", CheckARefusedSendIsNotAnError)
TestRun.Case("at most 100 per second are sent, the rest is counted", CheckRateLimitDropsTheRestAndCountsIt)
TestRun.Case("cycles, functions, buffers, windows and instances can be dumped without a throw", CheckEverythingCanBeRenderedWithoutThrowing)
TestRun.Case("cycles, functions and instances become markers", CheckCyclesFunctionsAndInstancesBecomeMarkers)
TestRun.Case("plain objects work and a shared child is not a cycle", CheckPlainObjectsAndSharedChildrenAreNotCycles)
TestRun.Case("depth and number of items are bounded", CheckDepthAndSizeAreBounded)
TestRun.Case("a very long text is cut and marked", CheckLongTextIsCutAndMarked)

TestRun.Finish()
