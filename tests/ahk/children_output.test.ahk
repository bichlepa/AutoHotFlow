#Requires AutoHotkey v2.0
; Unit tests for the output handling of src/supervisor/Children.ahk (WI-23): log lines of the child output,
; the per-tick limit and the ring that survives the process.
#Include lib\Assert.ahk
#Include ..\..\src\supervisor\Children.ahk

class QuietHub {
    Publish(topic, type, payload) {
    }
    Send(to, type, payload) => true
}

NewChildren() {
    Log.Configure(Log.Memory)
    Log.memoryLines := []
    return Children(Map("session", "t", "pipe", "p", "data", "d", "hubHwnd", 0, "testRoles", false
        , "script", "x", "roleOpts", ""), QuietHub())
}

NewRec(children, name, role) {
    rec := Map("name", name, "role", role, "reader", "", "output", [])
    children._recs[name] := rec
    return rec
}

Numbered(n) {
    lines := []
    loop n
        lines.Push("line " A_Index)
    return lines
}

CheckLinesAreLoggedWithRoleAsSourceAndNameInText() {
    c := NewChildren()
    rec := NewRec(c, "echo:a", "echo")
    c._Emit(rec, ["first", "second"])
    Log.Configure("")
    Assert.Equal(Log.memoryLines.Length, 2)
    Assert.Equal(Log.memoryLines[1]["level"], "a0")
    Assert.Equal(Log.memoryLines[1]["source"], "echo")
    Assert.Equal(Log.memoryLines[1]["text"], "[echo:a] first")
}

CheckRingKeepsTheLast100Lines() {
    c := NewChildren()
    rec := NewRec(c, "engine", "engine")
    c._Emit(rec, Numbered(60))
    c._Emit(rec, Numbered(60))
    Log.Configure("")
    out := c.Output("engine")
    Assert.Equal(out.Length, Children.OUTPUT_RING_MAX)
    Assert.Equal(out[out.Length], "line 60")
    Assert.Equal(out[1], "line 21")                  ; 120 lines were written, the first 20 are gone
}

CheckAFloodIsLimitedPerTickButKeptInTheRing() {
    c := NewChildren()
    rec := NewRec(c, "engine", "engine")
    c._Emit(rec, Numbered(Children.LINES_PER_TICK + 30))
    Log.Configure("")
    Assert.Equal(Log.memoryLines.Length, Children.LINES_PER_TICK + 1)    ; the lines and one note
    Assert.True(InStr(Log.memoryLines[Log.memoryLines.Length]["text"], "30 lines of output of engine were not logged"))
    Assert.Equal(c.Output("engine")[c.Output("engine").Length], "line " (Children.LINES_PER_TICK + 30))
}

CheckOutputOfAnUnknownChildIsEmptyAndACopy() {
    c := NewChildren()
    Log.Configure("")
    Assert.Equal(c.Output("nobody").Length, 0)
    rec := NewRec(c, "x", "x")
    rec["output"].Push("kept")
    copy := c.Output("x")
    copy.Push("changed")
    Assert.Equal(c.Output("x").Length, 1)
}

TestRun.Init()

TestRun.Case("output lines are logged at a0 with the role as source and the child name in the text", CheckLinesAreLoggedWithRoleAsSourceAndNameInText)
TestRun.Case("the ring keeps the last 100 lines", CheckRingKeepsTheLast100Lines)
TestRun.Case("a flood is limited per tick in the log but kept in the ring", CheckAFloodIsLimitedPerTickButKeptInTheRing)
TestRun.Case("the output of an unknown child is empty, the result is a copy", CheckOutputOfAnUnknownChildIsEmptyAndACopy)

TestRun.Finish()
